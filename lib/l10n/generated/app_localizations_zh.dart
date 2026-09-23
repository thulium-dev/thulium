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

  @override
  String get loginTitle => '登录 Thulium';

  @override
  String get studentIdLabel => '清华学号';

  @override
  String get studentIdHint => '请输入清华学号';

  @override
  String get passwordLabel => '密码';

  @override
  String get passwordHint => '请输入密码';

  @override
  String get signInAction => '登录';

  @override
  String get requiredField => '此字段为必填项。';

  @override
  String get loginError => '登录失败，请检查学号和密码后重试。';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get twoFactorTitle => '二次认证';

  @override
  String get wechatMethod => '企业微信';

  @override
  String smsMethod(String phone) {
    return '短信（$phone）';
  }

  @override
  String get totpMethod => 'TOTP';

  @override
  String get verificationCodeTitle => '验证码';

  @override
  String get verificationCodeHint => '请输入验证码';

  @override
  String get confirmAction => '确认';
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

  @override
  String get loginTitle => '登录 Thulium';

  @override
  String get studentIdLabel => '清华学号';

  @override
  String get studentIdHint => '请输入清华学号';

  @override
  String get passwordLabel => '密码';

  @override
  String get passwordHint => '请输入密码';

  @override
  String get signInAction => '登录';

  @override
  String get requiredField => '此字段为必填项。';

  @override
  String get loginError => '登录失败，请检查学号和密码后重试。';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get twoFactorTitle => '二次认证';

  @override
  String get wechatMethod => '企业微信';

  @override
  String smsMethod(String phone) {
    return '短信（$phone）';
  }

  @override
  String get totpMethod => 'TOTP';

  @override
  String get verificationCodeTitle => '验证码';

  @override
  String get verificationCodeHint => '请输入验证码';

  @override
  String get confirmAction => '确认';
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
  String smsMethod(String phone) {
    return '簡訊（$phone）';
  }

  @override
  String get totpMethod => 'TOTP';

  @override
  String get verificationCodeTitle => '驗證碼';

  @override
  String get verificationCodeHint => '請輸入驗證碼';

  @override
  String get confirmAction => '確認';
}
