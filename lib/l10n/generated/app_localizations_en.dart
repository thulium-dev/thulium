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
  String get verificationCodeInvalid =>
      'That code was not accepted. Please try again.';

  @override
  String get trustDeviceTitle => 'Trust this device?';

  @override
  String get trustDeviceDescription =>
      'Tsinghua may remember this device and ask for fewer verification codes. Only choose this on a device you control.';

  @override
  String get trustDeviceAction => 'Trust device';

  @override
  String get notNowAction => 'Not now';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get backAction => 'Back';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get logoutAction => 'Log out';

  @override
  String get logoutError =>
      'Could not clear the saved session. Please try again.';

  @override
  String get eventsTab => 'Events';

  @override
  String get plansTab => 'Plans';

  @override
  String get studyTab => 'Study';

  @override
  String get lifeTab => 'Life';

  @override
  String get eventsTitle => 'Student events';

  @override
  String get eventsDescription =>
      'Upcoming classes, academic calendar reminders, and other student-related events will appear here.';

  @override
  String get plansTitle => 'Student plans';

  @override
  String get plansDescription =>
      'Your academic calendar and custom plans will appear here.';

  @override
  String calendarWeek(int week) {
    return 'Week $week';
  }

  @override
  String get calendarPreviousWeek => 'Previous week';

  @override
  String get calendarNextWeek => 'Next week';

  @override
  String get calendarRefresh => 'Refresh calendar';

  @override
  String get calendarExport => 'Export calendar';

  @override
  String get calendarExportDialogTitle => 'Export calendar';

  @override
  String get calendarExportRange => 'Date range';

  @override
  String get calendarExportCurrentWeek => 'Current week';

  @override
  String get calendarExportEntireTerm => 'Entire term';

  @override
  String get calendarExportSchoolCourses => 'School courses';

  @override
  String get calendarExportPersonalPlans => 'Personal plans';

  @override
  String get calendarExportAction => 'Export';

  @override
  String get calendarExportNoEvents =>
      'No events are available for the selected options.';

  @override
  String get calendarExportFailed =>
      'Could not export the calendar. Please try again.';

  @override
  String get calendarExportSaved => 'Calendar file saved.';

  @override
  String get calendarLoading => 'Loading calendar…';

  @override
  String get calendarLoadError => 'Could not load the academic calendar.';

  @override
  String get calendarStaleCache =>
      'Showing a saved calendar because the latest update failed.';

  @override
  String get calendarRetry => 'Retry';

  @override
  String get calendarNoCourses => 'No plans scheduled for this week.';

  @override
  String get calendarOverlappingPlans => 'Overlapping plans';

  @override
  String get planAddTitle => 'Add plan';

  @override
  String get planName => 'Name';

  @override
  String get planLocation => 'Location';

  @override
  String get planDate => 'Date';

  @override
  String get planStartTime => 'Start time';

  @override
  String get planEndTime => 'End time';

  @override
  String get planCategory => 'Category';

  @override
  String get planLessonCategory => 'Lesson';

  @override
  String get planNewCategory => 'New category';

  @override
  String get planCategoryName => 'Category name';

  @override
  String get planCategoryColor => 'Category color';

  @override
  String get planCategoryDuplicate =>
      'A category with this name already exists.';

  @override
  String get planRepeat => 'Repeat';

  @override
  String get planRepeatNone => 'Never';

  @override
  String get planRepeatDaily => 'Daily';

  @override
  String get planRepeatWeekly => 'Weekly';

  @override
  String get planRepeatInterval => 'Every N days';

  @override
  String planRepeatEveryDays(int days) {
    return 'Every $days days';
  }

  @override
  String get planIntervalDays => 'Interval in days';

  @override
  String get planIntervalInvalid => 'Enter a positive number of days.';

  @override
  String get planTimeRequired => 'Choose a date, start time, and end time.';

  @override
  String get planEndAfterStart =>
      'End time must be later than start time on the same day.';

  @override
  String get planSave => 'Save plan';

  @override
  String get planSaveError => 'Could not save this plan. Please try again.';

  @override
  String get planEditTitle => 'Edit plan';

  @override
  String get planSaveChanges => 'Save changes';

  @override
  String get planDetailsTitle => 'Plan details';

  @override
  String get planTimeRange => 'Time';

  @override
  String get planEditOccurrence => 'Edit this occurrence';

  @override
  String get planEditSeries => 'Edit entire series';

  @override
  String get planEditSeriesUnavailable => 'This plan does not repeat';

  @override
  String get planDeleteSeries => 'Delete entire series';

  @override
  String get planDeleteOccurrence => 'Delete plan';

  @override
  String get planCancelOccurrence => 'Cancel this occurrence';

  @override
  String get planConfirmDeleteTitle => 'Delete plan?';

  @override
  String get planConfirmCancelTitle => 'Cancel occurrence?';

  @override
  String get planConfirmFetchedLesson =>
      'This lesson will be hidden in Thulium only. School calendar data will not be changed.';

  @override
  String get planConfirmDeleteSeries =>
      'Every occurrence of this repeating plan will be deleted, including individual edits.';

  @override
  String get planConfirmOneOccurrence =>
      'Only this occurrence will be removed. Other occurrences will remain.';

  @override
  String get planDontAskAgain => 'Don\'t ask again for this action';

  @override
  String get planDeleteAction => 'Delete';

  @override
  String get planCancelAction => 'Cancel once';

  @override
  String get studyTitle => 'Study';

  @override
  String get studyDescription =>
      'Study tools and learning resources will appear here.';

  @override
  String get lifeTitle => 'Life';

  @override
  String get lifeDescription =>
      'Campus life services and everyday tools will appear here.';
}
