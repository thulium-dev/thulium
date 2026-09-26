import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh', 'CN'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Thulium'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome, THUer'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Campus information, useful services, and everyday tools in one place.'**
  String get welcomeDescription;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @simplifiedChineseLanguage.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get simplifiedChineseLanguage;

  /// No description provided for @traditionalChineseLanguage.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get traditionalChineseLanguage;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Thulium'**
  String get loginTitle;

  /// No description provided for @studentIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Tsinghua student ID'**
  String get studentIdLabel;

  /// No description provided for @studentIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your student ID'**
  String get studentIdHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @signInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInAction;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check your student ID and password, then try again.'**
  String get loginError;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @twoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twoFactorTitle;

  /// No description provided for @wechatMethod.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get wechatMethod;

  /// No description provided for @smsMethod.
  ///
  /// In en, this message translates to:
  /// **'SMS ({phone})'**
  String smsMethod(String phone);

  /// No description provided for @totpMethod.
  ///
  /// In en, this message translates to:
  /// **'TOTP'**
  String get totpMethod;

  /// No description provided for @verificationCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCodeTitle;

  /// No description provided for @verificationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get verificationCodeHint;

  /// No description provided for @verificationCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code was not accepted. Please try again.'**
  String get verificationCodeInvalid;

  /// No description provided for @trustDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust this device?'**
  String get trustDeviceTitle;

  /// No description provided for @trustDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Tsinghua may remember this device and ask for fewer verification codes. Only choose this on a device you control.'**
  String get trustDeviceDescription;

  /// No description provided for @trustDeviceAction.
  ///
  /// In en, this message translates to:
  /// **'Trust device'**
  String get trustDeviceAction;

  /// No description provided for @notNowAction.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNowAction;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @backAction.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backAction;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @logoutAction.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutAction;

  /// No description provided for @logoutError.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the saved session. Please try again.'**
  String get logoutError;

  /// No description provided for @eventsTab.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get eventsTab;

  /// No description provided for @plansTab.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plansTab;

  /// No description provided for @studyTab.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get studyTab;

  /// No description provided for @lifeTab.
  ///
  /// In en, this message translates to:
  /// **'Life'**
  String get lifeTab;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Student events'**
  String get eventsTitle;

  /// No description provided for @eventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Upcoming classes, academic calendar reminders, and other student-related events will appear here.'**
  String get eventsDescription;

  /// No description provided for @plansTitle.
  ///
  /// In en, this message translates to:
  /// **'Student plans'**
  String get plansTitle;

  /// No description provided for @plansDescription.
  ///
  /// In en, this message translates to:
  /// **'Your academic calendar and custom plans will appear here.'**
  String get plansDescription;

  /// No description provided for @calendarWeek.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String calendarWeek(int week);

  /// No description provided for @calendarPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get calendarPreviousWeek;

  /// No description provided for @calendarNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get calendarNextWeek;

  /// No description provided for @calendarRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh calendar'**
  String get calendarRefresh;

  /// No description provided for @calendarExport.
  ///
  /// In en, this message translates to:
  /// **'Export calendar (coming soon)'**
  String get calendarExport;

  /// No description provided for @calendarLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading calendar…'**
  String get calendarLoading;

  /// No description provided for @calendarLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the academic calendar.'**
  String get calendarLoadError;

  /// No description provided for @calendarStaleCache.
  ///
  /// In en, this message translates to:
  /// **'Showing a saved calendar because the latest update failed.'**
  String get calendarStaleCache;

  /// No description provided for @calendarRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get calendarRetry;

  /// No description provided for @calendarNoCourses.
  ///
  /// In en, this message translates to:
  /// **'No plans scheduled for this week.'**
  String get calendarNoCourses;

  /// No description provided for @calendarOverlappingPlans.
  ///
  /// In en, this message translates to:
  /// **'Overlapping plans'**
  String get calendarOverlappingPlans;

  /// No description provided for @planAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add plan'**
  String get planAddTitle;

  /// No description provided for @planName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get planName;

  /// No description provided for @planLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get planLocation;

  /// No description provided for @planDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get planDate;

  /// No description provided for @planStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get planStartTime;

  /// No description provided for @planEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get planEndTime;

  /// No description provided for @planCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get planCategory;

  /// No description provided for @planLessonCategory.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get planLessonCategory;

  /// No description provided for @planNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get planNewCategory;

  /// No description provided for @planCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get planCategoryName;

  /// No description provided for @planCategoryColor.
  ///
  /// In en, this message translates to:
  /// **'Category color'**
  String get planCategoryColor;

  /// No description provided for @planCategoryDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exists.'**
  String get planCategoryDuplicate;

  /// No description provided for @planRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get planRepeat;

  /// No description provided for @planRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get planRepeatNone;

  /// No description provided for @planRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get planRepeatDaily;

  /// No description provided for @planRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get planRepeatWeekly;

  /// No description provided for @planRepeatInterval.
  ///
  /// In en, this message translates to:
  /// **'Every N days'**
  String get planRepeatInterval;

  /// No description provided for @planRepeatEveryDays.
  ///
  /// In en, this message translates to:
  /// **'Every {days} days'**
  String planRepeatEveryDays(int days);

  /// No description provided for @planIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'Interval in days'**
  String get planIntervalDays;

  /// No description provided for @planIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number of days.'**
  String get planIntervalInvalid;

  /// No description provided for @planTimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a date, start time, and end time.'**
  String get planTimeRequired;

  /// No description provided for @planEndAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End time must be later than start time on the same day.'**
  String get planEndAfterStart;

  /// No description provided for @planSave.
  ///
  /// In en, this message translates to:
  /// **'Save plan'**
  String get planSave;

  /// No description provided for @planSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this plan. Please try again.'**
  String get planSaveError;

  /// No description provided for @planEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get planEditTitle;

  /// No description provided for @planSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get planSaveChanges;

  /// No description provided for @planDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan details'**
  String get planDetailsTitle;

  /// No description provided for @planTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get planTimeRange;

  /// No description provided for @planEditOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Edit this occurrence'**
  String get planEditOccurrence;

  /// No description provided for @planEditSeries.
  ///
  /// In en, this message translates to:
  /// **'Edit entire series'**
  String get planEditSeries;

  /// No description provided for @planEditSeriesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This plan does not repeat'**
  String get planEditSeriesUnavailable;

  /// No description provided for @planDeleteSeries.
  ///
  /// In en, this message translates to:
  /// **'Delete entire series'**
  String get planDeleteSeries;

  /// No description provided for @planDeleteOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get planDeleteOccurrence;

  /// No description provided for @planCancelOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Cancel this occurrence'**
  String get planCancelOccurrence;

  /// No description provided for @planConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete plan?'**
  String get planConfirmDeleteTitle;

  /// No description provided for @planConfirmCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel occurrence?'**
  String get planConfirmCancelTitle;

  /// No description provided for @planConfirmFetchedLesson.
  ///
  /// In en, this message translates to:
  /// **'This lesson will be hidden in Thulium only. School calendar data will not be changed.'**
  String get planConfirmFetchedLesson;

  /// No description provided for @planConfirmDeleteSeries.
  ///
  /// In en, this message translates to:
  /// **'Every occurrence of this repeating plan will be deleted, including individual edits.'**
  String get planConfirmDeleteSeries;

  /// No description provided for @planConfirmOneOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Only this occurrence will be removed. Other occurrences will remain.'**
  String get planConfirmOneOccurrence;

  /// No description provided for @planDontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again for this action'**
  String get planDontAskAgain;

  /// No description provided for @planDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get planDeleteAction;

  /// No description provided for @planCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel once'**
  String get planCancelAction;

  /// No description provided for @studyTitle.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get studyTitle;

  /// No description provided for @studyDescription.
  ///
  /// In en, this message translates to:
  /// **'Study tools and learning resources will appear here.'**
  String get studyDescription;

  /// No description provided for @lifeTitle.
  ///
  /// In en, this message translates to:
  /// **'Life'**
  String get lifeTitle;

  /// No description provided for @lifeDescription.
  ///
  /// In en, this message translates to:
  /// **'Campus life services and everyday tools will appear here.'**
  String get lifeDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
