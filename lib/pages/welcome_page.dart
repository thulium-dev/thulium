import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

import '../widgets/language_button.dart';
import 'login_page.dart';

/// The unauthenticated landing page shown before the student signs in.
final class WelcomePage extends StatelessWidget {
  const WelcomePage({
    required this.onLocaleSelected,
    required this.onThemeToggle,
    required this.onLoginSuccess,
    super.key,
  });

  final ValueChanged<Locale> onLocaleSelected;
  final VoidCallback onThemeToggle;
  final VoidCallback onLoginSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
      child: SafeArea(
        child: Stack(
          children: [
            Center(
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
                        onPress: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LoginPage(
                                onLoginSuccess: () {
                                  Navigator.of(context).pop();
                                  onLoginSuccess();
                                },
                              ),
                            ),
                          );
                        },
                        child: Text(l10n.explore),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LanguageButton(onSelected: onLocaleSelected),
                  IconButton(
                    tooltip: l10n.theme,
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    onPressed: onThemeToggle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
