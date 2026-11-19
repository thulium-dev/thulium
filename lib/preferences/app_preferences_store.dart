import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Installation preferences are independent of accounts and login credentials.
final class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
  });

  final ThemeMode themeMode;
  final Locale locale;

  factory AppPreferences.decode(String encoded) {
    final Object? value;
    try {
      value = jsonDecode(encoded);
    } on FormatException {
      return const AppPreferences();
    }
    if (value is! Map) return const AppPreferences();
    return AppPreferences(
      themeMode: switch (value['theme']) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      locale: switch (value['locale']) {
        'zh-CN' => const Locale('zh', 'CN'),
        'zh-TW' => const Locale('zh', 'TW'),
        'zh' => const Locale('zh'),
        _ => const Locale('en'),
      },
    );
  }

  String encode() =>
      jsonEncode({'theme': themeMode.name, 'locale': locale.toLanguageTag()});
}

abstract interface class AppPreferencesStore {
  Future<AppPreferences> read();
  Future<void> write(AppPreferences preferences);
}

final class LocalAppPreferencesStore implements AppPreferencesStore {
  // ignore: constant_identifier_names
  static const _PREFERENCES_KEY = 'thulium.preferences.v1';
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _storage =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<AppPreferences> read() async {
    final encoded = await _storage.getString(_PREFERENCES_KEY);
    return encoded == null
        ? const AppPreferences()
        : AppPreferences.decode(encoded);
  }

  @override
  Future<void> write(AppPreferences preferences) =>
      _storage.setString(_PREFERENCES_KEY, preferences.encode());
}
