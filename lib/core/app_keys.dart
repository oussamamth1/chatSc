import 'package:flutter/material.dart';

/// Lets code outside the widget tree (the call controller's state listener)
/// push screens and show snackbars — needed because an incoming call can
/// arrive while the user is anywhere in the app, not just inside a chat.
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
