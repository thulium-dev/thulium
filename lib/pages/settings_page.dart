import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../widgets/app_page_scaffold.dart';
import '../diagnostics/diagnostic_export.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

/// Contains account and application settings for the authenticated user.
final class SettingsPage extends StatefulWidget {
  const SettingsPage({this.onLogout, this.exportDiagnostics, super.key});

  final Future<bool> Function()? onLogout;
  final Future<void> Function(Rect? sharePositionOrigin)? exportDiagnostics;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends State<SettingsPage> {
  bool _isLoggingOut = false;
  bool _logoutFailed = false;
  bool _isExporting = false;
  bool _exportFailed = false;
  final _exportKey = GlobalKey();

  Future<void> _exportDiagnostics() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _exportFailed = false;
    });
    final box = _exportKey.currentContext?.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      final export = widget.exportDiagnostics;
      if (export != null) {
        await export(origin);
      } else {
        await DiagnosticExport().export(
          title: AppLocalizations.of(context)!.exportDiagnostics,
          sharePositionOrigin: origin,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _exportFailed = true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
      _logoutFailed = false;
    });

    final succeeded = await widget.onLogout!();
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

    return AppPageScaffold(
      title: l10n.settingsTitle,
      maxWidth: 560,
      child: ListView(
        children: [
          FButton(
            key: _exportKey,
            variant: FButtonVariant.outline,
            onPress: _isExporting ? null : _exportDiagnostics,
            prefix: const Icon(FLucideIcons.fileText, size: 18),
            child: _isExporting
                ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
                : Text(l10n.exportDiagnostics),
          ),
          if (_exportFailed) ...[
            SizedBox(height: context.theme.style.pagePadding.top),
            Text(
              l10n.exportDiagnosticsError,
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.error,
              ),
            ),
          ],
          if (widget.onLogout != null) ...[
            SizedBox(height: context.theme.style.pagePadding.top),
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
              SizedBox(height: context.theme.style.pagePadding.top),
              Text(
                l10n.logoutError,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.error,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
