// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get chooseLanguage => 'اختر لغة التطبيق';

  @override
  String get logIn => 'تسجيل الدخول';

  @override
  String get logInAppbar => 'تسجيل\nالدخول';

  @override
  String get home => 'الرئيسية';

  @override
  String get appointments => 'المواعيد';

  @override
  String get documents => 'المستندات';

  @override
  String get messages => 'الرسائل';

  @override
  String get account => 'الحساب';

  @override
  String get exitAppTitle => 'الخروج من التطبيق';

  @override
  String get areYouSureToExit => 'هل أنت متأكد أنك تريد الخروج من التطبيق؟';

  @override
  String get exit => 'خروج';

  @override
  String get cancel => 'إلغاء';

  @override
  String get appName => 'DocSera';

  @override
  String get myPractitioners => 'الأطباء المفضلين';

  @override
  String get noPractitionersAdded => 'لم تقم بإضافة أي أطباء مفضلين بعد.';

  @override
  String get unknownSpecialty => 'تخصص غير معروف';

  @override
  String get bannerTitle1 => 'تنبيه صحي هام';

  @override
  String get bannerTitle2 => 'تنبيه صحي هام';

  @override
  String get bannerTitle3 => 'تنبيه صحي هام';

  @override
  String get bannerText1 => 'ألم بطني متكرر يشبه التقلصات؟ إليك ما قد يكون السبب وراءه.';

  @override
  String get bannerText2 => 'اكتشف فوائد الرعاية الصحية الوقائية.';

  @override
  String get bannerText3 => 'احصل على استشارة طبية من منزلك!';

  @override
  String get sponsored => 'إعلان مدفوع';

  @override
  String get weAreHiring => 'نحن نوظف!';

  @override
  String get workWithUs => 'اعمل معنا للنمو معًا';

  @override
  String get learnMore => 'اعرف المزيد';

  @override
  String get areYouAHealthProfessional => 'هل أنت طبيب؟';

  @override
  String get improveDailyLife => 'حسن حياتك اليومية مع حلولنا للمحترفين الصحيين.';

  @override
  String get registerAsDoctor => 'سجل كطبيب';

  @override
  String get bookAppointment => 'احجز موعدًا';

  @override
  String get viewProfile => 'عرض الملف الشخصي';

  @override
  String get removeFromFavorites => 'إزالة من الأطباء المفضلين';

  @override
  String get yourDoctor => 'دكتورك معنا...';

  @override
  String get anytime => 'دايماً موجود';

  @override
  String get search => 'بحث';

  @override
  String get fasterAccess => 'وصول أسرع وأسهل إلى الرعاية';

  @override
  String get fasterAccessDescription => 'احجز مواعيد للزيارات الشخصية واحصل على تذكيرات حتى لا تفوت أي موعد.';

  @override
  String get receiveCare => 'احصل على الرعاية بشروطك';

  @override
  String get receiveCareDescription => 'تواصل مع الأطباء، واحصل على نصائح وقائية ورعاية عند الحاجة.';

  @override
  String get manageHealth => 'إدارة صحتك';

  @override
  String get manageHealthDescription => 'احتفظ بسهولة بجميع معلوماتك الصحية ومعلومات من يهمك أمرهم في مكان واحد.';

  @override
  String get planAppointments => 'خطط لمواعيدك';

  @override
  String get planAppointmentsDescription => 'ابحث عن محترف صحي واحجز موعدك عبر الإنترنت في أي وقت.';

  @override
  String get logInCapital => 'تسجيل الدخول';

  @override
  String get upcomingAppointments => 'القادمة';

  @override
  String get pastAppointments => 'السابقة';

  @override
  String get noUpcomingAppointments => 'لا توجد مواعيد قادمة';

  @override
  String get noPastAppointments => 'لا توجد مواعيد سابقة';

  @override
  String get noAppointmentsDescription => 'تحكم في صحتك. احجز موعدك القادم بسهولة.';

  @override
  String bookedOn(Object date) {
    return 'تم الحجز في: $date';
  }

  @override
  String appointmentReason(Object reason) {
    return 'السبب: $reason';
  }

  @override
  String patientName(Object name) {
    return 'المريض: $name';
  }

  @override
  String get bookAgain => 'احجز مرة أخرى';

  @override
  String get waitingConfirmation => 'بانتظار تأكيد الموعد';

  @override
  String get loadMoreAppointments => 'تحميل المزيد..';

  @override
  String get unknownDate => 'التاريخ غير معروف';

  @override
  String get unknownTime => 'الوقت غير معروف';

  @override
  String get unknown => 'غير معروف';

  @override
  String get somethingWentWrong => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get cancelReasonQuestion => 'لماذا تريد إلغاء هذا الموعد؟';

  @override
  String get typeReasonHere => 'اكتب السبب هنا...';

  @override
  String get reasonRequired => 'يجب إدخال سبب للإلغاء.';

  @override
  String get tooLateToCancel => 'لقد فات الأوان لإلغاء هذا الموعد الآن.';

  @override
  String get notAllowed => 'غير مسموح';

  @override
  String get cancelTimeLimitNote => 'احتراماً لوقت الطبيب والمرضى الآخرين، يجب إلغاء الموعد قبل ٢٤ ساعة على الأقل من الوقت المحدد. لا يُسمح بالإلغاء المتأخر.';

  @override
  String get appointmentCancelledMessage => 'تم إلغاء الموعد بنجاح. يمكنك حجز موعد جديد في أي وقت.';

  @override
  String get toAppointmentPage => 'العودة إلى صفحة المواعيد';

  @override
  String get tooLateToReschedule => 'تجاوزت المهلة لإعادة جدولة هذا الموعد.';

  @override
  String get rescheduleTimeLimitNote => 'احتراماً لوقت الطبيب والمرضى الآخرين، يجب إعادة جدولة الموعد قبل ٢٤ ساعة على الأقل من الوقت المحدد. لا يُسمح بإعادة الجدولة المتأخرة.';

  @override
  String get appointmentRescheduleNoWarning => 'يمكنك الآن متابعة إعادة الجدولة.';

  @override
  String get noAvailableAppointmentsRes => 'لا توجد مواعيد أخرى متاحة لإعادة الجدولة.';

  @override
  String get cancelInsteadNote => 'يمكنك إلغاء هذا الموعد بدلاً من ذلك إذا لزم الأمر.';

  @override
  String get rescheduleReasonQuestion => 'لماذا تريد إعادة جدولة هذا الموعد؟';

  @override
  String get confirmReschedule => 'تأكيد إعادة الجدولة';

  @override
  String get currentAppointment => 'الموعد الحالي';

  @override
  String get newAppointment => 'الموعد الجديد';

  @override
  String get manageDocuments => 'إدارة مستنداتك';

  @override
  String get manageDocumentsDescription => 'يمكنك الوصول إلى مستنداتك بسهولة ومشاركتها مع الأطباء في أي وقت.';

  @override
  String get notes => 'الملاحظات';

  @override
  String get takeNotesTitle => 'دوِّن ملاحظات\n مهمة حول صحتك';

  @override
  String get takeNotesDescription => 'مثلاً، تتبع الأعراض، سجل ملاحظات حول صحتك النفسية، وحضر أسئلة لمناقشتها مع طبيبك.';

  @override
  String get addDocument => 'إضافة مستند';

  @override
  String get uploadingDocument => 'جاري رفع المستند...';

  @override
  String get documentTooLarge => 'الملف بعد الضغط أكبر من 2 ميغابايت، الرجاء تقليل عدد الصور أو استخدام صور أصغر.';

  @override
  String get pdfTooLarge => 'ملف PDF كبير جداً، الرجاء استخدام ملف أصغر من 2MB';

  @override
  String get chooseAddDocumentMethod => 'اختر طريقة إضافة المستند';

  @override
  String get createNote => 'إنشاء ملاحظة';

  @override
  String get sendRequests => 'إرسال الطلبات';

  @override
  String get sendRequestsDescription => 'يمكنك إرسال طلبات محددة إلى الأطباء للاستفسار عن الوصفات الطبية، نتائج الفحوصات، خطابات الإحالة، والمزيد.';

  @override
  String get sendMessage => 'إرسال رسالة';

  @override
  String get easilySendMessages => 'أرسل الرسائل بسهولة إلى الأطباء';

  @override
  String get sendMessagesDescription => 'ابدأ محادثة مع طبيبك. استفسر عن نتائج الفحوصات، اطلب خطابات الإحالة، والمزيد.';

  @override
  String get fileTooLarge => 'إجمالي حجم الصور كبير جداً (الحد الأقصى 4 ميغابايت). يرجى تقليل عدد الصور أو تصغير حجمها.';

  @override
  String get chooseAttachmentType => 'إرسال مرفق';

  @override
  String get welcomeDocsera => 'مرحباً بك في دوكسيرا!';

  @override
  String get welcome_subtitle => 'قم بإدارة مواعيدك وابقَ على تواصل.';

  @override
  String get login_button => 'تسجيل الدخول';

  @override
  String get signup_button => 'إنشاء حساب جديد';

  @override
  String get benefit_appointments => 'حجز المواعيد بسهولة';

  @override
  String get benefit_reminders => 'تلقي التذكيرات تلقائيًا';

  @override
  String get benefit_history => 'متابعة تاريخ مواعيدك';

  @override
  String get benefit_chat => 'التواصل مع الأطباء مباشرة';

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get noName => 'لا يوجد اسم';

  @override
  String get birthDateNotProvided => 'تاريخ الميلاد غير متوفر';

  @override
  String get addressNotProvided => 'العنوان غير مُدخل';

  @override
  String get didYouKnow => 'هل كنت تعلم؟';

  @override
  String get didYouKnowDesc => 'يمكنك أيضًا حجز المواعيد لأقربائك من خلال إنشاء ملفات شخصية مخصصة لهم.';

  @override
  String get manageMyRelatives => 'إدارة الأقارب';

  @override
  String get relativeAddedSuccess => 'تمت إضافة القريب بنجاح!';

  @override
  String relativeAddFailed(Object error) {
    return 'فشل في إضافة القريب: $error';
  }

  @override
  String get arabicOnlyError => 'الرجاء إدخال النص باللغة العربية فقط';

  @override
  String get numbersOnlyError => 'يرجى إدخال أرقام فقط';

  @override
  String get max3DigitsError => 'الرقم يجب ألا يتجاوز 3 خانات';

  @override
  String get editMyProfile => 'تعديل الملف الشخصي';

  @override
  String get gender => 'الجنس';

  @override
  String get selectGender => 'اختر الجنس';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get dateOfBirth => 'تاريخ الميلاد';

  @override
  String get dateFormatHint => 'الصيغة: يوم.شهر.سنة';

  @override
  String get address => 'العنوان';

  @override
  String get street => 'الشارع';

  @override
  String get buildingNr => 'رقم البناء';

  @override
  String get city => 'المدينة';

  @override
  String get selectCity => 'اختر المدينة';

  @override
  String get country => 'الدولة';

  @override
  String get selectCountry => 'اختر الدولة';

  @override
  String get save => 'حفظ';

  @override
  String get genderRequired => 'الجنس مطلوب';

  @override
  String get firstNameRequired => 'الاسم الأول مطلوب';

  @override
  String get lastNameRequired => 'اسم العائلة مطلوب';

  @override
  String get dobRequired => 'تاريخ الميلاد مطلوب';

  @override
  String get buildingNrError => 'يرجى ملء الشارع والمدينة والدولة قبل إدخال رقم البناء.';

  @override
  String get updateSuccess => 'تم تحديث الملف الشخصي بنجاح!';

  @override
  String updateFailed(Object error) {
    return 'فشل في تحديث الملف الشخصي: $error';
  }

  @override
  String get infoText => 'سيتم مشاركة التغييرات في ملفك مع الممارسين الطبيين.';

  @override
  String get requiredField => '  هذا الحقل إجباري';

  @override
  String get minTwoLettersError => 'الرجاء إدخال حرفين على الأقل';

  @override
  String get fillFullAddress => 'برجاء ملء الشارع، المدينة، والدولة قبل إضافة رقم المبنى.';

  @override
  String get enterPhoneOptional => 'أدخل رقم الهاتف (اختياري)';

  @override
  String get enterEmailOptional => 'أدخل البريد الإلكتروني (اختياري)';

  @override
  String get enterStreet => 'أدخل اسم الشارع';

  @override
  String get enterBuildingOptional => 'أدخل رقم البناء (اختياري)';

  @override
  String get authorizationStatement => 'أُقر بأنني الممثل القانوني لقريبي، أو أنني مخوّل باستخدام خدمات Docsera لإدارة بياناته الطبية نيابة عنه.';

  @override
  String get add => 'إضافة';

  @override
  String get syria => 'سوريا';

  @override
  String get damascus => 'دمشق';

  @override
  String get reefDamascus => 'ريف دمشق';

  @override
  String get aleppo => 'حلب';

  @override
  String get homs => 'حمص';

  @override
  String get hama => 'حماة';

  @override
  String get latakia => 'اللاذقية';

  @override
  String get deirEzzor => 'دير الزور';

  @override
  String get raqqa => 'الرقة';

  @override
  String get idlib => 'إدلب';

  @override
  String get daraa => 'درعا';

  @override
  String get tartus => 'طرطوس';

  @override
  String get alHasakah => 'الحسكة';

  @override
  String get qamishli => 'القامشلي';

  @override
  String get suwayda => 'السويداء';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get myProfile => 'ملفي الشخصي';

  @override
  String get myRelatives => 'أقاربي';

  @override
  String get myRelativesDescription => 'إضافة أو إدارة الأقارب';

  @override
  String get editRelative => 'تعديل معلومات القريب';

  @override
  String get noRelativesTitle => 'اهتم بأقاربك على دوكسيرا';

  @override
  String get noRelativesDesc => 'أضف أقاربك إلى حسابك لإدارة مواعيدهم ووثائقهم الصحية بكل سهولة.';

  @override
  String bornOn(Object date) {
    return 'تاريخ الميلاد: $date';
  }

  @override
  String get bornOnLabel => 'تاريخ الميلاد';

  @override
  String yearsCount(Object count) {
    return '$count سنة';
  }

  @override
  String get manageAccessRights => 'إدارة صلاحيات الوصول';

  @override
  String accessRightsFor(Object name) {
    return 'صلاحيات الوصول لـ $name';
  }

  @override
  String get thisPersonCan => 'هذا الشخص يمكنه:';

  @override
  String get bookRescheduleCancel => 'حجز، إعادة جدولة وإلغاء';

  @override
  String get allAppointments => 'جميع المواعيد';

  @override
  String get addAndManage => 'إضافة وإدارة';

  @override
  String get allDocuments => 'جميع المستندات';

  @override
  String get updateIdentity => 'تحديث الهوية و';

  @override
  String get contactInfo => 'معلومات التواصل';

  @override
  String get removeThisRelative => 'إزالة هذا القريب';

  @override
  String removeRelativeTitle(Object name) {
    return 'إزالة $name؟';
  }

  @override
  String get removeRelativeDesc => 'عند إزالة هذا القريب من حسابك، لن تتمكن من الوصول إلى مستنداته أو سجل مواعيده بعد الآن.';

  @override
  String get remove => 'إزالة';

  @override
  String relativeRemoved(Object name) {
    return 'تمت إزالة $name من قائمة الأقارب.';
  }

  @override
  String relativeRemoveFailed(Object error, Object name) {
    return 'فشل في إزالة $name: $error';
  }

  @override
  String get you => 'أنت';

  @override
  String get accountHolder => 'صاحب الحساب';

  @override
  String get invalidPhoneNumber => 'رقم الهاتف غير صحيح.\nيجب إما أن يبدأ بـ 9 ويتكوّن من 9 أرقام، أو يبدأ بـ 09 ويتكوّن من 10 أرقام.';

  @override
  String get addEmailTitle => 'إضافة بريد إلكتروني';

  @override
  String get samePhone => 'رقم الهاتف هذا مستخدم حالياً.';

  @override
  String get sameEmail => 'البريد الإلكتروني هذا مستخدم حالياً.';

  @override
  String get invalidEmail => 'البريد الإلكتروني غير صالح';

  @override
  String get loginSection => 'تسجيل الدخول';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordHidden => '••••••••••••••••';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get languageDescription => 'إعدادات لغة الحساب';

  @override
  String get twoFactorAuth => 'المصادقة الثنائية';

  @override
  String get twoFactorAuthActivated => 'مفعلة';

  @override
  String get encryptedDocuments => 'المستندات المشفرة';

  @override
  String get encryptedDocumentsDescription => 'تأمين ملفاتك الطبية';

  @override
  String get faceIdTitle => 'افتح باستخدام Face ID';

  @override
  String get faceIdDescription => 'استخدم Face ID لتسجيل الدخول بسرعة وأمان.';

  @override
  String get fingerprintTitle => 'افتح باستخدام البصمة';

  @override
  String get fingerprintDescription => 'استخدم بصمتك لتسجيل الدخول بسرعة وأمان.';

  @override
  String get faceIdPrompt => 'المصادقة باستخدام Face ID';

  @override
  String get fingerprintPrompt => 'المصادقة باستخدام البصمة';

  @override
  String get faceIdFailed => 'فشل التحقق من Face ID';

  @override
  String get fingerprintFailed => 'فشل التحقق من البصمة';

  @override
  String get biometricTitle => 'المصادقة البيومترية';

  @override
  String get confidentiality => 'الخصوصية';

  @override
  String get myPreferences => 'تفضيلاتي';

  @override
  String get legalInformation => 'المعلومات القانونية';

  @override
  String get deleteMyAccount => 'حذف حسابي';

  @override
  String get editPhoneNumber => 'تعديل رقم الهاتف';

  @override
  String get editEmail => 'تعديل البريد الإلكتروني';

  @override
  String get newPhoneNumber => 'رقم الهاتف الجديد';

  @override
  String get newEmailAddress => 'عنوان البريد الإلكتروني الجديد';

  @override
  String get verify => 'تحقق';

  @override
  String pleaseConfirm(Object fieldType) {
    return 'يرجى تأكيد $fieldType';
  }

  @override
  String get sixDigitCode => 'رمز التحقق المكون من 6 أرقام';

  @override
  String sentVerificationMessage(Object destination, Object messageType) {
    return 'لقد أرسلنا لك $destination إلى $messageType.';
  }

  @override
  String get sms => 'SMS';

  @override
  String get resendCode => 'لم تستلم الرمز؟ اضغط لإعادة الإرسال.';

  @override
  String resendIn(Object seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String get phoneUpdatedWithoutVerification => 'تم تحديث الهاتف دون التحقق';

  @override
  String get phoneUpdatedSuccess => 'تم التحقق من رقم الهاتف وتحديثه!';

  @override
  String get emailUpdatedSuccess => 'تم التحقق من البريد الإلكتروني وتحديثه!';

  @override
  String get continueButton => 'متابعة';

  @override
  String get verifyLater => 'تحقق لاحقاً';

  @override
  String get alreadyExistsPhone => 'يوجد حساب دوكسيرا مسجل بهذا الرقم بالفعل';

  @override
  String get alreadyExistsEmail => 'يوجد حساب دوكسيرا مسجل بهذا البريد الإلكتروني بالفعل';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get incorrectCurrentPassword => 'كلمة المرور الحالية غير صحيحة';

  @override
  String get passwordMatchError => 'لا يمكن أن تكون كلمة المرور الجديدة مطابقة للحالية';

  @override
  String get passwordUpdatedSuccess => 'تم تحديث كلمة المرور بنجاح!';

  @override
  String passwordUpdatedFailed(Object error) {
    return 'فشل في تحديث كلمة المرور: $error';
  }

  @override
  String get guest => 'ضيف';

  @override
  String get notProvided => 'غير متوفر';

  @override
  String get verified => 'تم التحقق';

  @override
  String get notVerified => 'لم يتم التحقق';

  @override
  String get addressNotEntered => 'لم يتم إدخال العنوان';

  @override
  String get personalizedServices => 'الخدمات المخصصة';

  @override
  String get serviceImprovements => 'تحسينات الخدمة';

  @override
  String get map => 'الخريطة';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get cookieManagement => 'إدارة ال Cookies ';

  @override
  String get termsAndConditionsOfUse => 'الشروط والأحكام';

  @override
  String get termsOfUseAgreement => 'اتفاقية شروط الاستخدام';

  @override
  String get personalDataProtectionPolicy => 'سياسة حماية البيانات الشخصية';

  @override
  String get cookiePolicy => 'سياسة ملفات تعريف الارتباط';

  @override
  String get legalNotice => 'إشعار قانوني';

  @override
  String get reportIllicitContent => 'الإبلاغ عن محتوى غير قانوني';

  @override
  String get deleteAccountWarningText => 'يمكنك حذف حسابك وبياناتك المرتبطة في أي وقت. لن يؤدي ذلك إلى حذف بياناتك تلقائيًا من قواعد بيانات الأطباء الذين حجزت معهم مواعيد. قد يكون لدى الأطباء مصلحة مشروعة في الاحتفاظ ببياناتك الشخصية. يمكنك ممارسة حقوقك في الوصول أو التصحيح أو الحذف من خلال التواصل معهم مباشرة.';

  @override
  String get confirmDeleteMyAccount => 'حذف حسابي';

  @override
  String get goodbyeMessage => 'نأسف لرؤيتك ترحل 😔';

  @override
  String get goodbyeSubtext => 'تم حذف حسابك بنجاح. نأمل أن نراك مجددًا في المستقبل.';

  @override
  String get searchTitle => 'بحث';

  @override
  String get searchHint => 'الاسم، التخصص، العيادة';

  @override
  String get favoritesTitle => 'المفضلة';

  @override
  String get noFavorites => 'لا يوجد أطباء مفضلون';

  @override
  String get noResultsTitle => 'لم يتم العثور على نتائج';

  @override
  String get noResultsSubtitle => 'حاول استخدام مصطلح بحث مختلف.';

  @override
  String get searchBySpecialty => 'البحث حسب التخصص';

  @override
  String get nearbyMe => 'بالقرب مني';

  @override
  String get cities => 'المدن';

  @override
  String get selectCityPlaceholder => 'اختر مدينة';

  @override
  String get locationPermissionDenied => 'تم رفض إذن الوصول إلى الموقع. يرجى تفعيله من الإعدادات.';

  @override
  String get locationError => 'تعذر الوصول إلى موقعك. يرجى تفعيل خدمات الموقع.';

  @override
  String get showResults => 'عرض النتائج';

  @override
  String get specialtyGeneral => 'طب عام';

  @override
  String get specialtyInternal => 'طب باطني';

  @override
  String get specialtyPediatrics => 'طب أطفال';

  @override
  String get specialtyGynecology => 'نسائية';

  @override
  String get specialtyDentistry => 'طب أسنان';

  @override
  String get specialtyCardiology => 'قلبية';

  @override
  String get specialtyENT => 'أنف وأذن وحنجرة';

  @override
  String get specialtyOphthalmology => 'طب عيون';

  @override
  String get specialtyOrthopedics => 'عظمية';

  @override
  String get specialtyDermatology => 'جلدية';

  @override
  String get specialtyPsychology => 'طب نفسي';

  @override
  String get specialtyNeurology => 'عصبية';

  @override
  String get specialtyNutrition => 'تغذية';

  @override
  String get specialtyEndocrinology => 'غدد وسكري';

  @override
  String get specialtyUrology => 'بولية';

  @override
  String get specialtyGeneralSurgery => 'جراحة عامة';

  @override
  String get specialtyGastro => 'هضمية';

  @override
  String get specialtyPlastic => 'تجميل';

  @override
  String get specialtyCancer => 'أورام';

  @override
  String get specialtyEmergency => 'طوارئ';

  @override
  String get specialtyPhysio => 'علاج فيزيائي';

  @override
  String get showOnMap => 'عرض على الخريطة';

  @override
  String get searchHere => 'ابحث هنا';

  @override
  String get bookingNotAvailable => 'الحجز غير متاح';

  @override
  String get bothGenders => 'كلا الجنسين';

  @override
  String get noFilters => 'لا توجد فلاتر مفعّلة';

  @override
  String get filters => 'الفلاتر';

  @override
  String get done => 'تم';

  @override
  String get moreFiltersSoon => 'المزيد من الفلاتر قريباً';

  @override
  String get maxDistance => 'أقصى مسافة';

  @override
  String get specialty => 'التخصص';

  @override
  String get reset => 'إعادة تعيين';

  @override
  String get more => 'أُخرى';

  @override
  String get openInMapsApp => 'افتح في تطبيق الخرائط';

  @override
  String get gallery => 'صور العيادة والطبيب';

  @override
  String get location => 'الموقع';

  @override
  String get openInMaps => 'افتح في الخرائط';

  @override
  String get additionalInformation => 'معلومات إضافية';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get specialtiesProcedures => 'التخصصات، الإجراءات والعلاجات';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get openWebsite => 'افتح الموقع';

  @override
  String get contactInformation => 'معلومات الاتصال';

  @override
  String get viewMore => 'عرض المزيد';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get openingHours => 'ساعات العمل';

  @override
  String get languagesSpoken => 'اللغات المتحدث بها';

  @override
  String get today => 'اليوم';

  @override
  String get closed => 'مغلق';

  @override
  String get clinicNotAvailable => 'العيادة غير متوفرة';

  @override
  String get faq => 'الأسئلة الشائعة';

  @override
  String get offeredServices => 'الخدمات المقدمة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageFrench => 'الفرنسية';

  @override
  String get languageGerman => 'الألمانية';

  @override
  String get languageSpanish => 'الإسبانية';

  @override
  String get languageTurkish => 'التركية';

  @override
  String get languageRussian => 'الروسية';

  @override
  String get languageKurdish => 'الكردية';

  @override
  String get pleaseLoginToContinue => 'يرجى تسجيل الدخول لإتمام الحجز';

  @override
  String get noAccountQuestion => 'ليس لديك حساب؟';

  @override
  String get makeAppointment => 'حجز موعد';

  @override
  String get whoIsThisFor => 'لمن هذا الموعد؟';

  @override
  String get addRelative => 'إضافة قريب';

  @override
  String get me => '(أنا)';

  @override
  String get yearsOld => ' عام';

  @override
  String get haveYouVisitedBefore => 'هل زرت هذا الطبيب من قبل؟';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get selectReasonTitle => 'سبب الزيارة';

  @override
  String get selectReason => 'اختر سبب الزيارة';

  @override
  String get initialExamination => 'فحص أولي للمريض الجديد';

  @override
  String get checkupFollowup => 'مراجعة / متابعة';

  @override
  String get acuteSymptoms => 'أعراض حادة / حالة طارئة';

  @override
  String get availableAppointments => 'المواعيد المتاحة';

  @override
  String get noAvailableAppointments => 'لا توجد مواعيد متاحة';

  @override
  String get showMore => 'عرض المزيد';

  @override
  String get confirmAppointment => 'تأكيد الحجز';

  @override
  String get doctorInfo => 'معلومات الطبيب';

  @override
  String get clinicAddress => 'عنوان العيادة';

  @override
  String get patientInfo => 'معلومات المريض';

  @override
  String get appointmentTime => 'وقت الموعد';

  @override
  String get confirm => 'تأكيد';

  @override
  String get slotReservedFor => 'هذا الموعد محجوز لمدة 15 دقيقة';

  @override
  String get byConfirming => 'بتأكيدك لهذا الموعد، ';

  @override
  String get agreeToHonor => 'أنت توافق على الالتزام به.';

  @override
  String get for2 => 'لـ ';

  @override
  String get date => 'التاريخ';

  @override
  String get reason => 'السبب';

  @override
  String get appointmentConfirmed => 'تم تأكيد الموعد';

  @override
  String get appointmentConfirmedMessage => 'تم إرسال تأكيد الحجز إلى بريدك الإلكتروني';

  @override
  String get addToCalendar => 'إضافة إلى التقويم';

  @override
  String get sendDocuments => 'إرسال المستندات';

  @override
  String get sendDocumentsSubtitle => 'إرسل المستندات إلى طبيبك قبل الموعد';

  @override
  String get viewMoreDetails => 'عرض تفاصيل الموعد';

  @override
  String appointmentWith(Object doctorName) {
    return 'موعد مع';
  }

  @override
  String get reasonForAppointment => 'سبب الموعد';

  @override
  String get notSpecified => 'غير محدد';

  @override
  String get appointmentAddedToCalendar => '📅 تم إضافة الموعد إلى التقويم!';

  @override
  String get appointmentFailedToAdd => '⚠️ فشل إضافة الموعد إلى التقويم.';

  @override
  String get errorLoadingAppointments => 'حدث خطأ أثناء تحميل المواعيد.';

  @override
  String get awaitingDoctorConfirmation => 'بانتظار تأكيد الطبيب';

  @override
  String get waitingForDoctorToApprove => 'تم إرسال طلبك بنجاح، وسيقوم الطبيب بمراجعة الموعد والموافقة عليه.';

  @override
  String get backToHome => 'العودة إلى الرئيسية';

  @override
  String get appointmentDetails => 'تفاصيل الموعد';

  @override
  String get reschedule => 'إعادة جدولة';

  @override
  String get cancelAppointment => 'إلغاء الموعد';

  @override
  String get patient => 'المريض';

  @override
  String get shareAppointmentDetails => 'مشاركة تفاصيل الموعد';

  @override
  String get clinicDetails => 'تفاصيل العيادة أو المركز الطبي';

  @override
  String get openMap => 'فتح الخريطة';

  @override
  String backToDoctorProfile(Object doctorName) {
    return 'العودة إلى ملف $doctorName الشخصي';
  }

  @override
  String appointmentWithLabel(Object doctorName) {
    return 'موعد مع $doctorName';
  }

  @override
  String appointmentReason2(Object reason) {
    return 'السبب: $reason';
  }

  @override
  String appointmentLocation(Object clinicName) {
    return 'الموقع: $clinicName';
  }

  @override
  String appointmentDate(Object date) {
    return 'التاريخ: $date';
  }

  @override
  String appointmentTime2(Object time) {
    return 'الوقت: $time';
  }

  @override
  String get sharedFromApp => 'تمت المشاركة من تطبيق DocSera';

  @override
  String get youAreAboutToReschedule => 'أنت على وشك إعادة جدولة موعدك في اللحظة الأخيرة';

  @override
  String get youAreAboutToCancel => 'أنت على وشك إلغاء موعدك في اللحظة الأخيرة';

  @override
  String get lastMinuteWarning => 'هذا الموعد خلال أقل من 48 ساعة. من غير المحتمل أن يتم حجزه من قبل مريض آخر.';

  @override
  String get respectPractitionerReschedule => 'احترامًا لطبيبك، يجب عليك إعادة الجدولة فقط إذا كان ذلك ضروريًا للغاية.';

  @override
  String get respectPractitionerCancel => 'احترامًا لطبيبك، يجب عليك الإلغاء فقط إذا كان ذلك ضروريًا للغاية.';

  @override
  String get continuing => 'المتابعة';

  @override
  String get keepAppointment => 'الاحتفاظ بالموعد';

  @override
  String get cancelAppointmentAction => 'إلغاء الموعد';

  @override
  String get appointmentRescheduled => 'تم تأكيد إعادة الجدولة';

  @override
  String get appointmentCancelled => 'تم إلغاء الموعد';

  @override
  String get appointmentCancelNoWarning => 'تم إلغاء الموعد دون تحذير';

  @override
  String get doctorIdMissingError => 'رقم تعريف الطبيب غير موجود. لا يمكن فتح الملف الشخصي.';

  @override
  String get rescheduleWarningTitle => 'أنت على وشك تأجيل موعدك في اللحظة الأخيرة';

  @override
  String get cancelWarningTitle => 'أنت على وشك إلغاء موعدك في اللحظة الأخيرة';

  @override
  String get appointmentShortNoticeWarning => 'هذا الموعد بعد أقل من 48 ساعة. من غير المحتمل أن يتم حجزه من قبل مريض آخر.';

  @override
  String get rescheduleRespectNotice => 'من باب الاحترام لمقدم الرعاية الصحية الخاص بك، يجب تأجيل الموعد فقط عند الضرورة القصوى';

  @override
  String get cancelRespectNotice => 'من باب الاحترام لمقدم الرعاية الصحية الخاص بك، يجب إلغاء الموعد فقط عند الضرورة القصوى';

  @override
  String get sendDocument => 'إرسال المستند';

  @override
  String get sendDocumentsLater => 'سيتم تفعيل ميزة إرسال المستندات لاحقًا عند الانتهاء من تطوير تطبيق الأطباء';

  @override
  String get sendDocumentsTo => 'أرسل المستندات إلى';

  @override
  String get beforeConsultation => 'قبل الاستشارة';

  @override
  String get exampleDocuments => 'مثل الإحالة، نتائج التحاليل، الوصفات الطبية';

  @override
  String get sizeLimit => 'الحجم';

  @override
  String get acceptedFormat => 'الصيغ المقبولة';

  @override
  String get identificationTitle => 'الحساب';

  @override
  String get registerOrLogin => 'سجّل أو قم بتسجيل الدخول';

  @override
  String get newToApp => 'جديد في دوكسيرا؟';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get emailOrPhone => 'البريد الإلكتروني أو رقم الهاتف';

  @override
  String get incorrectPassword => 'البريد الإلكتروني/الهاتف أو كلمة المرور غير صحيحة';

  @override
  String get userNotFound => 'المستخدم غير موجود';

  @override
  String loginError(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get faceIdNoCredentials => 'لم يتم العثور على بيانات محفوظة لتسجيل الدخول باستخدام Face ID.';

  @override
  String get logInWithFaceId => 'تسجيل الدخول باستخدام Face ID';

  @override
  String get logInWithFingerprint => 'تسجيل الدخول باستخدام Fingerprint';

  @override
  String get enterManually => 'أدخل يدويًا';

  @override
  String get useBiometricLogin => 'استخدم بصمة الوجه أو الإصبع لتسجيل الدخول';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get biometricPrompt => 'يرجى التحقق باستخدام بصمة الوجه أو الإصبع';

  @override
  String get logInFailed => 'فشل تسجيل الدخول. تحقق من البيانات وحاول مجددًا.';

  @override
  String get authenticating => 'جارٍ التحقق...';

  @override
  String get createAnAccount => 'إنشاء حساب';

  @override
  String get continueAsGuest => 'المتابعة كزائر';

  @override
  String get enterPhone => 'الرجاء إدخال رقم هاتفك';

  @override
  String get enterEmail => 'الرجاء إدخال بريدك الإلكتروني';

  @override
  String get errorCheckingEmail => 'حدث خطأ أثناء التحقق من البريد الإلكتروني. يرجى المحاولة مرة أخرى.';

  @override
  String get emailAlreadyRegistered => 'البريد الإلكتروني مسجل';

  @override
  String get emailAlreadyRegisteredContent => 'البريد الإلكتروني الذي أدخلته مسجل مسبقاً في دوكسيرا.';

  @override
  String get phoneAlreadyRegistered => 'رقم الهاتف مسجل';

  @override
  String get phoneAlreadyRegisteredContent => 'رقم الهاتف الذي أدخلته مسجل مسبقاً في دوكسيرا.';

  @override
  String get loginWithEmail => 'تسجيل الدخول بالبريد الإلكتروني';

  @override
  String get loginWithPhone => 'تسجيل الدخول برقم الهاتف';

  @override
  String get edit => 'تعديل';

  @override
  String get enterPersonalInfo => 'أدخل معلوماتك الشخصية';

  @override
  String get identity => 'الهويةالشخصية';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get enterDateOfBirth => 'أدخل تاريخ ميلادك';

  @override
  String get dobHint => 'يوم.شهر.سنة';

  @override
  String get createPassword => 'إنشاء كلمة المرور';

  @override
  String get weakPassword => 'قوة كلمة المرور: ضعيفة';

  @override
  String get fairPassword => 'قوة كلمة المرور: متوسطة';

  @override
  String get goodPassword => 'قوة كلمة المرور: جيدة';

  @override
  String get strongPassword => 'قوة كلمة المرور: قوية';

  @override
  String get useEightCharacters => 'استخدم 8 أحرف أو أكثر لكلمة المرور.';

  @override
  String get passwordTooSimple => 'كلمة المرور سهلة جدًا. حاول إضافة رموز خاصة، أرقام، وأحرف كبيرة.';

  @override
  String get passwordRepeatedCharacters => 'تجنب الأحرف المتكررة مثل \'aaa\' أو \'111\'.';

  @override
  String get termsOfUseTitle => 'شروط الاستخدام وسياسة الخصوصية';

  @override
  String get termsOfUseDescription => 'لإنشاء حساب في دوكسيرا، يرجى قبول شروط الاستخدام.';

  @override
  String get acceptTerms => 'لقد قرأت ووافقت على شروط الاستخدام';

  @override
  String get dataProcessingInfo => 'يمكنك العثور على مزيد من المعلومات حول معالجة البيانات في ';

  @override
  String get dataProtectionNotice => 'إشعارات حماية البيانات.';

  @override
  String get marketingPreferencesTitle => 'ابقَ على اطلاع بآخر التحديثات';

  @override
  String get marketingPreferencesSubtitle => 'احصل على رسائل بريد إلكتروني وإشعارات مخصصة حول النصائح الصحية وخدماتنا.';

  @override
  String get marketingCheckboxText => 'نصائح مفيدة لإدارة صحتي ومعلومات تسويقية حول خدماتنا';

  @override
  String get privacyPolicyInfo => 'يمكنك تغيير اختيارك في أي وقت من خلال الإعدادات. لمعرفة المزيد،';

  @override
  String get privacyPolicyLink => 'راجع سياسة الخصوصية.';

  @override
  String get enterSmsCode => 'أدخل الرمز الذي تم إرساله إليك عبر الرسائل القصيرة';

  @override
  String get enterEmailCode => 'أدخل الرمز الذي تم إرساله إليك عبر البريد الإلكتروني';

  @override
  String get otpLabel => 'رمز التحقق المكون من 6 أرقام';

  @override
  String get otpSentTo => 'تم إرسال هذا الرمز المؤقت إلى:';

  @override
  String get didntReceiveCode => 'لم تستلم الرمز؟';

  @override
  String get invalidCode => 'رمز غير صحيح. يرجى المحاولة مرة أخرى.';

  @override
  String get otpSendFailed => 'فشل في إرسال رمز التحقق. يرجى المحاولة مرة أخرى.';

  @override
  String get tryAgain => 'أعد المحاولة';

  @override
  String get seconds => 'ثوانٍ';

  @override
  String get reviewDetails => 'يرجى مراجعة التفاصيل الخاصة بك:';

  @override
  String get name => 'الاسم';

  @override
  String get mustBeOver16 => 'يجب أن يكون عمرك 16 سنة على الأقل';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailVerified => 'تم التحقق من البريد الإلكتروني';

  @override
  String get skipEmail => 'إضافة البريد الإلكتروني لاحقًا';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get phoneVerified => 'تم التحقق من الهاتف';

  @override
  String get termsAccepted => 'تمت الموافقة على الشروط';

  @override
  String get marketingPreferences => 'تفضيلات التسويق';

  @override
  String get register => 'تسجيل';

  @override
  String get registrationSuccess => 'تم إنشاء الحساب بنجاح!';

  @override
  String get registrationFailed => 'فشل تسجيل المستخدم';

  @override
  String get autoLoginFailed => 'فشل تسجيل الدخول التلقائي.';

  @override
  String get emailAlreadyRegisteredAlt => 'هذا البريد الإلكتروني مسجل بالفعل!';

  @override
  String get phoneAlreadyRegisteredAlt => 'رقم الهاتف هذا مسجل بالفعل!';

  @override
  String get welcomeToDocsera => 'مرحباً بك في دوكسيرا،';

  @override
  String get welcomeMessageInfo => 'احجز مواعيدك بسهولة، تابع ملفاتك الطبية، وتواصل مع الأطباء من مكان واحد وبكل أمان وسرعة.';

  @override
  String get goToHomepage => 'الانتقال إلى الصفحة الرئيسية';

  @override
  String get serverConnectionError => 'لا يمكن الاتصال بالخادم. تحقق من اتصال الإنترنت وحاول مجددًا.';

  @override
  String verificationError(Object errorMessage) {
    return 'حدث خطأ أثناء التحقق من الرقم: $errorMessage';
  }

  @override
  String get unexpectedError => 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى لاحقًا.';

  @override
  String get documentAddedSuccessfully => 'تمت إضافة المستند بنجاح!';

  @override
  String get documentAddFailed => 'فشل في إضافة المستند.';

  @override
  String get switchToListView => 'عرض كقائمة';

  @override
  String get switchToGridView => 'عرض كشبكة';

  @override
  String get addNewDocument => 'إضافة مستند جديد';

  @override
  String get addPage => 'إضافة صفحة';

  @override
  String get deletePage => 'حذف هذه الصفحة';

  @override
  String get continueText => 'متابعة';

  @override
  String get page => 'الصفحة';

  @override
  String get nameOfTheDocument => 'اسم المستند';

  @override
  String get optional => 'اختياري';

  @override
  String get typeOfTheDocument => 'نوع المستند';

  @override
  String get selectDocumentType => 'اختر نوع المستند';

  @override
  String get patientConcerned => 'المريض المعني';

  @override
  String get selectRelevantPatient => 'اختر المريض المعني';

  @override
  String get documentWillBeEncrypted => 'سيتم تشفير هذا المستند';

  @override
  String get results => 'عدد النتائج';

  @override
  String get medicalImaging => 'تصوير شعاعي';

  @override
  String get report => 'تقرير';

  @override
  String get referralLetter => 'إحالة طبية';

  @override
  String get treatmentPlan => 'خطة علاج';

  @override
  String get identityProof => 'إثبات هوية';

  @override
  String get insuranceProof => 'إثبات تأمين صحي';

  @override
  String get other => 'أخرى';

  @override
  String get sendToDoctor => 'إرسال للطبيب';

  @override
  String get rename => 'إعادة التسمية';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get download => 'تحميل';

  @override
  String get delete => 'حذف';

  @override
  String createdByYou(Object date) {
    return 'أنشأته أنت في $date';
  }

  @override
  String pagesCount(Object count) {
    return '$count صفحة';
  }

  @override
  String get pageSingular => 'صفحة';

  @override
  String get pagePlural => 'صفحات';

  @override
  String get deleteTheDocument => 'حذف المستند';

  @override
  String areYouSureToDelete(Object name) {
    return 'هل أنت متأكد أنك تريد حذف المستند \"$name\"؟\nإذا كنت قد شاركته مع طبيب، سيحتفظ بنسخته.';
  }

  @override
  String get documentUploadedSuccessfully => 'تم رفع المستند بنجاح';

  @override
  String get fileLoadFailed => '❌ فشل تحميل الملف';

  @override
  String get takePhoto => 'التقط صورة';

  @override
  String get chooseFromLibrary => 'اختر من المعرض';

  @override
  String get chooseFile => 'اختيار ملف';

  @override
  String get deleteDocument => 'حذف المستند';

  @override
  String get confirmDeleteDocument => 'هل أنت متأكد أنك تريد حذف هذا المستند؟';

  @override
  String get downloadSuccess => 'تم تحميل الملف بنجاح';

  @override
  String get permissionDenied => 'تم رفض إذن التخزين';

  @override
  String get uploadFailed => 'فشل في رفع المستند. حاول مرة أخرى.';

  @override
  String get documentDetails => 'تفاصيل المستند';

  @override
  String get createdAt => 'تاريخ الإنشاء';

  @override
  String get createdBy => 'تم الإنشاء بواسطة';

  @override
  String get encryptedDocument => 'مستند مشفّر';

  @override
  String get changeTheNameOfTheDocument => 'تغيير اسم الوثيقة';

  @override
  String get fillRequiredFields => 'يرجى ملء جميع الحقول المطلوبة';

  @override
  String get editNote => 'تعديل الملاحظة';

  @override
  String get noteTitle => 'عنوان الملاحظة';

  @override
  String get deleteTheNote => 'حذف الملاحظة';

  @override
  String get addNote => 'إضافة ملاحظة';

  @override
  String get discard => 'تجاهل';

  @override
  String get unsavedNoteTitle => 'تغييرات غير محفوظة';

  @override
  String get unsavedNoteMessage => 'هل ترغب في حفظ هذه الملاحظة قبل الخروج؟';

  @override
  String get noteContent => 'اكتب ملاحظتك هنا...';

  @override
  String get show => 'عرض';

  @override
  String lastUpdated(Object time) {
    return 'آخر تحديث الساعة $time';
  }

  @override
  String get sendMessageTitle => 'مراسلة طبيب';

  @override
  String get messagingDisabled => 'المراسلة غير متاحة';

  @override
  String get selectMessagePatient => 'لمن هذه الرسالة؟';

  @override
  String get selectMessageReason => 'ما سبب هذه الرسالة؟';

  @override
  String get noEmergencySupport => 'لا يمكن للطبيب معالجة الحالات الطارئة عبر الرسائل. في حال وجود حالة طبية طارئة، اتصل بالرقم 112.';

  @override
  String get reasonTestResults => 'طلب إرسال نتائج الفحوصات';

  @override
  String get reasonBill => 'فاتورة أو ملاحظة رسوم';

  @override
  String get reasonAppointment => 'حول موعد تم تحديده';

  @override
  String get reasonTreatmentUpdate => 'تحديثات على العلاج بعد الاستشارة';

  @override
  String get reasonOpeningHours => 'مواعيد وأيام الدوام';

  @override
  String get reasonContract => 'عقد العلاج';

  @override
  String get reasonOther => 'سبب آخر';

  @override
  String get whatDoYouNeed => 'ما الذي تحتاجه؟';

  @override
  String get help => 'مساعدة';

  @override
  String get attachDocuments => 'إرفاق مستندات';

  @override
  String get sendMyMessage => 'أرسل رسالتي';

  @override
  String get messageHint => 'اشرح سبب رسالتك. قدم أي معلومات ذات صلة للممارس.';

  @override
  String get helpTitle => 'ماذا يجب أن أضيف في طلبي؟';

  @override
  String get helpMessage1 => 'أدرج المعلومات الأساسية والمرتبطة والضرورية ليتمكن الطبيب من معالجة طلبك.';

  @override
  String get helpMessage2 => 'عند الحاجة (مثلًا لشهادة مرض)، قد يطلب منك الطبيب حجز موعد للفحص. وفي حال الطوارئ، اتصل برقم 112.';

  @override
  String get yesterday => 'أمس';

  @override
  String get conversationClosed => 'تم إغلاق المحادثة';

  @override
  String get forPatient => 'للمريض';

  @override
  String get messageForPatient => 'طلب المراسلة باسم:';

  @override
  String onBehalfOfPatient(Object patientName) {
    return 'نيابة عن $patientName';
  }

  @override
  String get onBehalfOf => 'نيابة عن';

  @override
  String conversationClosedByDoctor(Object doctorName) {
    return 'تم إغلاق هذه المحادثة من قبل $doctorName. لا يمكنك الرد بعد الآن.';
  }

  @override
  String get sendNewRequest => 'إرسال طلب جديد';

  @override
  String get writeYourMessage => 'اكتب رسالتك هنا...';

  @override
  String get waitingDoctorReply => 'يرجى انتظار رد الطبيب على طلبك.';

  @override
  String get read => 'تمت القراءة';

  @override
  String get chooseFromLibrary2 => 'اختيار صور';

  @override
  String get uploadPdf => 'رفع ملف PDF';

  @override
  String get attachedImage => 'صورة مرفقة';

  @override
  String get attachedImages => 'صور مرفقة';

  @override
  String get maxImagesReached => '8 صور حد أقصى.';

  @override
  String get remaining => 'باقي';

  @override
  String get addToDocuments => 'إضافة إلى المستندات';

  @override
  String get downloadAll => 'تحميل الكل';

  @override
  String get downloadCompleted => 'تم تحميل الصورة بنجاح';

  @override
  String get imagesDownloadedSuccessfully => 'تم تحميل الصور بنجاح';

  @override
  String get downloadFailed => 'فشل تحميل الصورة';

  @override
  String get imagesDownloadFailed => 'فشل تحميل الصور';

  @override
  String get ofText => 'من';

  @override
  String importedFromConversationWith(Object date, Object name) {
    return 'تم الاستيراد من المحادثة مع $name بتاريخ $date';
  }

  @override
  String get documentAccessInfo => 'فقط أنت تملك صلاحية الوصول إلى هذه المستندات وإدارتها.';

  @override
  String get notesAccessInfo => 'يمكنك أنت فقط الوصول إلى ملاحظاتك وإدارتها بأمان.';

  @override
  String get messageAccessInfo => 'يمكنك مراسلة طبيبك مباشرة من هنا. يتم حفظ جميع محادثاتك بأمان ويمكنك الوصول إليها بسهولة.';

  @override
  String get accountPrivacyInfoLine1 => 'بياناتك الشخصية تبقى خاصة.';

  @override
  String get accountPrivacyInfoLine2 => 'نحمي معلوماتك بأعلى معايير الأمان.';

  @override
  String get forgotPasswordButton => 'نسيت كلمة السر؟';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get activated => 'مفعّل';

  @override
  String get notActivated => 'غير مفعّل';

  @override
  String get encryptedDocumentsFullDescription => 'يتم تخزين مستنداتك الطبية بأمان باستخدام تشفير متقدم، مما يضمن أن تكون وحدك من يمكنه الوصول إليها وإدارتها.';

  @override
  String get twoFactorAuthHeadline => 'أمان إضافي يتجاوز كلمة المرور';

  @override
  String get twoFactorAuthFullDescription => 'لحماية إضافية، سيتم إرسال رمز تحقق إلى بريدك الإلكتروني أو عبر رسالة نصية عند تسجيل الدخول من جهاز جديد.';

  @override
  String get activate2FA => 'تفعيل التحقق بخطوتين';

  @override
  String get deactivate2FA => 'إلغاء تفعيل التحقق بخطوتين';

  @override
  String get twoFactorDeactivateWarning => 'سيؤدي إلغاء التحقق بخطوتين إلى تقليل أمان حسابك. هل أنت متأكد أنك تريد المتابعة؟';

  @override
  String get errorOccurred => 'حدث خطأ، يرجى المحاولة مرة أخرى';
}
