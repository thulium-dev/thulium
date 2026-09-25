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
  String get verificationCodeInvalid => '验证码不正确，请重试。';

  @override
  String get trustDeviceTitle => '信任此设备？';

  @override
  String get trustDeviceDescription =>
      '清华身份认证服务可能会记住此设备，减少后续验证码验证。请仅在你本人控制的设备上选择信任。';

  @override
  String get trustDeviceAction => '信任设备';

  @override
  String get notNowAction => '暂不';

  @override
  String get confirmAction => '确认';

  @override
  String get cancelAction => '取消';

  @override
  String get backAction => '返回';

  @override
  String get settingsTitle => '设置';

  @override
  String get logoutAction => '退出登录';

  @override
  String get logoutError => '无法清除已保存的登录状态，请重试。';

  @override
  String get eventsTab => '事件';

  @override
  String get plansTab => '计划';

  @override
  String get studyTab => '学习';

  @override
  String get lifeTab => '生活';

  @override
  String get eventsTitle => '学生事件';

  @override
  String get eventsDescription => '即将开始的课程、校历提醒和其他与学生相关的事件将在这里显示。';

  @override
  String get plansTitle => '学生计划';

  @override
  String get plansDescription => '你的教学日历和自定义计划将在这里显示。';

  @override
  String calendarWeek(int week) {
    return '第 $week 周';
  }

  @override
  String get calendarPreviousWeek => '上一周';

  @override
  String get calendarNextWeek => '下一周';

  @override
  String get calendarRefresh => '刷新日历';

  @override
  String get calendarExport => '导出日历（即将推出）';

  @override
  String get calendarLoading => '正在加载日历…';

  @override
  String get calendarLoadError => '无法加载教学日历。';

  @override
  String get calendarStaleCache => '更新失败，当前显示已保存的日历。';

  @override
  String get calendarRetry => '重试';

  @override
  String get calendarNoCourses => '本周没有课程。';

  @override
  String get calendarOverlappingPlans => '重叠的计划';

  @override
  String get studyTitle => '学习';

  @override
  String get studyDescription => '学习工具和学习资源将在这里显示。';

  @override
  String get lifeTitle => '生活';

  @override
  String get lifeDescription => '校园生活服务和日常工具将在这里显示。';
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
  String get verificationCodeInvalid => '验证码不正确，请重试。';

  @override
  String get trustDeviceTitle => '信任此设备？';

  @override
  String get trustDeviceDescription =>
      '清华身份认证服务可能会记住此设备，减少后续验证码验证。请仅在你本人控制的设备上选择信任。';

  @override
  String get trustDeviceAction => '信任设备';

  @override
  String get notNowAction => '暂不';

  @override
  String get confirmAction => '确认';

  @override
  String get cancelAction => '取消';

  @override
  String get backAction => '返回';

  @override
  String get settingsTitle => '设置';

  @override
  String get logoutAction => '退出登录';

  @override
  String get logoutError => '无法清除已保存的登录状态，请重试。';

  @override
  String get eventsTab => '事件';

  @override
  String get plansTab => '计划';

  @override
  String get studyTab => '学习';

  @override
  String get lifeTab => '生活';

  @override
  String get eventsTitle => '学生事件';

  @override
  String get eventsDescription => '即将开始的课程、校历提醒和其他与学生相关的事件将在这里显示。';

  @override
  String get plansTitle => '学生计划';

  @override
  String get plansDescription => '你的教学日历和自定义计划将在这里显示。';

  @override
  String calendarWeek(int week) {
    return '第 $week 周';
  }

  @override
  String get calendarPreviousWeek => '上一周';

  @override
  String get calendarNextWeek => '下一周';

  @override
  String get calendarRefresh => '刷新日历';

  @override
  String get calendarExport => '导出日历（即将推出）';

  @override
  String get calendarLoading => '正在加载日历…';

  @override
  String get calendarLoadError => '无法加载教学日历。';

  @override
  String get calendarStaleCache => '更新失败，当前显示已保存的日历。';

  @override
  String get calendarRetry => '重试';

  @override
  String get calendarNoCourses => '本周没有课程。';

  @override
  String get calendarOverlappingPlans => '重叠的计划';

  @override
  String get studyTitle => '学习';

  @override
  String get studyDescription => '学习工具和学习资源将在这里显示。';

  @override
  String get lifeTitle => '生活';

  @override
  String get lifeDescription => '校园生活服务和日常工具将在这里显示。';
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
  String get verificationCodeInvalid => '驗證碼不正確，請重試。';

  @override
  String get trustDeviceTitle => '信任此裝置？';

  @override
  String get trustDeviceDescription =>
      '清華身分驗證服務可能會記住此裝置，減少後續驗證碼驗證。請僅在你本人控制的裝置上選擇信任。';

  @override
  String get trustDeviceAction => '信任裝置';

  @override
  String get notNowAction => '暫不';

  @override
  String get confirmAction => '確認';

  @override
  String get cancelAction => '取消';

  @override
  String get backAction => '返回';

  @override
  String get settingsTitle => '設定';

  @override
  String get logoutAction => '登出';

  @override
  String get logoutError => '無法清除已儲存的登入狀態，請重試。';

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
  String get plansDescription => '你的教學日曆和自訂計畫將在這裡顯示。';

  @override
  String calendarWeek(int week) {
    return '第 $week 週';
  }

  @override
  String get calendarPreviousWeek => '上一週';

  @override
  String get calendarNextWeek => '下一週';

  @override
  String get calendarRefresh => '重新整理日曆';

  @override
  String get calendarExport => '匯出日曆（即將推出）';

  @override
  String get calendarLoading => '正在載入日曆…';

  @override
  String get calendarLoadError => '無法載入教學日曆。';

  @override
  String get calendarStaleCache => '更新失敗，目前顯示已儲存的日曆。';

  @override
  String get calendarRetry => '重試';

  @override
  String get calendarNoCourses => '本週沒有課程。';

  @override
  String get calendarOverlappingPlans => '重疊的計劃';

  @override
  String get studyTitle => '學習';

  @override
  String get studyDescription => '學習工具和學習資源將在這裡顯示。';

  @override
  String get lifeTitle => '生活';

  @override
  String get lifeDescription => '校園生活服務和日常工具將在這裡顯示。';
}
