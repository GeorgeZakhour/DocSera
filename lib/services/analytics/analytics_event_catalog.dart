// =============================================================================
// Analytics Event Catalog — the contract between the app and the data layer.
// =============================================================================
// Every event the app emits MUST be registered here. The service rejects:
//   * unknown event names (compile-time safety via Events.* constants helps,
//     but runtime guard catches dynamic / typo cases too)
//   * unknown property keys (silently dropped; debug build emits a warning)
//   * required-property violations (event dropped; debug build warns)
//
// PHI rules are enforced at three layers:
//   1. SDK whitelist (this file) — only listed property keys allowed.
//   2. SDK value sanitizer — max 200 chars, no phone/email regex matches.
//   3. DB trigger backstop — same sanitization repeated server-side.
//
// When adding a new event:
//   1. Add a constant under Events.
//   2. Register its schema under _catalog with category + allowed/required props.
//   3. Document it in docs/launch/04a-event-taxonomy.md.
// =============================================================================

import 'dart:developer' as developer;

/// Namespaced event-name constants. Use these instead of raw strings.
class Events {
  // ----- App lifecycle -----
  static const appOpened          = 'app_opened';
  static const appForegrounded    = 'app_foregrounded';
  static const appBackgrounded    = 'app_backgrounded';
  static const sessionStart       = 'session_start';
  static const sessionEnd         = 'session_end';
  static const screenViewed       = 'screen_viewed';
  static const onboardingCompleted= 'onboarding_completed';

  // ----- Auth -----
  static const signupStarted      = 'signup_started';
  static const signupCompleted    = 'signup_completed';
  static const signupFailed       = 'signup_failed';
  static const loginStarted       = 'login_started';
  static const loginCompleted     = 'login_completed';
  static const loginFailed        = 'login_failed';
  static const logout             = 'logout';
  static const otpRequested       = 'otp_requested';
  static const otpVerified        = 'otp_verified';
  static const otpFailed          = 'otp_failed';
  static const otpResent          = 'otp_resent';
  static const biometricPrompted  = 'biometric_prompted';
  static const biometricSucceeded = 'biometric_succeeded';
  static const biometricFailed    = 'biometric_failed';
  static const forgotPasswordStarted   = 'forgot_password_started';
  static const forgotPasswordCompleted = 'forgot_password_completed';

  // ----- Search & discovery -----
  static const searchStarted        = 'search_started';
  static const searchFilterApplied  = 'search_filter_applied';
  static const searchFilterCleared  = 'search_filter_cleared';
  static const searchResultsViewed  = 'search_results_viewed';
  static const searchNoResultsShown = 'search_no_results_shown';
  static const searchResultClicked  = 'search_result_clicked';
  static const mapViewOpened        = 'map_view_opened';
  static const mapPinClicked        = 'map_pin_clicked';
  static const recentSearchClicked  = 'recent_search_clicked';

  // ----- Doctor profile -----
  static const doctorProfileViewed     = 'doctor_profile_viewed';
  static const doctorProfileScrolledEnd= 'doctor_profile_scrolled_to_bottom';
  static const doctorPhoneClicked      = 'doctor_phone_clicked';
  static const doctorEmailClicked      = 'doctor_email_clicked';
  static const doctorAddressClicked    = 'doctor_address_clicked';
  static const doctorDirectionsOpened  = 'doctor_directions_opened';
  static const doctorShareClicked      = 'doctor_share_clicked';
  static const doctorFavorited         = 'doctor_favorited';
  static const doctorUnfavorited       = 'doctor_unfavorited';
  static const doctorReviewSectionViewed= 'doctor_review_section_viewed';
  static const doctorScheduleViewed    = 'doctor_schedule_viewed';

  // ----- Booking funnel -----
  static const bookingStarted         = 'booking_started';
  static const bookingReasonSelected  = 'booking_reason_selected';
  static const bookingPatientSelected = 'booking_patient_selected';
  static const bookingDateViewed      = 'booking_date_viewed';
  static const bookingSlotPicked      = 'booking_slot_picked';
  static const bookingReviewShown     = 'booking_review_shown';
  static const bookingConfirmed       = 'booking_confirmed';
  static const bookingFailed          = 'booking_failed';
  static const bookingAbandoned       = 'booking_abandoned';

  // ----- Appointment lifecycle -----
  static const appointmentViewed         = 'appointment_viewed';
  static const appointmentRescheduled    = 'appointment_rescheduled';
  static const appointmentCancelled      = 'appointment_cancelled';
  static const appointmentReminderReceived = 'appointment_reminder_received';
  static const appointmentReviewSubmitted= 'appointment_review_submitted';

  // ----- Messaging -----
  static const conversationListViewed = 'conversation_list_viewed';
  static const conversationOpened     = 'conversation_opened';
  static const messageSent            = 'message_sent';
  static const messageFailed          = 'message_failed';
  static const attachmentSent         = 'attachment_sent';
  static const voiceMessageSent       = 'voice_message_sent';

  // ----- Documents -----
  static const documentsTabViewed     = 'documents_tab_viewed';
  static const documentUploaded       = 'document_uploaded';
  static const documentViewed         = 'document_viewed';
  static const documentDownloaded     = 'document_downloaded';
  static const documentShared         = 'document_shared';
  static const documentDeleted        = 'document_deleted';

  // ----- Loyalty / Offers / Vouchers / Partners -----
  static const loyaltyTabViewed       = 'loyalty_tab_viewed';
  static const pointsHistoryViewed    = 'points_history_viewed';
  static const pointsEarned           = 'points_earned';
  static const pointsRedeemed         = 'points_redeemed';
  static const offerViewed            = 'offer_viewed';
  static const offerClicked           = 'offer_clicked';
  static const offerRedeemed          = 'offer_redeemed';
  static const voucherReceived        = 'voucher_received';
  static const voucherViewed          = 'voucher_viewed';
  static const voucherUsed            = 'voucher_used';
  static const voucherExpired         = 'voucher_expired';
  static const voucherShared          = 'voucher_shared';
  static const partnerProfileViewed   = 'partner_profile_viewed';
  static const partnerPhoneClicked    = 'partner_phone_clicked';
  static const partnerAddressClicked  = 'partner_address_clicked';
  static const partnerDirectionsOpened= 'partner_directions_opened';

  // ----- Referrals -----
  static const referralScreenViewed   = 'referral_screen_viewed';
  static const referralLinkCopied     = 'referral_link_copied';
  static const referralLinkShared     = 'referral_link_shared';
  static const referralRewardEarned   = 'referral_reward_earned';

  // ----- Health profile -----
  static const healthProfileViewed    = 'health_profile_viewed';
  static const healthProfileEdited    = 'health_profile_edited';
  static const relativeAdded          = 'relative_added';
  static const relativeRemoved        = 'relative_removed';
  static const patientSwitched        = 'patient_switched';

  // ----- Account / Settings -----
  static const accountTabViewed       = 'account_tab_viewed';
  static const profileEdited          = 'profile_edited';
  static const languageChanged        = 'language_changed';
  static const notificationsSettingsChanged = 'notifications_settings_changed';
  static const biometricSettingsChanged     = 'biometric_settings_changed';
  static const accountDeletionStarted = 'account_deletion_started';
  static const accountDeletionCompleted = 'account_deletion_completed';
  static const supportContacted       = 'support_contacted';
  static const appRated               = 'app_rated';

  // ----- Banners / Popups / Push -----
  static const bannerViewed           = 'banner_viewed';
  static const bannerClicked          = 'banner_clicked';
  static const bannerDismissed        = 'banner_dismissed';
  static const popupShown             = 'popup_shown';
  static const popupActionTaken       = 'popup_action_taken';
  static const popupDismissed         = 'popup_dismissed';
  static const pushReceived           = 'push_received';
  static const pushOpened             = 'push_opened';
  static const deepLinkFollowed       = 'deep_link_followed';

  // ----- Errors / UX -----
  static const errorShown             = 'error_shown';
  static const offlineBannerShown     = 'offline_banner_shown';
  static const formValidationFailed   = 'form_validation_failed';
  static const emptyStateShown        = 'empty_state_shown';
}

/// Schema declared per event: which property keys are valid, which are required.
class EventSchema {
  final String category;
  final Set<String> allowedProperties;
  final Set<String> requiredProperties;

  const EventSchema({
    required this.category,
    this.allowedProperties = const {},
    this.requiredProperties = const {},
  });
}

/// The single source of truth. Adding an event without registering it here
/// causes the SDK to drop it (with a debug-mode warning).
final Map<String, EventSchema> _catalog = {
  // ---- App lifecycle ----
  Events.appOpened:           const EventSchema(category: 'app',
      allowedProperties: {'cold_start', 'time_since_last_open_seconds_bucket'}),
  Events.appForegrounded:     const EventSchema(category: 'app'),
  Events.appBackgrounded:     const EventSchema(category: 'app',
      allowedProperties: {'foreground_duration_seconds_bucket'}),
  Events.sessionStart:        const EventSchema(category: 'app',
      allowedProperties: {'session_id'}),
  Events.sessionEnd:          const EventSchema(category: 'app',
      allowedProperties: {'session_id', 'duration_seconds_bucket', 'reason'}),
  Events.screenViewed:        const EventSchema(category: 'app',
      allowedProperties: {'screen_name', 'previous_screen_name'},
      requiredProperties: {'screen_name'}),
  Events.onboardingCompleted: const EventSchema(category: 'app',
      allowedProperties: {'steps_seen'}),

  // ---- Auth ----
  Events.signupStarted:       const EventSchema(category: 'auth',
      allowedProperties: {'method'}),
  Events.signupCompleted:     const EventSchema(category: 'auth',
      allowedProperties: {'method'}),
  Events.signupFailed:        const EventSchema(category: 'auth',
      allowedProperties: {'method', 'error_code'}),
  Events.loginStarted:        const EventSchema(category: 'auth',
      allowedProperties: {'method'}),
  Events.loginCompleted:      const EventSchema(category: 'auth',
      allowedProperties: {'method'}),
  Events.loginFailed:         const EventSchema(category: 'auth',
      allowedProperties: {'method', 'error_code'}),
  Events.logout:              const EventSchema(category: 'auth'),
  Events.otpRequested:        const EventSchema(category: 'auth',
      allowedProperties: {'channel', 'context'},
      requiredProperties: {'channel'}),
  Events.otpVerified:         const EventSchema(category: 'auth',
      allowedProperties: {'channel', 'context', 'attempts'}),
  Events.otpFailed:           const EventSchema(category: 'auth',
      allowedProperties: {'channel', 'context', 'error_code', 'attempts'}),
  Events.otpResent:           const EventSchema(category: 'auth',
      allowedProperties: {'channel', 'attempt_number'}),
  Events.biometricPrompted:   const EventSchema(category: 'auth',
      allowedProperties: {'biometric_type'}),
  Events.biometricSucceeded:  const EventSchema(category: 'auth',
      allowedProperties: {'biometric_type'}),
  Events.biometricFailed:     const EventSchema(category: 'auth',
      allowedProperties: {'biometric_type', 'error_code'}),
  Events.forgotPasswordStarted:   const EventSchema(category: 'auth'),
  Events.forgotPasswordCompleted: const EventSchema(category: 'auth'),

  // ---- Search ----
  Events.searchStarted:         const EventSchema(category: 'search',
      allowedProperties: {'source'}),
  Events.searchFilterApplied:   const EventSchema(category: 'search',
      allowedProperties: {'filter_type', 'filter_value'}),
  Events.searchFilterCleared:   const EventSchema(category: 'search',
      allowedProperties: {'filter_type'}),
  Events.searchResultsViewed:   const EventSchema(category: 'search',
      allowedProperties: {'results_count_bucket', 'has_results'}),
  Events.searchNoResultsShown:  const EventSchema(category: 'search'),
  Events.searchResultClicked:   const EventSchema(category: 'search',
      allowedProperties: {'doctor_id', 'position_bucket', 'list_type'}),
  Events.mapViewOpened:         const EventSchema(category: 'search'),
  Events.mapPinClicked:         const EventSchema(category: 'search',
      allowedProperties: {'doctor_id'}),
  Events.recentSearchClicked:   const EventSchema(category: 'search'),

  // ---- Doctor profile ----
  Events.doctorProfileViewed: const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id', 'source', 'specialty_id'},
      requiredProperties: {'doctor_id'}),
  Events.doctorProfileScrolledEnd: const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'}),
  Events.doctorPhoneClicked:  const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'},
      requiredProperties: {'doctor_id'}),
  Events.doctorEmailClicked:  const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'}),
  Events.doctorAddressClicked: const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'}),
  Events.doctorDirectionsOpened: const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'}),
  Events.doctorShareClicked:  const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id', 'share_method'}),
  Events.doctorFavorited:     const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'},
      requiredProperties: {'doctor_id'}),
  Events.doctorUnfavorited:   const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'},
      requiredProperties: {'doctor_id'}),
  Events.doctorReviewSectionViewed: const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'}),
  Events.doctorScheduleViewed: const EventSchema(category: 'doctor',
      allowedProperties: {'doctor_id'}),

  // ---- Booking funnel ----
  Events.bookingStarted:        const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'source'},
      requiredProperties: {'doctor_id'}),
  Events.bookingReasonSelected: const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'reason_id'}),
  Events.bookingPatientSelected: const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'patient_kind'}),
  Events.bookingDateViewed:     const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'days_offset_bucket'}),
  Events.bookingSlotPicked:     const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'slot_offset_days_bucket', 'slot_hour_bucket'}),
  Events.bookingReviewShown:    const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id'}),
  Events.bookingConfirmed:      const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'appointment_id', 'reason_id', 'patient_kind'},
      requiredProperties: {'doctor_id'}),
  Events.bookingFailed:         const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'error_code'}),
  Events.bookingAbandoned:      const EventSchema(category: 'booking',
      allowedProperties: {'doctor_id', 'last_step_reached'}),

  // ---- Appointment lifecycle ----
  Events.appointmentViewed:         const EventSchema(category: 'appointment',
      allowedProperties: {'appointment_id'}),
  Events.appointmentRescheduled:    const EventSchema(category: 'appointment',
      allowedProperties: {'appointment_id'}),
  Events.appointmentCancelled:      const EventSchema(category: 'appointment',
      allowedProperties: {'appointment_id', 'cancellation_reason_id'}),
  Events.appointmentReminderReceived: const EventSchema(category: 'appointment',
      allowedProperties: {'appointment_id', 'minutes_before'}),
  Events.appointmentReviewSubmitted: const EventSchema(category: 'appointment',
      allowedProperties: {'appointment_id', 'rating'}),

  // ---- Messaging ----
  Events.conversationListViewed: const EventSchema(category: 'messaging'),
  Events.conversationOpened:    const EventSchema(category: 'messaging',
      allowedProperties: {'conversation_id'}),
  Events.messageSent:           const EventSchema(category: 'messaging',
      allowedProperties: {'conversation_id', 'length_bucket', 'has_attachment'}),
  Events.messageFailed:         const EventSchema(category: 'messaging',
      allowedProperties: {'conversation_id', 'error_code'}),
  Events.attachmentSent:        const EventSchema(category: 'messaging',
      allowedProperties: {'conversation_id', 'attachment_type', 'size_bucket'}),
  Events.voiceMessageSent:      const EventSchema(category: 'messaging',
      allowedProperties: {'conversation_id', 'duration_seconds_bucket'}),

  // ---- Documents ----
  Events.documentsTabViewed:    const EventSchema(category: 'documents'),
  Events.documentUploaded:      const EventSchema(category: 'documents',
      allowedProperties: {'document_type', 'source', 'size_bucket'}),
  Events.documentViewed:        const EventSchema(category: 'documents',
      allowedProperties: {'document_id', 'document_type'}),
  Events.documentDownloaded:    const EventSchema(category: 'documents',
      allowedProperties: {'document_id', 'document_type'}),
  Events.documentShared:        const EventSchema(category: 'documents',
      allowedProperties: {'document_id', 'share_method'}),
  Events.documentDeleted:       const EventSchema(category: 'documents',
      allowedProperties: {'document_id'}),

  // ---- Loyalty / Offers / Vouchers / Partners ----
  Events.loyaltyTabViewed:      const EventSchema(category: 'loyalty'),
  Events.pointsHistoryViewed:   const EventSchema(category: 'loyalty'),
  Events.pointsEarned:          const EventSchema(category: 'loyalty',
      allowedProperties: {'source', 'amount_bucket'}),
  Events.pointsRedeemed:        const EventSchema(category: 'loyalty',
      allowedProperties: {'offer_id', 'points_spent_bucket'}),
  Events.offerViewed:           const EventSchema(category: 'loyalty',
      allowedProperties: {'offer_id', 'partner_id', 'position_bucket', 'list_context'},
      requiredProperties: {'offer_id'}),
  Events.offerClicked:          const EventSchema(category: 'loyalty',
      allowedProperties: {'offer_id', 'partner_id', 'position_bucket'},
      requiredProperties: {'offer_id'}),
  Events.offerRedeemed:         const EventSchema(category: 'loyalty',
      allowedProperties: {'offer_id', 'partner_id', 'voucher_id'},
      requiredProperties: {'offer_id'}),
  Events.voucherReceived:       const EventSchema(category: 'loyalty',
      allowedProperties: {'voucher_id', 'offer_id', 'partner_id', 'source'}),
  Events.voucherViewed:         const EventSchema(category: 'loyalty',
      allowedProperties: {'voucher_id'}),
  Events.voucherUsed:           const EventSchema(category: 'loyalty',
      allowedProperties: {'voucher_id', 'partner_id'},
      requiredProperties: {'voucher_id'}),
  Events.voucherExpired:        const EventSchema(category: 'loyalty',
      allowedProperties: {'voucher_id'}),
  Events.voucherShared:         const EventSchema(category: 'loyalty',
      allowedProperties: {'voucher_id', 'share_method'}),
  Events.partnerProfileViewed:  const EventSchema(category: 'partner',
      allowedProperties: {'partner_id', 'source'},
      requiredProperties: {'partner_id'}),
  Events.partnerPhoneClicked:   const EventSchema(category: 'partner',
      allowedProperties: {'partner_id'},
      requiredProperties: {'partner_id'}),
  Events.partnerAddressClicked: const EventSchema(category: 'partner',
      allowedProperties: {'partner_id'}),
  Events.partnerDirectionsOpened: const EventSchema(category: 'partner',
      allowedProperties: {'partner_id'}),

  // ---- Referrals ----
  Events.referralScreenViewed:  const EventSchema(category: 'referral'),
  Events.referralLinkCopied:    const EventSchema(category: 'referral'),
  Events.referralLinkShared:    const EventSchema(category: 'referral',
      allowedProperties: {'channel'}),
  Events.referralRewardEarned:  const EventSchema(category: 'referral',
      allowedProperties: {'amount_bucket'}),

  // ---- Health profile ----
  Events.healthProfileViewed:   const EventSchema(category: 'health_profile'),
  Events.healthProfileEdited:   const EventSchema(category: 'health_profile',
      allowedProperties: {'field_type'}),
  Events.relativeAdded:         const EventSchema(category: 'health_profile'),
  Events.relativeRemoved:       const EventSchema(category: 'health_profile'),
  Events.patientSwitched:       const EventSchema(category: 'health_profile',
      allowedProperties: {'to_kind'}),

  // ---- Account / Settings ----
  Events.accountTabViewed:      const EventSchema(category: 'account'),
  Events.profileEdited:         const EventSchema(category: 'account',
      allowedProperties: {'field_type'}),
  Events.languageChanged:       const EventSchema(category: 'account',
      allowedProperties: {'from', 'to'}),
  Events.notificationsSettingsChanged: const EventSchema(category: 'account',
      allowedProperties: {'channel', 'enabled'}),
  Events.biometricSettingsChanged: const EventSchema(category: 'account',
      allowedProperties: {'enabled'}),
  Events.accountDeletionStarted:   const EventSchema(category: 'account'),
  Events.accountDeletionCompleted: const EventSchema(category: 'account'),
  Events.supportContacted:      const EventSchema(category: 'account',
      allowedProperties: {'channel'}),
  Events.appRated:              const EventSchema(category: 'account',
      allowedProperties: {'rating', 'where_prompted'}),

  // ---- Banners / Popups / Push ----
  Events.bannerViewed:          const EventSchema(category: 'banner',
      allowedProperties: {'banner_id', 'position'}),
  Events.bannerClicked:         const EventSchema(category: 'banner',
      allowedProperties: {'banner_id', 'action'}),
  Events.bannerDismissed:       const EventSchema(category: 'banner',
      allowedProperties: {'banner_id'}),
  Events.popupShown:            const EventSchema(category: 'popup',
      allowedProperties: {'popup_id', 'type'}),
  Events.popupActionTaken:      const EventSchema(category: 'popup',
      allowedProperties: {'popup_id', 'action'}),
  Events.popupDismissed:        const EventSchema(category: 'popup',
      allowedProperties: {'popup_id'}),
  Events.pushReceived:          const EventSchema(category: 'push',
      allowedProperties: {'notification_type'}),
  Events.pushOpened:            const EventSchema(category: 'push',
      allowedProperties: {'notification_type'}),
  Events.deepLinkFollowed:      const EventSchema(category: 'app',
      allowedProperties: {'path_kind'}),

  // ---- Errors / UX ----
  Events.errorShown:            const EventSchema(category: 'error',
      allowedProperties: {'error_code', 'screen'}),
  Events.offlineBannerShown:    const EventSchema(category: 'error'),
  Events.formValidationFailed:  const EventSchema(category: 'error',
      allowedProperties: {'form_id', 'field_id', 'error_type'}),
  Events.emptyStateShown:       const EventSchema(category: 'error',
      allowedProperties: {'screen', 'type'}),
};

class AnalyticsEventCatalog {
  AnalyticsEventCatalog._();

  static EventSchema? schemaFor(String eventName) => _catalog[eventName];

  static bool isRegistered(String eventName) => _catalog.containsKey(eventName);

  /// Validates and sanitizes a payload against its schema. Returns the cleaned
  /// property map, or `null` if the event must be dropped.
  static Map<String, dynamic>? validateAndSanitize(
    String eventName,
    Map<String, dynamic> properties, {
    bool warnInDebug = true,
  }) {
    final schema = _catalog[eventName];
    if (schema == null) {
      if (warnInDebug) {
        developer.log('[Analytics] dropped: unknown event "$eventName"',
            name: 'analytics');
      }
      return null;
    }

    // Required-property check.
    for (final req in schema.requiredProperties) {
      final v = properties[req];
      if (v == null || (v is String && v.isEmpty)) {
        if (warnInDebug) {
          developer.log(
              '[Analytics] dropped: "$eventName" missing required "$req"',
              name: 'analytics');
        }
        return null;
      }
    }

    // Property whitelist + value sanitization.
    final cleaned = <String, dynamic>{};
    properties.forEach((k, v) {
      if (!schema.allowedProperties.contains(k)) {
        if (warnInDebug) {
          developer.log(
              '[Analytics] dropped property "$k" on "$eventName" (not in schema)',
              name: 'analytics');
        }
        return;
      }
      final sanitized = _sanitizeValue(v);
      if (sanitized == null) {
        if (warnInDebug) {
          developer.log(
              '[Analytics] dropped property "$k" on "$eventName" (PII / oversized)',
              name: 'analytics');
        }
        return;
      }
      cleaned[k] = sanitized;
    });

    return cleaned;
  }

  // ---------------------------------------------------------------------------
  // Value-level sanitizer. Mirrors the DB trigger.
  // Keeps: strings ≤ 200 chars, ints, doubles, bools, ISO timestamps.
  // Drops: PII-pattern strings (phone, email), oversized strings.
  // ---------------------------------------------------------------------------
  static dynamic _sanitizeValue(dynamic v) {
    if (v == null) return null;
    if (v is num || v is bool) return v;
    if (v is String) {
      if (v.length > 200) return null;
      if (_phoneRe.hasMatch(v)) return null;
      if (_emailRe.hasMatch(v)) return null;
      return v;
    }
    // Anything else (lists, maps): only allow if all primitives. Conservative:
    // stringify if simple, drop if complex. JSONB stores objects fine but our
    // taxonomy doesn't currently use them.
    if (v is List || v is Map) return null;
    return null;
  }

  // Phone-shape match — anchored to start AND end so a value only flags as a
  // phone number if the WHOLE string is phone-shaped (digits, spaces, dashes,
  // parens, optional leading +). UUIDs and other mixed strings won't match.
  static final RegExp _phoneRe = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
  static final RegExp _emailRe = RegExp(
      r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
}
