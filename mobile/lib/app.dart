import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'features/catalog/providers/store_context_provider.dart';
import 'shared/theme/app_colors.dart';
import 'shared/widgets/app_background.dart';

class HelianthaApp extends ConsumerWidget {
  const HelianthaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeContext = ref.watch(storeContextProvider).valueOrNull;
    final selectedLanguageId = ref.watch(selectedLanguageIdProvider);
    final language = storeContext?.languageById(
      storeContext.effectiveLanguageId(selectedLanguageId),
    );
    final textDirection =
        language?.isRtl == true ? TextDirection.rtl : TextDirection.ltr;

    return MaterialApp.router(
      title: 'Heliantha',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final compactWidth = mediaQuery.size.width <= 600;
        final normalizedMediaQuery = compactWidth
            ? mediaQuery.copyWith(
                padding: mediaQuery.padding.copyWith(left: 0, right: 0),
                viewPadding:
                    mediaQuery.viewPadding.copyWith(left: 0, right: 0),
              )
            : mediaQuery;

        return Directionality(
          textDirection: textDirection,
          child: MediaQuery(
            data: normalizedMediaQuery,
            child: SizedBox.expand(
              child: HelianthaBackground(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        visualDensity: VisualDensity.standard,
        colorScheme: const ColorScheme.light(
          primary: AppColors.blue,
          onPrimary: Colors.white,
          secondary: AppColors.sun,
          onSecondary: AppColors.navy,
          tertiary: AppColors.leaf,
          onTertiary: Colors.white,
          error: AppColors.danger,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
        ),
        textTheme: Typography.material2021().black.apply(
              bodyColor: AppColors.ink,
              displayColor: AppColors.ink,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.softSun,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.navy
                  : AppColors.muted,
            ),
          ),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 46),
            foregroundColor: AppColors.blue,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        searchBarTheme: SearchBarThemeData(
          elevation: WidgetStateProperty.all(0),
          backgroundColor: WidgetStateProperty.all(AppColors.surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          hintStyle: WidgetStateProperty.all(
            const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
