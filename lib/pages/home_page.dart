// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import '../widgets/language_button.dart';
import 'settings_page.dart';
import 'calendar_page.dart';

/// The authenticated application shell with the primary navigation sections.
final class HomePage extends StatefulWidget {
  const HomePage({
    required this.onLocaleSelected,
    required this.onThemeToggle,
    required this.onLogout,
    required this.onSessionExpired,
    this.sessionStore,
    super.key,
  });

  final ValueChanged<Locale> onLocaleSelected;
  final VoidCallback onThemeToggle;
  final Future<bool> Function() onLogout;
  final VoidCallback onSessionExpired;
  final AuthSessionStore? sessionStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends State<HomePage> {
  static const _HEADER_ICON_SIZE = 40.0;
  static const _HEADER_TOP = 4.0;
  static const _CALENDAR_TOP = _HEADER_TOP + _HEADER_ICON_SIZE + 4.0;

  int _selectedIndex = 0;
  bool _hasOpenedPlans = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      (title: l10n.eventsTitle, description: l10n.eventsDescription),
      (title: l10n.plansTitle, description: l10n.plansDescription),
      (title: l10n.studyTitle, description: l10n.studyDescription),
      (title: l10n.lifeTitle, description: l10n.lifeDescription),
    ];
    final labels = [l10n.eventsTab, l10n.plansTab, l10n.studyTab, l10n.lifeTab];
    final icons = [
      Icons.event_outlined,
      Icons.calendar_month_outlined,
      Icons.menu_book_outlined,
      Icons.home_outlined,
    ];

    return FScaffold(
      footer: FBottomNavigationBar(
        index: _selectedIndex,
        onChange: (index) => setState(() {
          _selectedIndex = index;
          if (index == 1) _hasOpenedPlans = true;
        }),
        children: [
          for (var index = 0; index < labels.length; index++)
            MergeSemantics(
              child: Semantics(
                label: labels[index],
                button: true,
                selected: index == _selectedIndex,
                child: FBottomNavigationBarItem(icon: Icon(icons[index])),
              ),
            ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (_selectedIndex != 1)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sections[_selectedIndex].title,
                          style: context.theme.typography.xl2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sections[_selectedIndex].description,
                          style: context.theme.typography.md,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_hasOpenedPlans)
              Positioned.fill(
                top: _CALENDAR_TOP,
                child: Offstage(
                  offstage: _selectedIndex != 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                    child: AcademicCalendarPage(
                      sessionStore: widget.sessionStore,
                      onSessionExpired: widget.onSessionExpired,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: _HEADER_TOP,
              left: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LanguageButton(
                    onSelected: widget.onLocaleSelected,
                    buttonSize: _HEADER_ICON_SIZE,
                  ),
                  SizedBox.square(
                    dimension: _HEADER_ICON_SIZE,
                    child: IconButton(
                      tooltip: l10n.theme,
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: Icon(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      onPressed: widget.onThemeToggle,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: _HEADER_TOP,
              right: 8,
              child: SizedBox.square(
                dimension: _HEADER_ICON_SIZE,
                child: IconButton(
                  tooltip: l10n.settingsTitle,
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsPage(onLogout: widget.onLogout),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
