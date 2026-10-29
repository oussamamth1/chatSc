import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../core/constants.dart';
import '../data/download_service.dart';
import '../data/video_info.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    // Render's free tier spins down after 15 min idle; waking it back up
    // can take 30-60s, so connectTimeout must be generous or the very
    // first request after a period of inactivity times out immediately.
    connectTimeout: const Duration(seconds: 90),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(minutes: 5),
  ));
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(dioProvider));
});

enum DownloadStatus { idle, fetchingInfo, infoLoaded, downloading, saved, error }

class DownloadState {
  final DownloadStatus status;
  final VideoInfo? info;
  final double progress;
  final String? errorMessage;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.info,
    this.progress = 0,
    this.errorMessage,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    VideoInfo? info,
    double? progress,
    String? errorMessage,
  }) {
    return DownloadState(
      status: status ?? this.status,
      info: info ?? this.info,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
    );
  }
}

class DownloadController extends StateNotifier<DownloadState> {
  DownloadController(this._service) : super(const DownloadState());

  final DownloadService _service;

  Future<void> fetchInfo(String url) async {
    state = state.copyWith(status: DownloadStatus.fetchingInfo, errorMessage: null);
    try {
      final info = await _service.fetchInfo(url.trim());
      state = state.copyWith(status: DownloadStatus.infoLoaded, info: info);
    } on DioException catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        errorMessage: _extractError(e),
      );
    }
  }

  Future<void> downloadAndSave(String url) async {
    state = state.copyWith(status: DownloadStatus.downloading, progress: 0, errorMessage: null);
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        state = state.copyWith(
          status: DownloadStatus.error,
          errorMessage: 'Gallery permission denied',
        );
        return;
      }

      final file = await _service.downloadVideo(
        url.trim(),
        onProgress: (p) => state = state.copyWith(progress: p),
      );

      await Gal.putVideo(file.path);
      await file.delete();

      state = state.copyWith(status: DownloadStatus.saved, progress: 1);
    } on DioException catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        errorMessage: _extractError(e),
      );
    } on GalException catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        errorMessage: 'Failed to save to gallery: ${e.type.message}',
      );
    }
  }

  void reset() => state = const DownloadState();

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Something went wrong';
  }
}

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, DownloadState>((ref) {
  return DownloadController(ref.watch(downloadServiceProvider));
});
