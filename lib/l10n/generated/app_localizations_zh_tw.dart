// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizations {
  AppLocalizationsZhTw([String locale = 'zh_TW']) : super(locale);

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

  @override
  String get loginTitle => '登入 Thulium';

  @override
  String get studentIdLabel => '清華學號';

  @override
  String get studentIdHint => '請輸入清華學號';

  @override
  String get passwordLabel => '密碼';

  @override
  String get passwordHint => '請輸入密碼';

  @override
  String get signInAction => '登入';

  @override
  String get requiredField => '此欄位為必填項目。';

  @override
  String get loginError => '登入失敗，請檢查學號和密碼後重試。';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get twoFactorTitle => '雙重驗證';

  @override
  String get wechatMethod => '企業微信';

  @override
  String smsMethod(Object phone) => '簡訊（$phone）';

  @override
  String get totpMethod => 'TOTP';

  @override
  String get verificationCodeTitle => '驗證碼';

  @override
  String get verificationCodeHint => '請輸入驗證碼';

  @override
  String get cancelAction => '取消';

  @override
  String get backAction => '返回';

  @override
  String get confirmAction => '確認';

  @override
  String get eventsTab => '事件';

  @override
  String get plansTab => '計畫';

  @override
  String get studyTab => '學習';

  @override
  String get lifeTab => '生活';

  @override
  String get eventsTitle => '學生事件';

  @override
  String get eventsDescription => '即將開始的課程、校曆提醒和其他與學生相關的事件將在這裡顯示。';

  @override
  String get plansTitle => '學生計畫';

  @override
  String get plansDescription => '你的課程表和自訂計畫將在這裡顯示。';

  @override
  String get studyTitle => '學習';

  @override
  String get studyDescription => '學習工具和學習資源將在這裡顯示。';

  @override
  String get lifeTitle => '生活';

  @override
  String get lifeDescription => '校園生活服務和日常工具將在這裡顯示。';
}
