import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'features/catalog/providers/store_context_provider.dart';
import 'shared/theme/app_theme.dart';
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
                viewPadding: mediaQuery.viewPadding.copyWith(left: 0, right: 0),
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
      theme: AppTheme.light,
    );
  }
}
