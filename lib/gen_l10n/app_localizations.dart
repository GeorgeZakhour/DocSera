import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose App Language'**
  String get chooseLanguage;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @logInAppbar.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logInAppbar;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @exitAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Application'**
  String get exitAppTitle;

  /// No description provided for @areYouSureToExit.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get areYouSureToExit;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'DocSera'**
  String get appName;

  /// No description provided for @myPractitioners.
  ///
  /// In en, this message translates to:
  /// **'My Practitioners'**
  String get myPractitioners;

  /// No description provided for @noPractitionersAdded.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any practitioners yet.'**
  String get noPractitionersAdded;

  /// No description provided for @unknownSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Unknown Specialty'**
  String get unknownSpecialty;

  /// No description provided for @bannerTitle1.
  ///
  /// In en, this message translates to:
  /// **'Important Health Alert'**
  String get bannerTitle1;

  /// No description provided for @bannerTitle2.
  ///
  /// In en, this message translates to:
  /// **'Important Health Alert'**
  String get bannerTitle2;

  /// No description provided for @bannerTitle3.
  ///
  /// In en, this message translates to:
  /// **'Important Health Alert'**
  String get bannerTitle3;

  /// No description provided for @bannerText1.
  ///
  /// In en, this message translates to:
  /// **'Recurring, cramp-like abdominal pain? Here\'s what could be behind it.'**
  String get bannerText1;

  /// No description provided for @bannerText2.
  ///
  /// In en, this message translates to:
  /// **'Discover the benefits of preventive healthcare.'**
  String get bannerText2;

  /// No description provided for @bannerText3.
  ///
  /// In en, this message translates to:
  /// **'Get a doctor’s consultation from your home!'**
  String get bannerText3;

  /// No description provided for @sponsored.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get sponsored;

  /// No description provided for @weAreHiring.
  ///
  /// In en, this message translates to:
  /// **'We Are Hiring!'**
  String get weAreHiring;

  /// No description provided for @workWithUs.
  ///
  /// In en, this message translates to:
  /// **'Work with us to grow together'**
  String get workWithUs;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'LEARN MORE'**
  String get learnMore;

  /// No description provided for @areYouAHealthProfessional.
  ///
  /// In en, this message translates to:
  /// **'Are you a health professional?'**
  String get areYouAHealthProfessional;

  /// No description provided for @improveDailyLife.
  ///
  /// In en, this message translates to:
  /// **'Improve your daily life with our solutions for health professionals.'**
  String get improveDailyLife;

  /// No description provided for @registerAsDoctor.
  ///
  /// In en, this message translates to:
  /// **'REGISTER AS A DOCTOR'**
  String get registerAsDoctor;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book an appointment'**
  String get bookAppointment;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from my favorite practitioners'**
  String get removeFromFavorites;

  /// No description provided for @yourDoctor.
  ///
  /// In en, this message translates to:
  /// **'Seamless Healthcare'**
  String get yourDoctor;

  /// No description provided for @anytime.
  ///
  /// In en, this message translates to:
  /// **'Anytime.'**
  String get anytime;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @fasterAccess.
  ///
  /// In en, this message translates to:
  /// **'Faster and easier access to care'**
  String get fasterAccess;

  /// No description provided for @fasterAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Book video or in-person appointments and get reminders so you never miss one.'**
  String get fasterAccessDescription;

  /// No description provided for @receiveCare.
  ///
  /// In en, this message translates to:
  /// **'Receive care on your terms'**
  String get receiveCare;

  /// No description provided for @receiveCareDescription.
  ///
  /// In en, this message translates to:
  /// **'Message your practitioners, get preventive advice and care when you need it.'**
  String get receiveCareDescription;

  /// No description provided for @manageHealth.
  ///
  /// In en, this message translates to:
  /// **'Manage your health'**
  String get manageHealth;

  /// No description provided for @manageHealthDescription.
  ///
  /// In en, this message translates to:
  /// **'Easily keep in one place all your health information and that of those who are important to you.'**
  String get manageHealthDescription;

  /// No description provided for @planAppointments.
  ///
  /// In en, this message translates to:
  /// **'Plan your appointments'**
  String get planAppointments;

  /// No description provided for @planAppointmentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Find a healthcare professional and book an appointment online at any time.'**
  String get planAppointmentsDescription;

  /// No description provided for @logInCapital.
  ///
  /// In en, this message translates to:
  /// **'LOG IN'**
  String get logInCapital;

  /// No description provided for @upcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingAppointments;

  /// No description provided for @pastAppointments.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get pastAppointments;

  /// No description provided for @noUpcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments'**
  String get noUpcomingAppointments;

  /// No description provided for @noPastAppointments.
  ///
  /// In en, this message translates to:
  /// **'No past appointments'**
  String get noPastAppointments;

  /// No description provided for @noAppointmentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Take charge of your health. Easily book your next appointment.'**
  String get noAppointmentsDescription;

  /// No description provided for @bookedOn.
  ///
  /// In en, this message translates to:
  /// **'Booked on: {date}'**
  String bookedOn(Object date);

  /// No description provided for @appointmentReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String appointmentReason(Object reason);

  /// No description provided for @patientName.
  ///
  /// In en, this message translates to:
  /// **'Patient: {name}'**
  String patientName(Object name);

  /// No description provided for @bookAgain.
  ///
  /// In en, this message translates to:
  /// **'Book again'**
  String get bookAgain;

  /// No description provided for @waitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get waitingConfirmation;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @loadMoreAppointments.
  ///
  /// In en, this message translates to:
  /// **'Load more..'**
  String get loadMoreAppointments;

  /// No description provided for @unknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown Date'**
  String get unknownDate;

  /// No description provided for @unknownTime.
  ///
  /// In en, this message translates to:
  /// **'Unknown Time'**
  String get unknownTime;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @cancelReasonQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why do you want to cancel this appointment?'**
  String get cancelReasonQuestion;

  /// No description provided for @typeReasonHere.
  ///
  /// In en, this message translates to:
  /// **'Type your reason here...'**
  String get typeReasonHere;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'You must provide a reason to cancel.'**
  String get reasonRequired;

  /// No description provided for @tooLateToCancel.
  ///
  /// In en, this message translates to:
  /// **'It\'s too late to cancel this appointment now.'**
  String get tooLateToCancel;

  /// No description provided for @notAllowed.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get notAllowed;

  /// No description provided for @cancelTimeLimitNote.
  ///
  /// In en, this message translates to:
  /// **'For the respect of doctors\' time and other patients, appointments must be cancelled at least 24 hours before the scheduled time. Late cancellations are not allowed.'**
  String get cancelTimeLimitNote;

  /// No description provided for @appointmentCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'The appointment has been successfully cancelled. You can book a new appointment at any time.'**
  String get appointmentCancelledMessage;

  /// No description provided for @toAppointmentPage.
  ///
  /// In en, this message translates to:
  /// **'Back to Appointments Page'**
  String get toAppointmentPage;

  /// No description provided for @tooLateToReschedule.
  ///
  /// In en, this message translates to:
  /// **'Too late to reschedule this appointment.'**
  String get tooLateToReschedule;

  /// No description provided for @rescheduleTimeLimitNote.
  ///
  /// In en, this message translates to:
  /// **'For the respect of doctors\' time and other patients, appointments must be rescheduled at least 24 hours before the scheduled time. Late rescheduling is not allowed.'**
  String get rescheduleTimeLimitNote;

  /// No description provided for @appointmentRescheduleNoWarning.
  ///
  /// In en, this message translates to:
  /// **'You can now proceed to reschedule.'**
  String get appointmentRescheduleNoWarning;

  /// No description provided for @noAvailableAppointmentsRes.
  ///
  /// In en, this message translates to:
  /// **'No other appointments are available for rescheduling.'**
  String get noAvailableAppointmentsRes;

  /// No description provided for @cancelInsteadNote.
  ///
  /// In en, this message translates to:
  /// **'You can cancel this appointment instead if needed.'**
  String get cancelInsteadNote;

  /// No description provided for @rescheduleReasonQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why do you want to reschedule this appointment?'**
  String get rescheduleReasonQuestion;

  /// No description provided for @confirmReschedule.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reschedule'**
  String get confirmReschedule;

  /// No description provided for @currentAppointment.
  ///
  /// In en, this message translates to:
  /// **'Current Appointment'**
  String get currentAppointment;

  /// No description provided for @newAppointment.
  ///
  /// In en, this message translates to:
  /// **'New Appointment'**
  String get newAppointment;

  /// No description provided for @manageDocuments.
  ///
  /// In en, this message translates to:
  /// **'Manage your documents'**
  String get manageDocuments;

  /// No description provided for @manageDocumentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Easily access your documents and share them with your practitioners at any time.'**
  String get manageDocumentsDescription;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @takeNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Take important notes\n about your health'**
  String get takeNotesTitle;

  /// No description provided for @takeNotesDescription.
  ///
  /// In en, this message translates to:
  /// **'For example, track symptoms, note mental health concerns, and prepare questions for your practitioners.'**
  String get takeNotesDescription;

  /// No description provided for @addDocument.
  ///
  /// In en, this message translates to:
  /// **'Add Document'**
  String get addDocument;

  /// No description provided for @uploadingDocument.
  ///
  /// In en, this message translates to:
  /// **'Uploading document...'**
  String get uploadingDocument;

  /// No description provided for @documentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The compressed file exceeds 2 MB. Please reduce the number of images or use smaller ones.'**
  String get documentTooLarge;

  /// No description provided for @pdfTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The PDF file is too large. Please use a file smaller than 2MB.'**
  String get pdfTooLarge;

  /// No description provided for @chooseAddDocumentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose a method'**
  String get chooseAddDocumentMethod;

  /// No description provided for @createNote.
  ///
  /// In en, this message translates to:
  /// **'Create Note'**
  String get createNote;

  /// No description provided for @sendRequests.
  ///
  /// In en, this message translates to:
  /// **'Send requests'**
  String get sendRequests;

  /// No description provided for @sendRequestsDescription.
  ///
  /// In en, this message translates to:
  /// **'You can send specific requests to your practitioners to ask about prescriptions, test results, referral letters, and more.'**
  String get sendRequestsDescription;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get sendMessage;

  /// No description provided for @easilySendMessages.
  ///
  /// In en, this message translates to:
  /// **'Easily send messages to practitioners'**
  String get easilySendMessages;

  /// No description provided for @sendMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with your practitioners. Ask about exam results, request referral letters, and more.'**
  String get sendMessagesDescription;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The total size of images is too large (max 4MB). Please reduce the number or size of images.'**
  String get fileTooLarge;

  /// No description provided for @chooseAttachmentType.
  ///
  /// In en, this message translates to:
  /// **'Send attachment'**
  String get chooseAttachmentType;

  /// No description provided for @welcomeDocsera.
  ///
  /// In en, this message translates to:
  /// **'Welcome to DocSera!'**
  String get welcomeDocsera;

  /// No description provided for @welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your appointments and stay connected.'**
  String get welcome_subtitle;

  /// No description provided for @login_button.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login_button;

  /// No description provided for @signup_button.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get signup_button;

  /// No description provided for @benefit_appointments.
  ///
  /// In en, this message translates to:
  /// **'Easy appointment booking'**
  String get benefit_appointments;

  /// No description provided for @benefit_reminders.
  ///
  /// In en, this message translates to:
  /// **'Receive automatic reminders'**
  String get benefit_reminders;

  /// No description provided for @benefit_history.
  ///
  /// In en, this message translates to:
  /// **'Track your appointment history'**
  String get benefit_history;

  /// No description provided for @benefit_chat.
  ///
  /// In en, this message translates to:
  /// **'Communicate directly with doctors'**
  String get benefit_chat;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @pointsHistory.
  ///
  /// In en, this message translates to:
  /// **'Points History'**
  String get pointsHistory;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get points;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @rewardPoints.
  ///
  /// In en, this message translates to:
  /// **'Earned Points'**
  String get rewardPoints;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again'**
  String get errorOccurred;

  /// No description provided for @completedAppointment.
  ///
  /// In en, this message translates to:
  /// **'Completed Appointment'**
  String get completedAppointment;

  /// No description provided for @withDoctor.
  ///
  /// In en, this message translates to:
  /// **'with'**
  String get withDoctor;

  /// No description provided for @onDate.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get onDate;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @doctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctor;

  /// No description provided for @relative.
  ///
  /// In en, this message translates to:
  /// **'Relative'**
  String get relative;

  /// No description provided for @accomplishedAt.
  ///
  /// In en, this message translates to:
  /// **'Accomplished at'**
  String get accomplishedAt;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @noName.
  ///
  /// In en, this message translates to:
  /// **'No name provided'**
  String get noName;

  /// No description provided for @birthDateNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Birth date not provided'**
  String get birthDateNotProvided;

  /// No description provided for @addressNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Address not provided'**
  String get addressNotProvided;

  /// No description provided for @didYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Did you know that?'**
  String get didYouKnow;

  /// No description provided for @didYouKnowDesc.
  ///
  /// In en, this message translates to:
  /// **'You can also book appointments for your relatives by creating dedicated profiles for them.'**
  String get didYouKnowDesc;

  /// No description provided for @manageMyRelatives.
  ///
  /// In en, this message translates to:
  /// **'Manage my relatives'**
  String get manageMyRelatives;

  /// No description provided for @relativeAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Relative added successfully!'**
  String get relativeAddedSuccess;

  /// No description provided for @relativeAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add relative: {error}'**
  String relativeAddFailed(Object error);

  /// No description provided for @arabicOnlyError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the text in Arabic only'**
  String get arabicOnlyError;

  /// No description provided for @numbersOnlyError.
  ///
  /// In en, this message translates to:
  /// **'Please enter numbers only'**
  String get numbersOnlyError;

  /// No description provided for @max3DigitsError.
  ///
  /// In en, this message translates to:
  /// **'Number must not exceed 3 digits'**
  String get max3DigitsError;

  /// No description provided for @editMyProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit my profile'**
  String get editMyProfile;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get selectGender;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @dateFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Format: DD.MM.YYYY'**
  String get dateFormatHint;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @street.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get street;

  /// No description provided for @buildingNr.
  ///
  /// In en, this message translates to:
  /// **'Building Nr.'**
  String get buildingNr;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @selectCity.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get selectCity;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get save;

  /// No description provided for @genderRequired.
  ///
  /// In en, this message translates to:
  /// **'Gender is required'**
  String get genderRequired;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get firstNameRequired;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get lastNameRequired;

  /// No description provided for @dobRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required'**
  String get dobRequired;

  /// No description provided for @buildingNrError.
  ///
  /// In en, this message translates to:
  /// **'Please fill Street, City, and Country before adding a Building Number.'**
  String get buildingNrError;

  /// No description provided for @updateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get updateSuccess;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile: {error}'**
  String updateFailed(Object error);

  /// No description provided for @infoText.
  ///
  /// In en, this message translates to:
  /// **'Changes made to your profile will be shared with your practitioners.'**
  String get infoText;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @minTwoLettersError.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least two letters'**
  String get minTwoLettersError;

  /// No description provided for @fillFullAddress.
  ///
  /// In en, this message translates to:
  /// **'Please fill Street, City, and Country before adding a Building Number.'**
  String get fillFullAddress;

  /// No description provided for @enterPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number (optional)'**
  String get enterPhoneOptional;

  /// No description provided for @enterEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter email (optional)'**
  String get enterEmailOptional;

  /// No description provided for @enterStreet.
  ///
  /// In en, this message translates to:
  /// **'Enter street'**
  String get enterStreet;

  /// No description provided for @enterBuildingOptional.
  ///
  /// In en, this message translates to:
  /// **'Enter building number (optional)'**
  String get enterBuildingOptional;

  /// No description provided for @authorizationStatement.
  ///
  /// In en, this message translates to:
  /// **'I declare that I am the legal representative of my relative, or that I am authorized to use the Doctolib services to manage medical data on their behalf.'**
  String get authorizationStatement;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @syria.
  ///
  /// In en, this message translates to:
  /// **'Syria'**
  String get syria;

  /// No description provided for @damascus.
  ///
  /// In en, this message translates to:
  /// **'Damascus'**
  String get damascus;

  /// No description provided for @reefDamascus.
  ///
  /// In en, this message translates to:
  /// **'Rif Dimashq'**
  String get reefDamascus;

  /// No description provided for @aleppo.
  ///
  /// In en, this message translates to:
  /// **'Aleppo'**
  String get aleppo;

  /// No description provided for @homs.
  ///
  /// In en, this message translates to:
  /// **'Homs'**
  String get homs;

  /// No description provided for @hama.
  ///
  /// In en, this message translates to:
  /// **'Hama'**
  String get hama;

  /// No description provided for @latakia.
  ///
  /// In en, this message translates to:
  /// **'Latakia'**
  String get latakia;

  /// No description provided for @deirEzzor.
  ///
  /// In en, this message translates to:
  /// **'Deir ez-Zor'**
  String get deirEzzor;

  /// No description provided for @raqqa.
  ///
  /// In en, this message translates to:
  /// **'Raqqa'**
  String get raqqa;

  /// No description provided for @idlib.
  ///
  /// In en, this message translates to:
  /// **'Idlib'**
  String get idlib;

  /// No description provided for @daraa.
  ///
  /// In en, this message translates to:
  /// **'Daraa'**
  String get daraa;

  /// No description provided for @tartus.
  ///
  /// In en, this message translates to:
  /// **'Tartus'**
  String get tartus;

  /// No description provided for @alHasakah.
  ///
  /// In en, this message translates to:
  /// **'Al-Hasakah'**
  String get alHasakah;

  /// No description provided for @qamishli.
  ///
  /// In en, this message translates to:
  /// **'Qamishli'**
  String get qamishli;

  /// No description provided for @suwayda.
  ///
  /// In en, this message translates to:
  /// **'Suwayda'**
  String get suwayda;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @myRelatives.
  ///
  /// In en, this message translates to:
  /// **'My relatives'**
  String get myRelatives;

  /// No description provided for @myRelativesDescription.
  ///
  /// In en, this message translates to:
  /// **'Add or manage relatives'**
  String get myRelativesDescription;

  /// No description provided for @editRelative.
  ///
  /// In en, this message translates to:
  /// **'Edit Relative'**
  String get editRelative;

  /// No description provided for @noRelativesTitle.
  ///
  /// In en, this message translates to:
  /// **'Look after your relatives on DocSera'**
  String get noRelativesTitle;

  /// No description provided for @noRelativesDesc.
  ///
  /// In en, this message translates to:
  /// **'Add your relatives to your account to manage their appointments and their health documents with ease.'**
  String get noRelativesDesc;

  /// No description provided for @bornOn.
  ///
  /// In en, this message translates to:
  /// **'Born on {date}'**
  String bornOn(Object date);

  /// No description provided for @bornOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Born on'**
  String get bornOnLabel;

  /// No description provided for @yearsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} years'**
  String yearsCount(Object count);

  /// No description provided for @manageAccessRights.
  ///
  /// In en, this message translates to:
  /// **'Manage access rights'**
  String get manageAccessRights;

  /// No description provided for @accessRightsFor.
  ///
  /// In en, this message translates to:
  /// **'Access rights for {name}'**
  String accessRightsFor(Object name);

  /// No description provided for @thisPersonCan.
  ///
  /// In en, this message translates to:
  /// **'This person can:'**
  String get thisPersonCan;

  /// No description provided for @bookRescheduleCancel.
  ///
  /// In en, this message translates to:
  /// **'Book, reschedule and cancel'**
  String get bookRescheduleCancel;

  /// No description provided for @allAppointments.
  ///
  /// In en, this message translates to:
  /// **'all appointments'**
  String get allAppointments;

  /// No description provided for @addAndManage.
  ///
  /// In en, this message translates to:
  /// **'Add and manage'**
  String get addAndManage;

  /// No description provided for @allDocuments.
  ///
  /// In en, this message translates to:
  /// **'all documents'**
  String get allDocuments;

  /// No description provided for @updateIdentity.
  ///
  /// In en, this message translates to:
  /// **'Update identity and'**
  String get updateIdentity;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'contact information'**
  String get contactInfo;

  /// No description provided for @removeThisRelative.
  ///
  /// In en, this message translates to:
  /// **'Remove this relative'**
  String get removeThisRelative;

  /// No description provided for @removeRelativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeRelativeTitle(Object name);

  /// No description provided for @removeRelativeDesc.
  ///
  /// In en, this message translates to:
  /// **'By removing this relative from your account, you will no longer have access to their documents or appointment history.'**
  String get removeRelativeDesc;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @relativeRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} has been removed as relative.'**
  String relativeRemoved(Object name);

  /// No description provided for @relativeRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove {name}: {error}'**
  String relativeRemoveFailed(Object error, Object name);

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get you;

  /// No description provided for @accountHolder.
  ///
  /// In en, this message translates to:
  /// **'Account Holder'**
  String get accountHolder;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number.\nIt must either start with 9 and be 9 digits, or start with 09 and be 10 digits.'**
  String get invalidPhoneNumber;

  /// No description provided for @addEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Email'**
  String get addEmailTitle;

  /// No description provided for @samePhone.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already in use.'**
  String get samePhone;

  /// No description provided for @sameEmail.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get sameEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// No description provided for @loginSection.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginSection;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHidden.
  ///
  /// In en, this message translates to:
  /// **'••••••••••••••••'**
  String get passwordHidden;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Account language settings'**
  String get languageDescription;

  /// No description provided for @twoFactorAuth.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twoFactorAuth;

  /// No description provided for @twoFactorAuthActivated.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get twoFactorAuthActivated;

  /// No description provided for @encryptedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Encrypted documents'**
  String get encryptedDocuments;

  /// No description provided for @encryptedDocumentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Secured your medical files'**
  String get encryptedDocumentsDescription;

  /// No description provided for @faceIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID'**
  String get faceIdTitle;

  /// No description provided for @faceIdDescription.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID to quickly and securely log in.'**
  String get faceIdDescription;

  /// No description provided for @fingerprintTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Fingerprint'**
  String get fingerprintTitle;

  /// No description provided for @fingerprintDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint to quickly and securely log in.'**
  String get fingerprintDescription;

  /// No description provided for @faceIdPrompt.
  ///
  /// In en, this message translates to:
  /// **'Authenticate with Face ID'**
  String get faceIdPrompt;

  /// No description provided for @fingerprintPrompt.
  ///
  /// In en, this message translates to:
  /// **'Authenticate with Fingerprint'**
  String get fingerprintPrompt;

  /// No description provided for @faceIdFailed.
  ///
  /// In en, this message translates to:
  /// **'Face ID authentication failed'**
  String get faceIdFailed;

  /// No description provided for @fingerprintFailed.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint authentication failed'**
  String get fingerprintFailed;

  /// No description provided for @biometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric Authentication'**
  String get biometricTitle;

  /// No description provided for @confidentiality.
  ///
  /// In en, this message translates to:
  /// **'Confidentiality'**
  String get confidentiality;

  /// No description provided for @myPreferences.
  ///
  /// In en, this message translates to:
  /// **'My preferences'**
  String get myPreferences;

  /// No description provided for @legalInformation.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get legalInformation;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// No description provided for @editPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Edit Phone Number'**
  String get editPhoneNumber;

  /// No description provided for @editEmail.
  ///
  /// In en, this message translates to:
  /// **'Edit Email'**
  String get editEmail;

  /// No description provided for @newPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'New phone number'**
  String get newPhoneNumber;

  /// No description provided for @newEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'New email address'**
  String get newEmailAddress;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @pleaseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your {fieldType}'**
  String pleaseConfirm(Object fieldType);

  /// No description provided for @sixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit verification code'**
  String get sixDigitCode;

  /// No description provided for @sentVerificationMessage.
  ///
  /// In en, this message translates to:
  /// **'We have sent you an {destination} to {messageType}.'**
  String sentVerificationMessage(Object destination, Object messageType);

  /// No description provided for @sms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get sms;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? Tap to resend.'**
  String get resendCode;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} sec'**
  String resendIn(Object seconds);

  /// No description provided for @phoneUpdatedWithoutVerification.
  ///
  /// In en, this message translates to:
  /// **'Phone updated without verification'**
  String get phoneUpdatedWithoutVerification;

  /// No description provided for @phoneUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Phone number verified and updated!'**
  String get phoneUpdatedSuccess;

  /// No description provided for @emailUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Email verified and updated!'**
  String get emailUpdatedSuccess;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueButton;

  /// No description provided for @verifyLater.
  ///
  /// In en, this message translates to:
  /// **'Verify later'**
  String get verifyLater;

  /// No description provided for @alreadyExistsPhone.
  ///
  /// In en, this message translates to:
  /// **'A DocSera account already exists with this phone number'**
  String get alreadyExistsPhone;

  /// No description provided for @alreadyExistsEmail.
  ///
  /// In en, this message translates to:
  /// **'A DocSera account already exists with this email'**
  String get alreadyExistsEmail;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @incorrectCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect current password'**
  String get incorrectCurrentPassword;

  /// No description provided for @passwordMatchError.
  ///
  /// In en, this message translates to:
  /// **'New password cannot be the same as current password'**
  String get passwordMatchError;

  /// No description provided for @passwordUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get passwordUpdatedSuccess;

  /// No description provided for @passwordUpdatedFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update password: {error}'**
  String passwordUpdatedFailed(Object error);

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not Verified'**
  String get notVerified;

  /// No description provided for @addressNotEntered.
  ///
  /// In en, this message translates to:
  /// **'Address not entered'**
  String get addressNotEntered;

  /// No description provided for @personalizedServices.
  ///
  /// In en, this message translates to:
  /// **'Personalized services'**
  String get personalizedServices;

  /// No description provided for @serviceImprovements.
  ///
  /// In en, this message translates to:
  /// **'Service improvements'**
  String get serviceImprovements;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @cookieManagement.
  ///
  /// In en, this message translates to:
  /// **'Cookie Management'**
  String get cookieManagement;

  /// No description provided for @termsAndConditionsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms and conditions of use'**
  String get termsAndConditionsOfUse;

  /// No description provided for @termsOfUseAgreement.
  ///
  /// In en, this message translates to:
  /// **'Terms of use agreement'**
  String get termsOfUseAgreement;

  /// No description provided for @personalDataProtectionPolicy.
  ///
  /// In en, this message translates to:
  /// **'Personal data protection policy'**
  String get personalDataProtectionPolicy;

  /// No description provided for @cookiePolicy.
  ///
  /// In en, this message translates to:
  /// **'Cookie policy'**
  String get cookiePolicy;

  /// No description provided for @legalNotice.
  ///
  /// In en, this message translates to:
  /// **'Legal notice'**
  String get legalNotice;

  /// No description provided for @reportIllicitContent.
  ///
  /// In en, this message translates to:
  /// **'Report illicit content'**
  String get reportIllicitContent;

  /// No description provided for @deleteAccountWarningText.
  ///
  /// In en, this message translates to:
  /// **'You can delete your DocSera account and associated data at any time. This will not automatically delete your personal data from the databases of the healthcare professionals with whom you have booked appointments. Healthcare professionals may have a legitimate interest in keeping your personal data. You are free to exercise your rights of access, rectification or deletion and contact them directly.'**
  String get deleteAccountWarningText;

  /// No description provided for @confirmDeleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'DELETE MY ACCOUNT'**
  String get confirmDeleteMyAccount;

  /// No description provided for @goodbyeMessage.
  ///
  /// In en, this message translates to:
  /// **'We\'re sad to see you go 😔'**
  String get goodbyeMessage;

  /// No description provided for @goodbyeSubtext.
  ///
  /// In en, this message translates to:
  /// **'Your account has been successfully deleted. We hope to see you again someday.'**
  String get goodbyeSubtext;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, specialty, clinic'**
  String get searchHint;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No Favorite Doctors'**
  String get noFavorites;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Results Found'**
  String get noResultsTitle;

  /// No description provided for @noResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try using another keyword or check your spelling.'**
  String get noResultsSubtitle;

  /// No description provided for @searchBySpecialty.
  ///
  /// In en, this message translates to:
  /// **'Search by specialty'**
  String get searchBySpecialty;

  /// No description provided for @nearbyMe.
  ///
  /// In en, this message translates to:
  /// **'Nearby me'**
  String get nearbyMe;

  /// No description provided for @cities.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get cities;

  /// No description provided for @selectCityPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select a city'**
  String get selectCityPlaceholder;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is denied. Please enable it in settings.'**
  String get locationPermissionDenied;

  /// No description provided for @locationError.
  ///
  /// In en, this message translates to:
  /// **'Unable to access your location. Please enable location services.'**
  String get locationError;

  /// No description provided for @showResults.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get showResults;

  /// No description provided for @specialtyGeneral.
  ///
  /// In en, this message translates to:
  /// **'General Medicine'**
  String get specialtyGeneral;

  /// No description provided for @specialtyInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal Medicine'**
  String get specialtyInternal;

  /// No description provided for @specialtyPediatrics.
  ///
  /// In en, this message translates to:
  /// **'Pediatrics'**
  String get specialtyPediatrics;

  /// No description provided for @specialtyGynecology.
  ///
  /// In en, this message translates to:
  /// **'Gynecology & Obstetrics'**
  String get specialtyGynecology;

  /// No description provided for @specialtyDentistry.
  ///
  /// In en, this message translates to:
  /// **'Dentistry'**
  String get specialtyDentistry;

  /// No description provided for @specialtyCardiology.
  ///
  /// In en, this message translates to:
  /// **'Cardiology & Vascular'**
  String get specialtyCardiology;

  /// No description provided for @specialtyENT.
  ///
  /// In en, this message translates to:
  /// **'Ear, Nose & Throat'**
  String get specialtyENT;

  /// No description provided for @specialtyOphthalmology.
  ///
  /// In en, this message translates to:
  /// **'Ophthalmology'**
  String get specialtyOphthalmology;

  /// No description provided for @specialtyOrthopedics.
  ///
  /// In en, this message translates to:
  /// **'Orthopedics'**
  String get specialtyOrthopedics;

  /// No description provided for @specialtyDermatology.
  ///
  /// In en, this message translates to:
  /// **'Dermatology'**
  String get specialtyDermatology;

  /// No description provided for @specialtyPsychology.
  ///
  /// In en, this message translates to:
  /// **'Psychiatry'**
  String get specialtyPsychology;

  /// No description provided for @specialtyNeurology.
  ///
  /// In en, this message translates to:
  /// **'Neurology'**
  String get specialtyNeurology;

  /// No description provided for @specialtyNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get specialtyNutrition;

  /// No description provided for @specialtyEndocrinology.
  ///
  /// In en, this message translates to:
  /// **'Endocrinology & Diabetes'**
  String get specialtyEndocrinology;

  /// No description provided for @specialtyUrology.
  ///
  /// In en, this message translates to:
  /// **'Urology'**
  String get specialtyUrology;

  /// No description provided for @specialtyGeneralSurgery.
  ///
  /// In en, this message translates to:
  /// **'General Surgery'**
  String get specialtyGeneralSurgery;

  /// No description provided for @specialtyGastro.
  ///
  /// In en, this message translates to:
  /// **'Gastroenterology'**
  String get specialtyGastro;

  /// No description provided for @specialtyPlastic.
  ///
  /// In en, this message translates to:
  /// **'Plastic Surgery'**
  String get specialtyPlastic;

  /// No description provided for @specialtyCancer.
  ///
  /// In en, this message translates to:
  /// **'Oncology'**
  String get specialtyCancer;

  /// No description provided for @specialtyEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency Medicine'**
  String get specialtyEmergency;

  /// No description provided for @specialtyPhysio.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapy'**
  String get specialtyPhysio;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @searchHere.
  ///
  /// In en, this message translates to:
  /// **'Search here'**
  String get searchHere;

  /// No description provided for @bookingNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Booking not available'**
  String get bookingNotAvailable;

  /// No description provided for @bothGenders.
  ///
  /// In en, this message translates to:
  /// **'Both genders'**
  String get bothGenders;

  /// No description provided for @noFilters.
  ///
  /// In en, this message translates to:
  /// **'No filters applied'**
  String get noFilters;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @moreFiltersSoon.
  ///
  /// In en, this message translates to:
  /// **'More filters coming soon'**
  String get moreFiltersSoon;

  /// No description provided for @maxDistance.
  ///
  /// In en, this message translates to:
  /// **'Max distance'**
  String get maxDistance;

  /// No description provided for @specialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialty;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get more;

  /// No description provided for @openInMapsApp.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps App'**
  String get openInMapsApp;

  /// No description provided for @messagesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not receiving messages'**
  String get messagesDisabled;

  /// No description provided for @patientsOnlyMessaging.
  ///
  /// In en, this message translates to:
  /// **'Messages only from patients'**
  String get patientsOnlyMessaging;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @openInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get openInMaps;

  /// No description provided for @additionalInformation.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get additionalInformation;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @specialtiesProcedures.
  ///
  /// In en, this message translates to:
  /// **'Specialties, procedures, and treatments'**
  String get specialtiesProcedures;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @openWebsite.
  ///
  /// In en, this message translates to:
  /// **'Open website'**
  String get openWebsite;

  /// No description provided for @contactInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformation;

  /// No description provided for @viewMore.
  ///
  /// In en, this message translates to:
  /// **'View More'**
  String get viewMore;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening Hours'**
  String get openingHours;

  /// No description provided for @languagesSpoken.
  ///
  /// In en, this message translates to:
  /// **'Languages Spoken'**
  String get languagesSpoken;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @clinicNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Clinic not available'**
  String get clinicNotAvailable;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faq;

  /// No description provided for @offeredServices.
  ///
  /// In en, this message translates to:
  /// **'Offered Services'**
  String get offeredServices;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageKurdish.
  ///
  /// In en, this message translates to:
  /// **'Kurdish'**
  String get languageKurdish;

  /// No description provided for @pleaseLoginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please log in to complete the booking'**
  String get pleaseLoginToContinue;

  /// No description provided for @noAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountQuestion;

  /// No description provided for @makeAppointment.
  ///
  /// In en, this message translates to:
  /// **'Make an Appointment'**
  String get makeAppointment;

  /// No description provided for @whoIsThisFor.
  ///
  /// In en, this message translates to:
  /// **'Who is this appointment for?'**
  String get whoIsThisFor;

  /// No description provided for @addRelative.
  ///
  /// In en, this message translates to:
  /// **'Add a relative'**
  String get addRelative;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'(Me)'**
  String get me;

  /// No description provided for @yearsOld.
  ///
  /// In en, this message translates to:
  /// **' years old'**
  String get yearsOld;

  /// No description provided for @cannotSendMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Message not allowed'**
  String get cannotSendMessageTitle;

  /// No description provided for @thisPatientCannotMessageDoctor.
  ///
  /// In en, this message translates to:
  /// **'Sorry, this patient cannot send a message to doctor'**
  String get thisPatientCannotMessageDoctor;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @haveYouVisitedBefore.
  ///
  /// In en, this message translates to:
  /// **'Have you visited this practitioner in the past?'**
  String get haveYouVisitedBefore;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @selectReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reason for this visit'**
  String get selectReasonTitle;

  /// No description provided for @selectReason.
  ///
  /// In en, this message translates to:
  /// **'Select the reason for this visit'**
  String get selectReason;

  /// No description provided for @noReasonsFound.
  ///
  /// In en, this message translates to:
  /// **'No appointment reasons found yet'**
  String get noReasonsFound;

  /// No description provided for @initialExamination.
  ///
  /// In en, this message translates to:
  /// **'Initial examination for new patient'**
  String get initialExamination;

  /// No description provided for @checkupFollowup.
  ///
  /// In en, this message translates to:
  /// **'Check-up / follow-up visit'**
  String get checkupFollowup;

  /// No description provided for @acuteSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Acute symptoms / emergency'**
  String get acuteSymptoms;

  /// No description provided for @availableAppointments.
  ///
  /// In en, this message translates to:
  /// **'Available Appointments'**
  String get availableAppointments;

  /// No description provided for @noAvailableAppointments.
  ///
  /// In en, this message translates to:
  /// **'No available appointments'**
  String get noAvailableAppointments;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show More appointments'**
  String get showMore;

  /// No description provided for @confirmAppointment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Appointment'**
  String get confirmAppointment;

  /// No description provided for @doctorInfo.
  ///
  /// In en, this message translates to:
  /// **'Doctor Information'**
  String get doctorInfo;

  /// No description provided for @clinicAddress.
  ///
  /// In en, this message translates to:
  /// **'Clinic Address'**
  String get clinicAddress;

  /// No description provided for @patientInfo.
  ///
  /// In en, this message translates to:
  /// **'Patient Information'**
  String get patientInfo;

  /// No description provided for @appointmentTime.
  ///
  /// In en, this message translates to:
  /// **'Appointment Time'**
  String get appointmentTime;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @slotReservedFor.
  ///
  /// In en, this message translates to:
  /// **'This slot is reserved for 15 minutes'**
  String get slotReservedFor;

  /// No description provided for @byConfirming.
  ///
  /// In en, this message translates to:
  /// **'By confirming this appointment, '**
  String get byConfirming;

  /// No description provided for @agreeToHonor.
  ///
  /// In en, this message translates to:
  /// **'you agree to honor it.'**
  String get agreeToHonor;

  /// No description provided for @for2.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get for2;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @appointmentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Appointment Confirmed'**
  String get appointmentConfirmed;

  /// No description provided for @appointmentConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'A confirmation has been sent to your email'**
  String get appointmentConfirmedMessage;

  /// No description provided for @addToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to my calendar'**
  String get addToCalendar;

  /// No description provided for @sendDocuments.
  ///
  /// In en, this message translates to:
  /// **'Send Documents'**
  String get sendDocuments;

  /// No description provided for @sentDocuments.
  ///
  /// In en, this message translates to:
  /// **'Attached Documents'**
  String get sentDocuments;

  /// No description provided for @sendDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send documents to your practitioner before your consultation'**
  String get sendDocumentsSubtitle;

  /// No description provided for @viewMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'View More Details'**
  String get viewMoreDetails;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @appointmentWith.
  ///
  /// In en, this message translates to:
  /// **'Appointment with {doctorName}'**
  String appointmentWith(Object doctorName);

  /// No description provided for @reasonForAppointment.
  ///
  /// In en, this message translates to:
  /// **'Reason for appointment'**
  String get reasonForAppointment;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @loginFirst.
  ///
  /// In en, this message translates to:
  /// **'Please log in first.'**
  String get loginFirst;

  /// No description provided for @slotAlreadyBooked.
  ///
  /// In en, this message translates to:
  /// **'Sorry, this time slot has just been booked. Please choose another time.'**
  String get slotAlreadyBooked;

  /// No description provided for @errorBookingAppointment.
  ///
  /// In en, this message translates to:
  /// **'Error booking appointment'**
  String get errorBookingAppointment;

  /// No description provided for @appointmentAddedToCalendar.
  ///
  /// In en, this message translates to:
  /// **'📅 Appointment added to your calendar!'**
  String get appointmentAddedToCalendar;

  /// No description provided for @appointmentFailedToAdd.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Failed to add appointment to the calendar.'**
  String get appointmentFailedToAdd;

  /// No description provided for @errorLoadingAppointments.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while loading appointments.'**
  String get errorLoadingAppointments;

  /// No description provided for @awaitingDoctorConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Doctor Confirmation'**
  String get awaitingDoctorConfirmation;

  /// No description provided for @waitingForDoctorToApprove.
  ///
  /// In en, this message translates to:
  /// **'Your request has been sent successfully. The doctor will review and approve the appointment shortly.'**
  String get waitingForDoctorToApprove;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @appointmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Appointment Details'**
  String get appointmentDetails;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @cancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel Appointment'**
  String get cancelAppointment;

  /// No description provided for @shareAppointmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Share appointment details'**
  String get shareAppointmentDetails;

  /// No description provided for @clinicDetails.
  ///
  /// In en, this message translates to:
  /// **'Details of the healthcare facility'**
  String get clinicDetails;

  /// No description provided for @openMap.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get openMap;

  /// No description provided for @backToDoctorProfile.
  ///
  /// In en, this message translates to:
  /// **'Back to {doctorName}\'s profile'**
  String backToDoctorProfile(Object doctorName);

  /// No description provided for @appointmentWithLabel.
  ///
  /// In en, this message translates to:
  /// **'Appointment with {doctorName}'**
  String appointmentWithLabel(Object doctorName);

  /// No description provided for @appointmentReason2.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String appointmentReason2(Object reason);

  /// No description provided for @appointmentLocation.
  ///
  /// In en, this message translates to:
  /// **'Location: {clinicName}'**
  String appointmentLocation(Object clinicName);

  /// No description provided for @appointmentDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String appointmentDate(Object date);

  /// No description provided for @appointmentTime2.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String appointmentTime2(Object time);

  /// No description provided for @sharedFromApp.
  ///
  /// In en, this message translates to:
  /// **'Shared from DocSera App'**
  String get sharedFromApp;

  /// No description provided for @youAreAboutToReschedule.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to move your appointment at the last minute'**
  String get youAreAboutToReschedule;

  /// No description provided for @youAreAboutToCancel.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to cancel your appointment at the last minute'**
  String get youAreAboutToCancel;

  /// No description provided for @lastMinuteWarning.
  ///
  /// In en, this message translates to:
  /// **'This appointment is in less than 48 hours. It is unlikely to be booked by another patient.'**
  String get lastMinuteWarning;

  /// No description provided for @respectPractitionerReschedule.
  ///
  /// In en, this message translates to:
  /// **'Out of respect to your practitioner, you should only move if absolutely necessary.'**
  String get respectPractitionerReschedule;

  /// No description provided for @respectPractitionerCancel.
  ///
  /// In en, this message translates to:
  /// **'Out of respect to your practitioner, you should only cancel if absolutely necessary.'**
  String get respectPractitionerCancel;

  /// No description provided for @continuing.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continuing;

  /// No description provided for @keepAppointment.
  ///
  /// In en, this message translates to:
  /// **'KEEP APPOINTMENT'**
  String get keepAppointment;

  /// No description provided for @cancelAppointmentAction.
  ///
  /// In en, this message translates to:
  /// **'CANCEL APPOINTMENT'**
  String get cancelAppointmentAction;

  /// No description provided for @appointmentRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Reschedule confirmed'**
  String get appointmentRescheduled;

  /// No description provided for @appointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment canceled'**
  String get appointmentCancelled;

  /// No description provided for @appointmentCancelNoWarning.
  ///
  /// In en, this message translates to:
  /// **'Appointment canceled without warning'**
  String get appointmentCancelNoWarning;

  /// No description provided for @doctorIdMissingError.
  ///
  /// In en, this message translates to:
  /// **'Doctor ID is missing. Unable to open profile.'**
  String get doctorIdMissingError;

  /// No description provided for @rescheduleWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to move your appointment at the last minute'**
  String get rescheduleWarningTitle;

  /// No description provided for @cancelWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to cancel your appointment at the last minute'**
  String get cancelWarningTitle;

  /// No description provided for @appointmentShortNoticeWarning.
  ///
  /// In en, this message translates to:
  /// **'This appointment is in less than 48 hours. It is unlikely to be booked by another patient.'**
  String get appointmentShortNoticeWarning;

  /// No description provided for @rescheduleRespectNotice.
  ///
  /// In en, this message translates to:
  /// **'Out of respect to your practitioner, you should only move if absolutely necessary'**
  String get rescheduleRespectNotice;

  /// No description provided for @cancelRespectNotice.
  ///
  /// In en, this message translates to:
  /// **'Out of respect to your practitioner, you should only cancel if absolutely necessary'**
  String get cancelRespectNotice;

  /// No description provided for @sendDocument.
  ///
  /// In en, this message translates to:
  /// **'Send document'**
  String get sendDocument;

  /// No description provided for @sendDocumentsLater.
  ///
  /// In en, this message translates to:
  /// **'Sending documents will be enabled later once the doctor app is ready'**
  String get sendDocumentsLater;

  /// No description provided for @sendDocumentsTo.
  ///
  /// In en, this message translates to:
  /// **'Send documents to'**
  String get sendDocumentsTo;

  /// No description provided for @beforeConsultation.
  ///
  /// In en, this message translates to:
  /// **'before consultation'**
  String get beforeConsultation;

  /// No description provided for @exampleDocuments.
  ///
  /// In en, this message translates to:
  /// **'For example, referral, test results, prescriptions'**
  String get exampleDocuments;

  /// No description provided for @sizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeLimit;

  /// No description provided for @acceptedFormat.
  ///
  /// In en, this message translates to:
  /// **'Accepted formats'**
  String get acceptedFormat;

  /// No description provided for @identificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Identification'**
  String get identificationTitle;

  /// No description provided for @registerOrLogin.
  ///
  /// In en, this message translates to:
  /// **'Register or Log in'**
  String get registerOrLogin;

  /// No description provided for @newToApp.
  ///
  /// In en, this message translates to:
  /// **'New to DocSera?'**
  String get newToApp;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get alreadyHaveAccount;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @emailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Email or Phone Number'**
  String get emailOrPhone;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email/phone or password'**
  String get incorrectPassword;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String loginError(Object error);

  /// No description provided for @faceIdNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'No saved credentials found for Face ID login.'**
  String get faceIdNoCredentials;

  /// No description provided for @logInWithFaceId.
  ///
  /// In en, this message translates to:
  /// **'Log in with Face ID'**
  String get logInWithFaceId;

  /// No description provided for @logInWithFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Log in with Fingerprint'**
  String get logInWithFingerprint;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get enterManually;

  /// No description provided for @useBiometricLogin.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID or Fingerprint to log in'**
  String get useBiometricLogin;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @biometricPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please verify using face or fingerprint'**
  String get biometricPrompt;

  /// No description provided for @logInFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials and try again.'**
  String get logInFailed;

  /// No description provided for @errorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'لا يوجد حساب بهذا البريد أو الرقم.'**
  String get errorUserNotFound;

  /// No description provided for @errorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'كلمة المرور غير صحيحة، يرجى المحاولة مجددًا.'**
  String get errorWrongPassword;

  /// No description provided for @errorGenericLogin.
  ///
  /// In en, this message translates to:
  /// **'فشل تسجيل الدخول، تحقق من البيانات وحاول مرة أخرى.'**
  String get errorGenericLogin;

  /// No description provided for @authenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating...'**
  String get authenticating;

  /// No description provided for @createAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get enterPhone;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get enterEmail;

  /// No description provided for @errorCheckingEmail.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while checking the email. Please try again.'**
  String get errorCheckingEmail;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'ُEmail already registered'**
  String get emailAlreadyRegistered;

  /// No description provided for @emailAlreadyRegisteredContent.
  ///
  /// In en, this message translates to:
  /// **'Email you entered is already registered in DocSera'**
  String get emailAlreadyRegisteredContent;

  /// No description provided for @phoneAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Phone number already registered'**
  String get phoneAlreadyRegistered;

  /// No description provided for @phoneAlreadyRegisteredContent.
  ///
  /// In en, this message translates to:
  /// **'Phone number you entered is already registered in DocSera'**
  String get phoneAlreadyRegisteredContent;

  /// No description provided for @loginWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Login with Email'**
  String get loginWithEmail;

  /// No description provided for @loginWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Login with Phone'**
  String get loginWithPhone;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @enterPersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter your personal information'**
  String get enterPersonalInfo;

  /// No description provided for @identity.
  ///
  /// In en, this message translates to:
  /// **'Identinty'**
  String get identity;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @enterDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Enter your date of birth'**
  String get enterDateOfBirth;

  /// No description provided for @dobHint.
  ///
  /// In en, this message translates to:
  /// **'DD.MM.YYYY'**
  String get dobHint;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a Password'**
  String get createPassword;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password strength: Weak'**
  String get weakPassword;

  /// No description provided for @fairPassword.
  ///
  /// In en, this message translates to:
  /// **'Password strength: Fair'**
  String get fairPassword;

  /// No description provided for @goodPassword.
  ///
  /// In en, this message translates to:
  /// **'Password strength: Good'**
  String get goodPassword;

  /// No description provided for @strongPassword.
  ///
  /// In en, this message translates to:
  /// **'Password strength: Strong'**
  String get strongPassword;

  /// No description provided for @useEightCharacters.
  ///
  /// In en, this message translates to:
  /// **'Use 8 characters or more for your password.'**
  String get useEightCharacters;

  /// No description provided for @passwordTooSimple.
  ///
  /// In en, this message translates to:
  /// **'Your password is too simple. Try adding special characters, numbers, and capital letters.'**
  String get passwordTooSimple;

  /// No description provided for @passwordRepeatedCharacters.
  ///
  /// In en, this message translates to:
  /// **'Avoid repeated characters like \'aaa\' or \'111\'.'**
  String get passwordRepeatedCharacters;

  /// No description provided for @termsOfUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use and Privacy Policy'**
  String get termsOfUseTitle;

  /// No description provided for @termsOfUseDescription.
  ///
  /// In en, this message translates to:
  /// **'To create a DocSera account, please accept the terms of use.'**
  String get termsOfUseDescription;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I have read and accepted the Terms of Use'**
  String get acceptTerms;

  /// No description provided for @dataProcessingInfo.
  ///
  /// In en, this message translates to:
  /// **'You can find more information on data processing in our '**
  String get dataProcessingInfo;

  /// No description provided for @dataProtectionNotice.
  ///
  /// In en, this message translates to:
  /// **'data protection notices.'**
  String get dataProtectionNotice;

  /// No description provided for @marketingPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay connected with our latest updates'**
  String get marketingPreferencesTitle;

  /// No description provided for @marketingPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get personalized emails and push notifications about health tips and our services.'**
  String get marketingPreferencesSubtitle;

  /// No description provided for @marketingCheckboxText.
  ///
  /// In en, this message translates to:
  /// **'Helpful tips to manage my health and marketing information about our services'**
  String get marketingCheckboxText;

  /// No description provided for @privacyPolicyInfo.
  ///
  /// In en, this message translates to:
  /// **'You can change your choice anytime in your settings. To learn more, '**
  String get privacyPolicyInfo;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'see the privacy policy.'**
  String get privacyPolicyLink;

  /// No description provided for @pleaseAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms to continue'**
  String get pleaseAcceptTerms;

  /// No description provided for @enterSmsCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to you by SMS'**
  String get enterSmsCode;

  /// No description provided for @enterEmailCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to you by Email'**
  String get enterEmailCode;

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit verification code'**
  String get otpLabel;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'This temporary code has been sent to:'**
  String get otpSentTo;

  /// No description provided for @didntReceiveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive a code?'**
  String get didntReceiveCode;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Please try again.'**
  String get invalidCode;

  /// No description provided for @otpSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP. Please try again.'**
  String get otpSendFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @reviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Please review your details:'**
  String get reviewDetails;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @mustBeOver16.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 16 years old'**
  String get mustBeOver16;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email Verified'**
  String get emailVerified;

  /// No description provided for @skipEmail.
  ///
  /// In en, this message translates to:
  /// **'Add email later'**
  String get skipEmail;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @phoneVerified.
  ///
  /// In en, this message translates to:
  /// **'Phone Verified'**
  String get phoneVerified;

  /// No description provided for @termsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Terms Accepted'**
  String get termsAccepted;

  /// No description provided for @marketingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Marketing Preferences'**
  String get marketingPreferences;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @registrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully!'**
  String get registrationSuccess;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to register user'**
  String get registrationFailed;

  /// No description provided for @autoLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to log in automatically.'**
  String get autoLoginFailed;

  /// No description provided for @emailAlreadyRegisteredAlt.
  ///
  /// In en, this message translates to:
  /// **'ُEmail already registered'**
  String get emailAlreadyRegisteredAlt;

  /// No description provided for @phoneAlreadyRegisteredAlt.
  ///
  /// In en, this message translates to:
  /// **'Phone number already registered'**
  String get phoneAlreadyRegisteredAlt;

  /// No description provided for @welcomeToDocsera.
  ///
  /// In en, this message translates to:
  /// **'Welcome to DocSera,'**
  String get welcomeToDocsera;

  /// No description provided for @welcomeMessageInfo.
  ///
  /// In en, this message translates to:
  /// **'Easily book your appointments, manage your medical files, and stay connected with doctors — all in one secure and fast place.'**
  String get welcomeMessageInfo;

  /// No description provided for @goToHomepage.
  ///
  /// In en, this message translates to:
  /// **'Go to Homepage'**
  String get goToHomepage;

  /// No description provided for @serverConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to the server. Please check your internet connection and try again.'**
  String get serverConnectionError;

  /// No description provided for @verificationError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while verifying the number: {errorMessage}'**
  String verificationError(Object errorMessage);

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again later.'**
  String get unexpectedError;

  /// No description provided for @documentAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Document added successfully!'**
  String get documentAddedSuccessfully;

  /// No description provided for @documentAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add document.'**
  String get documentAddFailed;

  /// No description provided for @switchToListView.
  ///
  /// In en, this message translates to:
  /// **'Switch to list view'**
  String get switchToListView;

  /// No description provided for @switchToGridView.
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get switchToGridView;

  /// No description provided for @addNewDocument.
  ///
  /// In en, this message translates to:
  /// **'Add new Document'**
  String get addNewDocument;

  /// No description provided for @addPage.
  ///
  /// In en, this message translates to:
  /// **'Add a page'**
  String get addPage;

  /// No description provided for @deletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete this page'**
  String get deletePage;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueText;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No description provided for @nameOfTheDocument.
  ///
  /// In en, this message translates to:
  /// **'Name of the document'**
  String get nameOfTheDocument;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @typeOfTheDocument.
  ///
  /// In en, this message translates to:
  /// **'Type of the document'**
  String get typeOfTheDocument;

  /// No description provided for @selectDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Select the document type'**
  String get selectDocumentType;

  /// No description provided for @patientConcerned.
  ///
  /// In en, this message translates to:
  /// **'Patient concerned'**
  String get patientConcerned;

  /// No description provided for @selectRelevantPatient.
  ///
  /// In en, this message translates to:
  /// **'Select the relevant patient'**
  String get selectRelevantPatient;

  /// No description provided for @documentWillBeEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This document will be encrypted'**
  String get documentWillBeEncrypted;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results Count'**
  String get results;

  /// No description provided for @medicalImaging.
  ///
  /// In en, this message translates to:
  /// **'Medical imaging'**
  String get medicalImaging;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @referralLetter.
  ///
  /// In en, this message translates to:
  /// **'Referral letter'**
  String get referralLetter;

  /// No description provided for @treatmentPlan.
  ///
  /// In en, this message translates to:
  /// **'Treatment plan'**
  String get treatmentPlan;

  /// No description provided for @identityProof.
  ///
  /// In en, this message translates to:
  /// **'Proof of identity (ID card, passport, residence permit)'**
  String get identityProof;

  /// No description provided for @insuranceProof.
  ///
  /// In en, this message translates to:
  /// **'Public insurance proof'**
  String get insuranceProof;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @sendToDoctor.
  ///
  /// In en, this message translates to:
  /// **'Send to a Doctor'**
  String get sendToDoctor;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @createdByYou.
  ///
  /// In en, this message translates to:
  /// **'Created by you • {date}'**
  String createdByYou(Object date);

  /// No description provided for @pagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Page(s)'**
  String pagesCount(Object count);

  /// No description provided for @pageSingular.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get pageSingular;

  /// No description provided for @pagePlural.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pagePlural;

  /// No description provided for @deleteTheDocument.
  ///
  /// In en, this message translates to:
  /// **'Delete the document'**
  String get deleteTheDocument;

  /// No description provided for @areYouSureToDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the document \"{name}\"?\nIf you shared it with a doctor, they will keep their copy.'**
  String areYouSureToDelete(Object name);

  /// No description provided for @documentUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded successfully'**
  String get documentUploadedSuccessfully;

  /// No description provided for @fileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'❌ Failed to load the file'**
  String get fileLoadFailed;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from Library'**
  String get chooseFromLibrary;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFile;

  /// No description provided for @deleteDocument.
  ///
  /// In en, this message translates to:
  /// **'Delete Document'**
  String get deleteDocument;

  /// No description provided for @confirmDeleteDocument.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this document?'**
  String get confirmDeleteDocument;

  /// No description provided for @downloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'The file has been downloaded successfully'**
  String get downloadSuccess;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Storage permission was denied'**
  String get permissionDenied;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload document. Please try again.'**
  String get uploadFailed;

  /// No description provided for @documentDetails.
  ///
  /// In en, this message translates to:
  /// **'Document details'**
  String get documentDetails;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get createdAt;

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get createdBy;

  /// No description provided for @encryptedDocument.
  ///
  /// In en, this message translates to:
  /// **'Encrypted document'**
  String get encryptedDocument;

  /// No description provided for @changeTheNameOfTheDocument.
  ///
  /// In en, this message translates to:
  /// **'Change the name of the document'**
  String get changeTheNameOfTheDocument;

  /// No description provided for @fillRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get fillRequiredFields;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get editNote;

  /// No description provided for @noteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note Title'**
  String get noteTitle;

  /// No description provided for @deleteTheNote.
  ///
  /// In en, this message translates to:
  /// **'Delete the note'**
  String get deleteTheNote;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @unsavedNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedNoteTitle;

  /// No description provided for @unsavedNoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save this note before exiting?'**
  String get unsavedNoteMessage;

  /// No description provided for @noteContent.
  ///
  /// In en, this message translates to:
  /// **'Write your note here...'**
  String get noteContent;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated at {time}'**
  String lastUpdated(Object time);

  /// No description provided for @sendMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get sendMessageTitle;

  /// No description provided for @messagingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Messaging unavailable'**
  String get messagingDisabled;

  /// No description provided for @selectMessagePatient.
  ///
  /// In en, this message translates to:
  /// **'Who is this message request for?'**
  String get selectMessagePatient;

  /// No description provided for @selectMessageReason.
  ///
  /// In en, this message translates to:
  /// **'What is the reason for this message?'**
  String get selectMessageReason;

  /// No description provided for @failedToLoadReasons.
  ///
  /// In en, this message translates to:
  /// **'Failed to load message reasons. Please try again later.'**
  String get failedToLoadReasons;

  /// No description provided for @noReasonsAddedByDoctor.
  ///
  /// In en, this message translates to:
  /// **'This doctor has not added any message reasons yet.'**
  String get noReasonsAddedByDoctor;

  /// No description provided for @noEmergencySupport.
  ///
  /// In en, this message translates to:
  /// **'Your practitioner cannot address medical emergencies by message. In case of a medical emergency, call 112.'**
  String get noEmergencySupport;

  /// No description provided for @reasonTestResults.
  ///
  /// In en, this message translates to:
  /// **'Request sending of test results'**
  String get reasonTestResults;

  /// No description provided for @reasonBill.
  ///
  /// In en, this message translates to:
  /// **'A bill or fees note'**
  String get reasonBill;

  /// No description provided for @reasonAppointment.
  ///
  /// In en, this message translates to:
  /// **'About a planned appointment'**
  String get reasonAppointment;

  /// No description provided for @reasonTreatmentUpdate.
  ///
  /// In en, this message translates to:
  /// **'Updates on treatment after consultation'**
  String get reasonTreatmentUpdate;

  /// No description provided for @reasonOpeningHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours and days'**
  String get reasonOpeningHours;

  /// No description provided for @reasonContract.
  ///
  /// In en, this message translates to:
  /// **'Treatment contract'**
  String get reasonContract;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @whatDoYouNeed.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get whatDoYouNeed;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @attachDocuments.
  ///
  /// In en, this message translates to:
  /// **'Attach documents'**
  String get attachDocuments;

  /// No description provided for @sendMyMessage.
  ///
  /// In en, this message translates to:
  /// **'SEND MY MESSAGE'**
  String get sendMyMessage;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Explain the reason for your message. Provide any relevant information to your practitioner.'**
  String get messageHint;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'What should I add in my request?'**
  String get helpTitle;

  /// No description provided for @helpMessage1.
  ///
  /// In en, this message translates to:
  /// **'Include essential, relevant, and necessary information for the physician to process your request.'**
  String get helpMessage1;

  /// No description provided for @helpMessage2.
  ///
  /// In en, this message translates to:
  /// **'If necessary (e.g., for a certificate of illness), the doctor may require you to make an appointment for an examination. In the event of an emergency, contact 112.'**
  String get helpMessage2;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @conversationClosed.
  ///
  /// In en, this message translates to:
  /// **'Conversation Closed'**
  String get conversationClosed;

  /// No description provided for @forPatient.
  ///
  /// In en, this message translates to:
  /// **'For patient'**
  String get forPatient;

  /// No description provided for @messageForPatient.
  ///
  /// In en, this message translates to:
  /// **'Message request for:'**
  String get messageForPatient;

  /// No description provided for @onBehalfOfPatient.
  ///
  /// In en, this message translates to:
  /// **'On behalf of {patientName}'**
  String onBehalfOfPatient(Object patientName);

  /// No description provided for @onBehalfOf.
  ///
  /// In en, this message translates to:
  /// **'On behalf of'**
  String get onBehalfOf;

  /// No description provided for @conversationClosedByDoctor.
  ///
  /// In en, this message translates to:
  /// **'This conversation has been closed by {doctorName}. You can no longer respond.'**
  String conversationClosedByDoctor(Object doctorName);

  /// No description provided for @sendNewRequest.
  ///
  /// In en, this message translates to:
  /// **'Send a new request'**
  String get sendNewRequest;

  /// No description provided for @writeYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Write your message...'**
  String get writeYourMessage;

  /// No description provided for @waitingDoctorReply.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the doctor to reply to your request.'**
  String get waitingDoctorReply;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @chooseFromLibrary2.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get chooseFromLibrary2;

  /// No description provided for @uploadPdf.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF file'**
  String get uploadPdf;

  /// No description provided for @attachedImage.
  ///
  /// In en, this message translates to:
  /// **'Attached image'**
  String get attachedImage;

  /// No description provided for @attachedImages.
  ///
  /// In en, this message translates to:
  /// **'Attached images'**
  String get attachedImages;

  /// No description provided for @maxImagesReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum 8 images.'**
  String get maxImagesReached;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get remaining;

  /// No description provided for @addToDocuments.
  ///
  /// In en, this message translates to:
  /// **'Add to Documents'**
  String get addToDocuments;

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get downloadAll;

  /// No description provided for @downloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Image downloaded successfully'**
  String get downloadCompleted;

  /// No description provided for @imagesDownloadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Images downloaded successfully'**
  String get imagesDownloadedSuccessfully;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download image'**
  String get downloadFailed;

  /// No description provided for @imagesDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download images'**
  String get imagesDownloadFailed;

  /// No description provided for @ofText.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get ofText;

  /// No description provided for @importedFromConversationWith.
  ///
  /// In en, this message translates to:
  /// **'Imported from the conversation with {name} on {date}'**
  String importedFromConversationWith(Object date, Object name);

  /// No description provided for @documentAccessInfo.
  ///
  /// In en, this message translates to:
  /// **'Only you can access and manage documents stored here.'**
  String get documentAccessInfo;

  /// No description provided for @notesAccessInfo.
  ///
  /// In en, this message translates to:
  /// **'Only you can access and manage your notes securely.'**
  String get notesAccessInfo;

  /// No description provided for @messageAccessInfo.
  ///
  /// In en, this message translates to:
  /// **'You can message your doctor directly here. All your conversations are securely stored and easily accessible.'**
  String get messageAccessInfo;

  /// No description provided for @accountPrivacyInfoLine1.
  ///
  /// In en, this message translates to:
  /// **'Your personal data stays personal.'**
  String get accountPrivacyInfoLine1;

  /// No description provided for @accountPrivacyInfoLine2.
  ///
  /// In en, this message translates to:
  /// **'We protect your information with industry-leading security.'**
  String get accountPrivacyInfoLine2;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Forget your password?'**
  String get forgotPasswordButton;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @activated.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get activated;

  /// No description provided for @notActivated.
  ///
  /// In en, this message translates to:
  /// **'Not activated'**
  String get notActivated;

  /// No description provided for @encryptedDocumentsFullDescription.
  ///
  /// In en, this message translates to:
  /// **'Your medical documents are securely stored with advanced encryption, ensuring that only you can access and manage them safely.'**
  String get encryptedDocumentsFullDescription;

  /// No description provided for @twoFactorAuthHeadline.
  ///
  /// In en, this message translates to:
  /// **'Extra security beyond your password'**
  String get twoFactorAuthHeadline;

  /// No description provided for @twoFactorAuthFullDescription.
  ///
  /// In en, this message translates to:
  /// **'For extra protection, a verification code is sent to you by email or SMS when you log in from a new device.'**
  String get twoFactorAuthFullDescription;

  /// No description provided for @activate2FA.
  ///
  /// In en, this message translates to:
  /// **'Activate Two-Factor Authentication'**
  String get activate2FA;

  /// No description provided for @deactivate2FA.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Two-Factor Authentication'**
  String get deactivate2FA;

  /// No description provided for @twoFactorDeactivateWarning.
  ///
  /// In en, this message translates to:
  /// **'Disabling 2FA will make your account less secure. Are you sure you want to proceed?'**
  String get twoFactorDeactivateWarning;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
