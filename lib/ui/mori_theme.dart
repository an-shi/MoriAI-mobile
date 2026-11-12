import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:mori_ai/ui/mori_icons.dart';

/// The Mori palette: calm mint greens on warm, milky backgrounds.
abstract final class MoriColors {
  // Brand
  static const mint = Color(0xFF3F8F75);
  static const mintBright = Color(0xFF5BAE91);
  static const mintSoft = Color(0xFFD9F0E5);
  static const mintDeep = Color(0xFF194B3B);
  static const cream = Color(0xFFF7F4EC);
  static const paper = Color(0xFFFFFDF8);

  // Light neutrals
  static const ink = Color(0xFF1C2722);
  static const inkMuted = Color(0xFF68756E);
  static const line = Color(0xFFE5E1D7);
  static const stone = Color(0xFFF0EDE4);

  // Dark neutrals
  static const darkCanvas = Color(0xFF0F1512);
  static const darkSurface = Color(0xFF151D19);
  static const darkRaised = Color(0xFF1C2621);
  static const darkInk = Color(0xFFE5ECE7);
  static const darkInkMuted = Color(0xFFA2B1A9);
  static const darkLine = Color(0xFF2B3731);

  // Accent
  static const sand = Color(0xFFC08A62);
  static const danger = Color(0xFFC4564B);
  static const dangerDark = Color(0xFFF0A198);
}

abstract final class MoriRadius {
  static const xsmall = 8.0;
  static const small = 10.0;
  static const medium = 14.0;
  static const large = 18.0;
  static const xlarge = 24.0;
  static const bubble = 18.0;
  static const pill = 999.0;
}

abstract final class MoriSpacing {
  static const page = 16.0;
  static const section = 24.0;
  static const row = 12.0;
}

/// Chat-specific colours used by message bubbles and the chat wallpaper.
@immutable
class MoriChatPalette extends ThemeExtension<MoriChatPalette> {
  const MoriChatPalette({
    required this.background,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.incomingBubble,
    required this.incomingText,
    required this.incomingBorder,
    required this.pattern,
    required this.composerBackground,
    required this.reactionBackground,
  });

  final Color background;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color incomingBubble;
  final Color incomingText;
  final Color incomingBorder;
  final Color pattern;
  final Color composerBackground;
  final Color reactionBackground;

  static const light = MoriChatPalette(
    background: Color(0xFFF4F0E7),
    outgoingBubble: Color(0xFFD5EFE2),
    outgoingText: Color(0xFF11362A),
    incomingBubble: Color(0xFFFFFDF8),
    incomingText: Color(0xFF1C2722),
    incomingBorder: Color(0xFFEAE6DC),
    pattern: Color(0x143F8F75),
    composerBackground: Color(0xFFFFFDF8),
    reactionBackground: Color(0xFFF0EDE4),
  );

  static const dark = MoriChatPalette(
    background: Color(0xFF0D1411),
    outgoingBubble: Color(0xFF285246),
    outgoingText: Color(0xFFE6FBF2),
    incomingBubble: Color(0xFF1B2520),
    incomingText: Color(0xFFE5ECE7),
    incomingBorder: Color(0xFF26332D),
    pattern: Color(0x1A8AD6B9),
    composerBackground: Color(0xFF151D19),
    reactionBackground: Color(0xFF222D27),
  );

  @override
  MoriChatPalette copyWith({
    Color? background,
    Color? outgoingBubble,
    Color? outgoingText,
    Color? incomingBubble,
    Color? incomingText,
    Color? incomingBorder,
    Color? pattern,
    Color? composerBackground,
    Color? reactionBackground,
  }) {
    return MoriChatPalette(
      background: background ?? this.background,
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      outgoingText: outgoingText ?? this.outgoingText,
      incomingBubble: incomingBubble ?? this.incomingBubble,
      incomingText: incomingText ?? this.incomingText,
      incomingBorder: incomingBorder ?? this.incomingBorder,
      pattern: pattern ?? this.pattern,
      composerBackground: composerBackground ?? this.composerBackground,
      reactionBackground: reactionBackground ?? this.reactionBackground,
    );
  }

  @override
  MoriChatPalette lerp(ThemeExtension<MoriChatPalette>? other, double t) {
    if (other is! MoriChatPalette) {
      return this;
    }
    return MoriChatPalette(
      background: Color.lerp(background, other.background, t)!,
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      outgoingText: Color.lerp(outgoingText, other.outgoingText, t)!,
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      incomingText: Color.lerp(incomingText, other.incomingText, t)!,
      incomingBorder: Color.lerp(incomingBorder, other.incomingBorder, t)!,
      pattern: Color.lerp(pattern, other.pattern, t)!,
      composerBackground: Color.lerp(
        composerBackground,
        other.composerBackground,
        t,
      )!,
      reactionBackground: Color.lerp(
        reactionBackground,
        other.reactionBackground,
        t,
      )!,
    );
  }
}

extension MoriChatPaletteContext on BuildContext {
  MoriChatPalette get chatPalette =>
      Theme.of(this).extension<MoriChatPalette>() ?? MoriChatPalette.light;
}

abstract final class MoriTheme {
  static const List<String> _fontFallback = <String>[
    'SF Pro Text',
    'PingFang SC',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Microsoft YaHei',
  ];

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: MoriColors.mint,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: MoriColors.mintSoft,
    onPrimaryContainer: MoriColors.mintDeep,
    secondary: Color(0xFF728D82),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE5EFE9),
    onSecondaryContainer: Color(0xFF233F34),
    tertiary: MoriColors.sand,
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF4E6D9),
    onTertiaryContainer: Color(0xFF4B2F1C),
    error: MoriColors.danger,
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBE3E0),
    onErrorContainer: Color(0xFF5E1712),
    surface: MoriColors.paper,
    onSurface: MoriColors.ink,
    surfaceDim: Color(0xFFDCD8CE),
    surfaceBright: Color(0xFFFFFDF9),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF2EFE6),
    surfaceContainer: Color(0xFFEDEAE1),
    surfaceContainerHigh: Color(0xFFE8E4DA),
    surfaceContainerHighest: Color(0xFFE2DED3),
    onSurfaceVariant: MoriColors.inkMuted,
    outline: Color(0xFF9AA79F),
    outlineVariant: MoriColors.line,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF29342E),
    onInverseSurface: Color(0xFFF6F3EB),
    inversePrimary: Color(0xFF9ADFC7),
    surfaceTint: MoriColors.mint,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8AD6B9),
    onPrimary: Color(0xFF07382A),
    primaryContainer: Color(0xFF214A3B),
    onPrimaryContainer: Color(0xFFC2EFDD),
    secondary: Color(0xFFA7BDB2),
    onSecondary: Color(0xFF14231D),
    secondaryContainer: Color(0xFF293A33),
    onSecondaryContainer: Color(0xFFD4E4DC),
    tertiary: Color(0xFFE0B592),
    onTertiary: Color(0xFF3F2614),
    tertiaryContainer: Color(0xFF553A25),
    onTertiaryContainer: Color(0xFFF7DBC3),
    error: Color(0xFFF0A198),
    onError: Color(0xFF5C120E),
    errorContainer: Color(0xFF4A211D),
    onErrorContainer: Color(0xFFF8DAD6),
    surface: MoriColors.darkSurface,
    onSurface: MoriColors.darkInk,
    surfaceDim: Color(0xFF0B110E),
    surfaceBright: Color(0xFF303B35),
    surfaceContainerLowest: Color(0xFF0A100D),
    surfaceContainerLow: Color(0xFF18211D),
    surfaceContainer: Color(0xFF1D2722),
    surfaceContainerHigh: Color(0xFF243029),
    surfaceContainerHighest: Color(0xFF2A3730),
    onSurfaceVariant: MoriColors.darkInkMuted,
    outline: Color(0xFF708078),
    outlineVariant: MoriColors.darkLine,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE5ECE7),
    onInverseSurface: Color(0xFF26312B),
    inversePrimary: Color(0xFF3F8F75),
    surfaceTint: Color(0xFF8AD6B9),
  );

  static ThemeData light() => _build(_lightScheme, MoriChatPalette.light);

  static ThemeData dark() => _build(_darkScheme, MoriChatPalette.dark);

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.18,
        letterSpacing: -0.8,
      ),
      displayMedium: TextStyle(
        fontSize: 29,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.6,
      ),
      displaySmall: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        height: 1.22,
        letterSpacing: -0.4,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, letterSpacing: 0.05),
      bodyMedium: TextStyle(fontSize: 14.5, height: 1.5, letterSpacing: 0.05),
      bodySmall: TextStyle(fontSize: 12.8, height: 1.45, letterSpacing: 0.1),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 11.2,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
    );
    return base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamilyFallback: _fontFallback,
    );
  }

  static ThemeData _build(ColorScheme scheme, MoriChatPalette chatPalette) {
    final textTheme = _textTheme(scheme);
    final brightness = scheme.brightness;
    final isLight = brightness == Brightness.light;
    final overlayStyle = isLight
        ? SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: scheme.surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: scheme.surface,
            systemNavigationBarIconBrightness: Brightness.light,
          );

    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(MoriRadius.medium)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight
          ? MoriColors.cream
          : MoriColors.darkCanvas,
      canvasColor: scheme.surface,
      primaryColor: scheme.primary,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        titleSpacing: 16,
        leadingWidth: 56,
        systemOverlayStyle: overlayStyle,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(MoriIcons.back, size: 22),
        closeButtonIconBuilder: (_) => const Icon(MoriIcons.close, size: 20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11.5,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isLight ? MoriColors.cream : MoriColors.darkCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        width: 304,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.large),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.8,
        space: 0.8,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 7,
        horizontalTitleGap: 14,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.medium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MoriRadius.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MoriRadius.medium),
          borderSide: BorderSide(
            color: isLight ? Colors.transparent : scheme.outlineVariant,
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MoriRadius.medium),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MoriRadius.medium),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MoriRadius.medium),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        helperMaxLines: 3,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 24,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.08),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.34),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          minimumSize: const Size(0, 44),
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLow,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          minimumSize: const Size(0, 44),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          minimumSize: const Size(0, 44),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoriRadius.small),
          ),
          textStyle: textTheme.labelLarge,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoriRadius.medium),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        splashColor: scheme.onPrimary.withValues(alpha: 0.16),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(),
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onPrimary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.xlarge),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 19,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        modalBarrierColor: Colors.black.withValues(alpha: isLight ? 0.3 : 0.55),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MoriRadius.xlarge),
          ),
        ),
        dragHandleColor: scheme.outlineVariant,
        dragHandleSize: const Size(34, 4),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        actionTextColor: scheme.inversePrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.medium),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.large),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(MoriRadius.xsmall),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerLow,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 1),
        checkmarkColor: scheme.primary,
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? Colors.white : scheme.onPrimary;
          }
          return isLight ? const Color(0xFFFDFBF6) : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return isLight
              ? scheme.surfaceContainerHighest
              : scheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return scheme.outlineVariant;
        }),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.08),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.outline;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primaryContainer,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: scheme.primaryContainer,
        linearMinHeight: 6,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        smallSize: 7,
        largeSize: 18,
        textStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.surface,
        headerForegroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.xlarge),
        ),
        dayShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoriRadius.small),
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.xlarge),
        ),
        dialBackgroundColor: scheme.surfaceContainerLow,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MoriRadius.large),
            ),
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [chatPalette],
    );
  }

  /// Extra padding used by scrollable pages.
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    MoriSpacing.page,
    MoriSpacing.page,
    MoriSpacing.page,
    36,
  );

  /// Forui theme kept in sync with the Material theme so that Forui widgets
  /// blend into the rest of the app.
  static FThemeData forui(ThemeData material) {
    final scheme = material.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final base = FThemeData(
      touch: true,
      debugLabel: isDark ? 'Mori Dark' : 'Mori Light',
      colors: FColors(
        brightness: scheme.brightness,
        systemOverlayStyle:
            material.appBarTheme.systemOverlayStyle ??
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark),
        barrier: Colors.black.withValues(alpha: isDark ? 0.55 : 0.3),
        background: scheme.surface,
        foreground: scheme.onSurface,
        primary: scheme.primary,
        primaryForeground: scheme.onPrimary,
        secondary: scheme.surfaceContainerLow,
        secondaryForeground: scheme.onSurface,
        muted: scheme.surfaceContainer,
        mutedForeground: scheme.onSurfaceVariant,
        destructive: scheme.error,
        destructiveForeground: scheme.onError,
        error: scheme.error,
        errorForeground: scheme.onError,
        card: scheme.surfaceContainerLow,
        border: scheme.outlineVariant,
      ),
    );
    return FThemeData(
      touch: true,
      debugLabel: base.debugLabel,
      colors: base.colors,
      style: base.style.copyWith(
        borderRadius: const FBorderRadius(
          md: BorderRadius.all(Radius.circular(MoriRadius.medium)),
          lg: BorderRadius.all(Radius.circular(MoriRadius.large)),
        ),
      ),
    );
  }
}
