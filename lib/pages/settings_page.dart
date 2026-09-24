import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

/// Contains account and application settings for the authenticated user.
final class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.onLogout, super.key});

  final Future<bool> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends State<SettingsPage> {
  bool _isLoggingOut = false;
  bool _logoutFailed = false;

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
      _logoutFailed = false;
    });

    final succeeded = await widget.onLogout();
    if (!mounted) return;
    if (succeeded) {
      // Settings is pushed over the authenticated home. Remove that route so
      // the root app can reveal the welcome page after its session state flips.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      _isLoggingOut = false;
      _logoutFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: l10n.backAction,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.settingsTitle, style: context.theme.typography.xl2),
                  const SizedBox(height: 24),
                  FButton(
                    variant: FButtonVariant.destructive,
                    onPress: _isLoggingOut ? null : _logout,
                    child: _isLoggingOut
                        ? const FCircularProgress(
                            size: FCircularProgressSizeVariant.sm,
                          )
                        : Text(l10n.logoutAction),
                  ),
                  if (_logoutFailed) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.logoutError,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
