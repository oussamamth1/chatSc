import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'video_info.dart';

class DownloadService {
  DownloadService(this._dio);

  final Dio _dio;

  Future<VideoInfo> fetchInfo(String url) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/info',
      queryParameters: {'url': url},
    );
    return VideoInfo.fromJson(response.data!);
  }

  /// Downloads the video to a temp file and returns it.
  Future<File> downloadVideo(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'ytdl_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final savePath = '${tempDir.path}/$fileName';

    await _dio.download(
      '/download',
      savePath,
      data: {'url': url},
      options: Options(method: 'POST'),
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return File(savePath);
  }
}
