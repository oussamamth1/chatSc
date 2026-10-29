import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yt_downloader/main.dart';

void main() {
  testWidgets('Shows the video URL input and fetch button', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YtDownloaderApp()));

    expect(find.text('Video Downloader'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Paste video link here'), findsOneWidget);
    expect(find.text('Fetch Info'), findsOneWidget);
  });
}
