import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_keys.dart';
import 'core/theme.dart';
import 'features/chat/data/push_service.dart';
import 'features/chat/presentation/call_overlay.dart';
import 'features/chat/presentation/conversations_screen.dart';
import 'features/chat/presentation/login_screen.dart';
import 'features/chat/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen(handleForegroundCallPush);
  FlutterCallkitIncoming.onBackgroundMessage(callkitBackgroundHandler);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.ink,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: YtDownloaderApp()));
}

class YtDownloaderApp extends StatelessWidget {
  const YtDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cipher',
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const CallOverlay(child: AuthGate()),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.loggedIn:
        return const ConversationsScreen();
      case AuthStatus.loggedOut:
      case AuthStatus.loading:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
