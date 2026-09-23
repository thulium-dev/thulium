import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

void main() {
  runApp(const ThuliumApp());
}

class ThuliumApp extends StatelessWidget {
  const ThuliumApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = FThemes.neutral.light.touch;

    return MaterialApp(
      title: 'Thulium',
      theme: lightTheme.toApproximateMaterialTheme(),
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        ...FLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => FTheme(
        data: lightTheme,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
        header: Text(l10n.appTitle),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.welcomeTitle,
                    style: context.theme.typography.xl2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeDescription,
                    style: context.theme.typography.md,
                  ),
                  const SizedBox(height: 24),
                  FButton(
                    onPress: () {},
                    prefix: Image.asset(
                      'assets/thulium.png',
                      width: 20,
                      height: 20,
                    ),
                    child: Text(l10n.explore),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
