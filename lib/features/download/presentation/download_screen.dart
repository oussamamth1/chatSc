import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/download_providers.dart';
import 'social_app.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _openSocialApp(SocialApp app) async {
    final uri = Uri.parse(app.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _urlController.text = text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadControllerProvider);
    final controller = ref.read(downloadControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Downloader'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Grab a link from any of these apps, then paste it below',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: SocialApp.all.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final app = SocialApp.all[index];
                    return _SocialAppButton(
                      app: app,
                      onTap: () => _openSocialApp(app),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'Paste video link here',
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Paste',
                            icon: const Icon(Icons.content_paste),
                            onPressed: _pasteFromClipboard,
                          ),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: state.status == DownloadStatus.fetchingInfo
                            ? null
                            : () {
                                if (_urlController.text.trim().isNotEmpty) {
                                  controller.fetchInfo(_urlController.text);
                                }
                              },
                        child: state.status == DownloadStatus.fetchingInfo
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Fetch Info'),
                      ),
                      if (state.status == DownloadStatus.fetchingInfo) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Waking up the server... first request can take up to a minute.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (state.info != null) ...[
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.info!.thumbnailUrl != null)
                        Image.network(
                          state.info!.thumbnailUrl!,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              state.info!.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed:
                                  state.status == DownloadStatus.downloading
                                      ? null
                                      : () => controller
                                          .downloadAndSave(_urlController.text),
                              icon: const Icon(Icons.download),
                              label: const Text('Download to Gallery'),
                            ),
                            if (state.status ==
                                DownloadStatus.downloading) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: state.progress,
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  '${(state.progress * 100).toStringAsFixed(0)}%'),
                            ],
                            if (state.status == DownloadStatus.saved) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green.shade600),
                                  const SizedBox(width: 8),
                                  const Text('Saved to gallery!'),
                                ],
                              ),
                            ],
                            if (state.status == DownloadStatus.error) ...[
                              const SizedBox(height: 16),
                              Text(
                                state.errorMessage ?? 'Something went wrong',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (state.status == DownloadStatus.error) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? 'Something went wrong',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialAppButton extends StatelessWidget {
  const _SocialAppButton({required this.app, required this.onTap});

  final SocialApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: app.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: FaIcon(app.icon, color: app.color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              app.name,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
