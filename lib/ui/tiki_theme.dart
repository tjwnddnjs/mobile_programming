import 'package:flutter/material.dart';

abstract final class Tiki {
  static const paper = Color(0xFFF9F5EC);
  static const ink = Color(0xFF25221F);
  static const muted = Color(0xFF665E56);
  static const blue = Color(0xFF91B5F1);
  static const coral = Color(0xFFF57256);
  static const lilac = Color(0xFFC6BBF5);
  static const lime = Color(0xFFDCEC58);
  static const white = Colors.white;
  static const error = Color(0xFFA52C24);
  static const outline = BorderSide(color: ink, width: 1.7);
  static const thinLine = Color(0xFFD9D0C2);
  static const radius = BorderRadius.all(Radius.circular(10));
  static const shape = RoundedRectangleBorder(
    borderRadius: radius,
    side: outline,
  );
  static const shadow = BoxShadow(color: ink, offset: Offset(2, 3));

  static const display = TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w900,
    color: ink,
    height: 1.1,
  );

  static const label =
      TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: ink);

  static const fieldBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: outline,
  );

  static ButtonStyle filled([Color color = blue]) => ElevatedButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: color,
        disabledBackgroundColor: const Color(0xFFE9E3D9),
        disabledForegroundColor: muted,
        elevation: 0,
        side: outline,
        shape: shape,
        textStyle: label,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: const ColorScheme.light(
          primary: ink,
          onPrimary: white,
          secondary: lilac,
          onSecondary: ink,
          surface: paper,
          onSurface: ink,
          error: error,
          outline: ink,
        ),
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Fraunces',
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        cardTheme: const CardThemeData(
          color: white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          shape: shape,
          titleTextStyle: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: white,
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: ink, width: 2.4),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          labelStyle: TextStyle(color: muted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: filled()),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: ink,
            backgroundColor: white,
            side: outline,
            shape: shape,
            textStyle: label,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: ink, textStyle: label),
        ),
        dividerTheme: const DividerThemeData(color: thinLine),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(white),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? lime : thinLine,
          ),
          trackOutlineColor: const WidgetStatePropertyAll(ink),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: ink,
          contentTextStyle: TextStyle(color: white, fontFamily: 'Poppins'),
        ),
      );
}

class TikiPanel extends StatelessWidget {
  const TikiPanel({
    super.key,
    required this.child,
    this.color = Tiki.white,
    this.onTap,
    this.borderRadius = Tiki.radius,
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: Tiki.outline,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: color,
        boxShadow: const [Tiki.shadow],
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class TikiBack extends StatelessWidget {
  const TikiBack({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 44,
            child: TikiPanel(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 23),
                onPressed: onPressed,
              ),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Back',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class TikiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TikiAppBar({super.key, required this.title, this.accent});

  final String title;
  final Color? accent;

  @override
  Size get preferredSize => const Size.fromHeight(128);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 66,
      scrolledUnderElevation: 0,
      title: Text('TikiTalk', style: Tiki.display.copyWith(fontSize: 28)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: TikiBack(onPressed: () => Navigator.maybePop(context)),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: accent == null
              ? Text(title, style: Tiki.display.copyWith(fontSize: 28))
              : TikiPanel(
                  color: accent!,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      title,
                      style: Tiki.display.copyWith(fontSize: 26),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
