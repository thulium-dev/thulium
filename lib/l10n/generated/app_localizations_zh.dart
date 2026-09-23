// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Thulium';

  @override
  String get welcomeTitle => '你好，THUer';

  @override
  String get welcomeDescription => '校园信息、常用服务与生活工具，将在这里汇聚';

  @override
  String get explore => '开始探索';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get englishLanguage => 'English';

  @override
  String get simplifiedChineseLanguage => '简体中文';

  @override
  String get traditionalChineseLanguage => '繁體中文';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get appTitle => 'Thulium';

  @override
  String get welcomeTitle => '你好，THUer';

  @override
  String get welcomeDescription => '校园信息、常用服务与生活工具，将在这里汇聚';

  @override
  String get explore => '开始探索';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get englishLanguage => 'English';

  @override
  String get simplifiedChineseLanguage => '简体中文';

  @override
  String get traditionalChineseLanguage => '繁體中文';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Thulium';

  @override
  String get welcomeTitle => '你好，THUer';

  @override
  String get welcomeDescription => '校園資訊、常用服務與生活工具，將在這裡匯聚';

  @override
  String get explore => '開始探索';

  @override
  String get language => '語言';

  @override
  String get theme => '主題';

  @override
  String get englishLanguage => 'English';

  @override
  String get simplifiedChineseLanguage => '简体中文';

  @override
  String get traditionalChineseLanguage => '繁體中文';
}
