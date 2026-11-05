import 'package:flutter/material.dart';

/// 年轮的配色：取自纸、墨、苔、琥珀。
/// 日记应用的气质应当是安静的，所以整体压低饱和度，只有强调色带一点温度。
class RingPalette {
  const RingPalette._();

  // 深色（夜灯下写字）
  static const nightBg = Color(0xFF14120F);
  static const nightSurface = Color(0xFF1D1A16);
  static const nightSurfaceHi = Color(0xFF26221C);
  static const nightLine = Color(0xFF332E26);
  static const nightInk = Color(0xFFEDE6DA);
  static const nightInkSoft = Color(0xFF9C948A);
  static const nightAmber = Color(0xFFC9A227);
  static const nightMoss = Color(0xFF8FA98A);

  // 浅色（宣纸）
  static const paperBg = Color(0xFFFAF7F2);
  static const paperSurface = Color(0xFFFFFFFF);
  static const paperSurfaceHi = Color(0xFFF3EEE6);
  static const paperLine = Color(0xFFE5DDD1);
  static const paperInk = Color(0xFF2A2622);
  static const paperInkSoft = Color(0xFF7A7167);
  static const paperAmber = Color(0xFFA8874F);
  static const paperMoss = Color(0xFF6B8464);
}

/// 日记正文使用的字体族（打包在 assets 里，保证 PDF 与界面一致）
const String kBodyFontFamily = 'WenKai';

class RingTheme {
  const RingTheme._();

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? RingPalette.nightBg : RingPalette.paperBg;
    final surface = isDark ? RingPalette.nightSurface : RingPalette.paperSurface;
    final surfaceHi =
        isDark ? RingPalette.nightSurfaceHi : RingPalette.paperSurfaceHi;
    final line = isDark ? RingPalette.nightLine : RingPalette.paperLine;
    final ink = isDark ? RingPalette.nightInk : RingPalette.paperInk;
    final inkSoft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    final moss = isDark ? RingPalette.nightMoss : RingPalette.paperMoss;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surface,
      primary: accent,
      secondary: moss,
      onSurface: ink,
      outline: line,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamilyFallback: const ['Noto Sans CJK SC', 'sans-serif'],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? RingPalette.nightSurface : Colors.white,
        indicatorColor: accent.withValues(alpha: 0.16),
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.6,
            color: states.contains(WidgetState.selected) ? accent : inkSoft,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? accent : inkSoft,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHi,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent),
        ),
        hintStyle: TextStyle(color: inkSoft, fontSize: 14),
        labelStyle: TextStyle(color: inkSoft, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? const Color(0xFF1A1712) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? RingPalette.nightSurfaceHi : const Color(0xFF3A342C),
        contentTextStyle: const TextStyle(color: Color(0xFFF2EDE4), fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHi,
        side: BorderSide(color: line),
        labelStyle: TextStyle(color: inkSoft, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      listTileTheme: ListTileThemeData(iconColor: inkSoft),
    );
  }
}
