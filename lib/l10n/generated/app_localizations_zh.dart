// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '清华便利';

  @override
  String get welcomeTitle => '你好，清华同学';

  @override
  String get welcomeDescription => '校园信息、常用服务与生活工具，将在这里汇聚。';

  @override
  String get explore => '开始探索';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get appTitle => '清华便利';

  @override
  String get welcomeTitle => '你好，清华同学';

  @override
  String get welcomeDescription => '校园信息、常用服务与生活工具，将在这里汇聚。';

  @override
  String get explore => '开始探索';
}
