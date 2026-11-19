import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../l10n/generated/app_localizations.dart';

/// Shared shell navigation, with visible labels and explicit selection semantics.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.index,
    required this.onChange,
    super.key,
  });

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [l10n.eventsTab, l10n.plansTab, l10n.studyTab, l10n.lifeTab];
    const icons = [
      Icons.event_outlined,
      Icons.calendar_month_outlined,
      Icons.menu_book_outlined,
      Icons.home_outlined,
    ];
    return FBottomNavigationBar(
      safeAreaBottom: true,
      index: index,
      onChange: onChange,
      children: [
        for (var item = 0; item < labels.length; item++)
          MergeSemantics(
            child: Semantics(
              button: true,
              selected: index == item,
              child: FBottomNavigationBarItem(
                icon: Icon(icons[item]),
                label: Text(labels[item]),
              ),
            ),
          ),
      ],
    );
  }
}
