import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Night Signal" palette — a covert-channel aesthetic for an app whose
/// whole premise is that the server never sees your messages. Deep
/// blue-black base, one cyan "signal" accent spent only on things that are
/// live or yours to send, a cooler green reserved for verified/online state.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF0A1620);
  static const panel = Color(0xFF0F2230);
  static const raised = Color(0xFF16303F);
  static const line = Color(0xFF1F3D4D);
  static const paper = Color(0xFFDCEAF0);
  static const mist = Color(0xFF7FA0B0);
  static const signal = Color(0xFF2DD4C8);
  static const onSignal = Color(0xFF04211E);
  static const moss = Color(0xFF4FBF8C);
  static const redact = Color(0xFF050B10);
  static const danger = Color(0xFFE2685A);
}

/// The redaction bar stands in for "encrypted / can't read this yet" —
/// a blacked-out strip instead of a lock icon and a caption.
class RedactionBar extends StatelessWidget {
  const RedactionBar({super.key, this.width = 120, this.height = 10});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.redact,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// A flat, hairline-bordered panel — the alternative to a soft-shadow card
/// kit. Used for every grouped block (forms, list sections).
class DispatchPanel extends StatelessWidget {
  const DispatchPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

/// A square-cornered initial tile — the app's one consistent identity mark,
/// used instead of a Material CircleAvatar everywhere a person is shown.
/// [accent] draws a small corner dot (e.g. for online presence).
class InitialTile extends StatelessWidget {
  const InitialTile({super.key, required this.label, this.size = 40, this.accent});

  final String label;
  final double size;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
            style: TextStyle(color: AppColors.paper, fontWeight: FontWeight.w700, fontSize: size * 0.4),
          ),
        ),
        if (accent != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Monospace is reserved for text that is functionally a code or a system
/// readout — shared codes, connection status, timestamps — not decoration.
TextStyle mono(
  BuildContext context, {
  double size = 13,
  Color? color,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
}) {
  return GoogleFonts.ibmPlexMono(
    fontSize: size,
    color: color ?? AppColors.mist,
    fontWeight: weight,
    letterSpacing: letterSpacing,
  );
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
      bodyColor: AppColors.paper,
      displayColor: AppColors.paper,
    );

    final colorScheme = const ColorScheme.dark(
      surface: AppColors.ink,
      onSurface: AppColors.paper,
      primary: AppColors.signal,
      onPrimary: AppColors.onSignal,
      secondary: AppColors.moss,
      onSecondary: Colors.black,
      error: AppColors.danger,
      onError: Colors.black,
      surfaceContainerHighest: AppColors.raised,
      outline: AppColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink,
      textTheme: textTheme,
      fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: AppColors.paper),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.raised,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.mist),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.mist),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.signal, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.signal,
          foregroundColor: AppColors.onSignal,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.mist),
      ),
      iconTheme: const IconThemeData(color: AppColors.mist),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          side: BorderSide(color: AppColors.line),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.signal,
        foregroundColor: AppColors.onSignal,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.raised,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: AppColors.line),
        ),
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.mist),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.signal),
    );
  }
}
