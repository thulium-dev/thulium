// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Thulium';

  @override
  String get welcomeTitle => 'Welcome, THUer';

  @override
  String get welcomeDescription =>
      'Campus information, useful services, and everyday tools in one place.';

  @override
  String get explore => 'Explore';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get englishLanguage => 'English';

  @override
  String get simplifiedChineseLanguage => '简体中文';

  @override
  String get traditionalChineseLanguage => '繁體中文';

  @override
  String get loginTitle => 'Sign in to Thulium';

  @override
  String get studentIdLabel => 'Tsinghua student ID';

  @override
  String get studentIdHint => 'Enter your student ID';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get signInAction => 'Sign in';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get loginError =>
      'Sign-in failed. Check your student ID and password, then try again.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get twoFactorTitle => 'Two-factor authentication';

  @override
  String get wechatMethod => 'WeChat';

  @override
  String smsMethod(String phone) {
    return 'SMS ($phone)';
  }

  @override
  String get totpMethod => 'TOTP';

  @override
  String get verificationCodeTitle => 'Verification code';

  @override
  String get verificationCodeHint => 'Enter the verification code';

  @override
  String get confirmAction => 'Confirm';
}
