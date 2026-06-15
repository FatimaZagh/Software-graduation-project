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
/// import 'l10n/app_localizations.dart';
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
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Rafeeq'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get navBook;

  /// No description provided for @navPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get navPharmacy;

  /// No description provided for @navHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get navHealth;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSettings;

  /// No description provided for @medicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get medicalRecords;

  /// No description provided for @medicalRecordBloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get medicalRecordBloodType;

  /// No description provided for @medicalRecordAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get medicalRecordAllergies;

  /// No description provided for @medicalRecordChronicConditions.
  ///
  /// In en, this message translates to:
  /// **'Chronic Conditions'**
  String get medicalRecordChronicConditions;

  /// No description provided for @medicalRecordNoneReported.
  ///
  /// In en, this message translates to:
  /// **'None reported'**
  String get medicalRecordNoneReported;

  /// No description provided for @medicalRecordNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get medicalRecordNone;

  /// No description provided for @medicalRecordEncounterTimeline.
  ///
  /// In en, this message translates to:
  /// **'Encounter Timeline'**
  String get medicalRecordEncounterTimeline;

  /// No description provided for @medicalRecordNoVisits.
  ///
  /// In en, this message translates to:
  /// **'No registered visits yet'**
  String get medicalRecordNoVisits;

  /// No description provided for @medicalRecordNoVisitsHint.
  ///
  /// In en, this message translates to:
  /// **'Your clinical visit history will appear here after you complete appointments with your care team.'**
  String get medicalRecordNoVisitsHint;

  /// No description provided for @medicalRecordChiefComplaint.
  ///
  /// In en, this message translates to:
  /// **'Symptoms & Complaint'**
  String get medicalRecordChiefComplaint;

  /// No description provided for @medicalRecordDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Clinical Diagnosis'**
  String get medicalRecordDiagnosis;

  /// No description provided for @medicalRecordVitals.
  ///
  /// In en, this message translates to:
  /// **'Recorded Vital Signs'**
  String get medicalRecordVitals;

  /// No description provided for @medicalRecordDoctorNotes.
  ///
  /// In en, this message translates to:
  /// **'Physician Assessment Notes'**
  String get medicalRecordDoctorNotes;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @doctorDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor workspace'**
  String get doctorDashboardTitle;

  /// No description provided for @doctorNavOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get doctorNavOverview;

  /// No description provided for @doctorNavAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get doctorNavAppointments;

  /// No description provided for @doctorNavMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get doctorNavMessages;

  /// No description provided for @doctorNavReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get doctorNavReviews;

  /// No description provided for @doctorDrawerProfile.
  ///
  /// In en, this message translates to:
  /// **'Professional profile'**
  String get doctorDrawerProfile;

  /// No description provided for @doctorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get doctorRetry;

  /// No description provided for @doctorPatientsToday.
  ///
  /// In en, this message translates to:
  /// **'Patients today'**
  String get doctorPatientsToday;

  /// No description provided for @doctorTotalAppointments.
  ///
  /// In en, this message translates to:
  /// **'Your appointments'**
  String get doctorTotalAppointments;

  /// No description provided for @doctorEarningsToday.
  ///
  /// In en, this message translates to:
  /// **'Earnings today (ILS)'**
  String get doctorEarningsToday;

  /// No description provided for @doctorPatientsUnique.
  ///
  /// In en, this message translates to:
  /// **'Distinct patients'**
  String get doctorPatientsUnique;

  /// No description provided for @doctorCancellationRate.
  ///
  /// In en, this message translates to:
  /// **'Cancellation rate %'**
  String get doctorCancellationRate;

  /// No description provided for @doctorQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming & queue'**
  String get doctorQueueTitle;

  /// No description provided for @doctorNoAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments match your profile.'**
  String get doctorNoAppointments;

  /// No description provided for @doctorBookingPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get doctorBookingPending;

  /// No description provided for @doctorBookingAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get doctorBookingAccepted;

  /// No description provided for @doctorBookingRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get doctorBookingRejected;

  /// No description provided for @doctorVisitWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get doctorVisitWaiting;

  /// No description provided for @doctorVisitInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get doctorVisitInProgress;

  /// No description provided for @doctorVisitCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get doctorVisitCompleted;

  /// No description provided for @doctorAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get doctorAccept;

  /// No description provided for @doctorReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get doctorReject;

  /// No description provided for @doctorReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get doctorReschedule;

  /// No description provided for @doctorStartVisit.
  ///
  /// In en, this message translates to:
  /// **'Start visit'**
  String get doctorStartVisit;

  /// No description provided for @doctorEndVisit.
  ///
  /// In en, this message translates to:
  /// **'End visit'**
  String get doctorEndVisit;

  /// No description provided for @doctorOpenConsultation.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get doctorOpenConsultation;

  /// No description provided for @doctorWaitingList.
  ///
  /// In en, this message translates to:
  /// **'Waiting list'**
  String get doctorWaitingList;

  /// No description provided for @doctorWaitingListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active waiting-list entries.'**
  String get doctorWaitingListEmpty;

  /// No description provided for @doctorChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient messages'**
  String get doctorChatTitle;

  /// No description provided for @doctorSelectPatient.
  ///
  /// In en, this message translates to:
  /// **'Select patient'**
  String get doctorSelectPatient;

  /// No description provided for @doctorChatHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message (updates every few seconds).'**
  String get doctorChatHint;

  /// No description provided for @doctorSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get doctorSend;

  /// No description provided for @doctorReviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get doctorReviewsTitle;

  /// No description provided for @doctorNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No ratings linked to your account yet.'**
  String get doctorNoReviews;

  /// No description provided for @doctorStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get doctorStars;

  /// No description provided for @doctorPunctuality.
  ///
  /// In en, this message translates to:
  /// **'Punctuality'**
  String get doctorPunctuality;

  /// No description provided for @doctorCleanliness.
  ///
  /// In en, this message translates to:
  /// **'Cleanliness'**
  String get doctorCleanliness;

  /// No description provided for @doctorBehavior.
  ///
  /// In en, this message translates to:
  /// **'Doctor behavior'**
  String get doctorBehavior;

  /// No description provided for @doctorComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get doctorComment;

  /// No description provided for @doctorTabPreconsult.
  ///
  /// In en, this message translates to:
  /// **'Pre-consult'**
  String get doctorTabPreconsult;

  /// No description provided for @doctorTabSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get doctorTabSession;

  /// No description provided for @doctorTabRx.
  ///
  /// In en, this message translates to:
  /// **'E-prescription'**
  String get doctorTabRx;

  /// No description provided for @doctorSessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get doctorSessionSaved;

  /// No description provided for @doctorRxNeedMed.
  ///
  /// In en, this message translates to:
  /// **'Add at least one medication name.'**
  String get doctorRxNeedMed;

  /// No description provided for @doctorRxSaved.
  ///
  /// In en, this message translates to:
  /// **'Prescription sent to patient & pharmacy'**
  String get doctorRxSaved;

  /// No description provided for @doctorChronic.
  ///
  /// In en, this message translates to:
  /// **'Chronic diseases'**
  String get doctorChronic;

  /// No description provided for @doctorNone.
  ///
  /// In en, this message translates to:
  /// **'None on file'**
  String get doctorNone;

  /// No description provided for @doctorAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get doctorAllergies;

  /// No description provided for @doctorSurgeries.
  ///
  /// In en, this message translates to:
  /// **'Past surgeries'**
  String get doctorSurgeries;

  /// No description provided for @doctorMeds.
  ///
  /// In en, this message translates to:
  /// **'Current medications'**
  String get doctorMeds;

  /// No description provided for @doctorPrevVisits.
  ///
  /// In en, this message translates to:
  /// **'Previous visits'**
  String get doctorPrevVisits;

  /// No description provided for @doctorPatientRecord.
  ///
  /// In en, this message translates to:
  /// **'Patient record'**
  String get doctorPatientRecord;

  /// No description provided for @doctorDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get doctorDiagnosis;

  /// No description provided for @doctorNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get doctorNotes;

  /// No description provided for @doctorVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get doctorVitals;

  /// No description provided for @doctorWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get doctorWeightKg;

  /// No description provided for @doctorBpSys.
  ///
  /// In en, this message translates to:
  /// **'BP systolic'**
  String get doctorBpSys;

  /// No description provided for @doctorBpDia.
  ///
  /// In en, this message translates to:
  /// **'BP diastolic'**
  String get doctorBpDia;

  /// No description provided for @doctorHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get doctorHeartRate;

  /// No description provided for @doctorAttachScan.
  ///
  /// In en, this message translates to:
  /// **'Attach scan / lab image'**
  String get doctorAttachScan;

  /// No description provided for @doctorAttachmentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} attachments on file'**
  String doctorAttachmentsCount(int count);

  /// No description provided for @doctorSaveSession.
  ///
  /// In en, this message translates to:
  /// **'Save session'**
  String get doctorSaveSession;

  /// No description provided for @doctorMedName.
  ///
  /// In en, this message translates to:
  /// **'Medication name'**
  String get doctorMedName;

  /// No description provided for @doctorMedDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get doctorMedDosage;

  /// No description provided for @doctorMedDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get doctorMedDuration;

  /// No description provided for @doctorMedInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get doctorMedInstructions;

  /// No description provided for @doctorMedFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get doctorMedFrequency;

  /// No description provided for @doctorAddMedLine.
  ///
  /// In en, this message translates to:
  /// **'Add medication line'**
  String get doctorAddMedLine;

  /// No description provided for @doctorPickSignature.
  ///
  /// In en, this message translates to:
  /// **'Pick signature image'**
  String get doctorPickSignature;

  /// No description provided for @doctorSignatureReady.
  ///
  /// In en, this message translates to:
  /// **'Signature attached'**
  String get doctorSignatureReady;

  /// No description provided for @doctorSubmitRx.
  ///
  /// In en, this message translates to:
  /// **'Submit prescription'**
  String get doctorSubmitRx;

  /// No description provided for @doctorProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Professional profile'**
  String get doctorProfileTitle;

  /// No description provided for @doctorFieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get doctorFieldDisplayName;

  /// No description provided for @doctorFieldSpecialization.
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get doctorFieldSpecialization;

  /// No description provided for @doctorFieldYears.
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get doctorFieldYears;

  /// No description provided for @doctorFieldCertifications.
  ///
  /// In en, this message translates to:
  /// **'Certifications (comma-separated)'**
  String get doctorFieldCertifications;

  /// No description provided for @doctorFieldFee.
  ///
  /// In en, this message translates to:
  /// **'Consultation fee (ILS)'**
  String get doctorFieldFee;

  /// No description provided for @doctorFieldPhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get doctorFieldPhoto;

  /// No description provided for @doctorPickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get doctorPickPhoto;

  /// No description provided for @doctorApplySchedule.
  ///
  /// In en, this message translates to:
  /// **'Apply Mon–Fri 09:00–17:00 with lunch break'**
  String get doctorApplySchedule;

  /// No description provided for @doctorScheduleApplied.
  ///
  /// In en, this message translates to:
  /// **'Standard work schedule applied (save to persist).'**
  String get doctorScheduleApplied;

  /// No description provided for @doctorSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get doctorSaveProfile;

  /// No description provided for @doctorProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get doctorProfileSaved;

  /// No description provided for @doctorPollHint.
  ///
  /// In en, this message translates to:
  /// **'Lists refresh automatically every 8 seconds.'**
  String get doctorPollHint;

  /// No description provided for @doctorLabelBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get doctorLabelBooking;

  /// No description provided for @doctorLabelVisit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get doctorLabelVisit;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

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

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @doctorGridAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get doctorGridAppointments;

  /// No description provided for @doctorGridWaitingList.
  ///
  /// In en, this message translates to:
  /// **'Waiting List'**
  String get doctorGridWaitingList;

  /// No description provided for @doctorGridMySchedule.
  ///
  /// In en, this message translates to:
  /// **'My Schedule'**
  String get doctorGridMySchedule;

  /// No description provided for @doctorGridPatientRecords.
  ///
  /// In en, this message translates to:
  /// **'Patient Records'**
  String get doctorGridPatientRecords;

  /// No description provided for @doctorGridEPrescription.
  ///
  /// In en, this message translates to:
  /// **'E-Prescription'**
  String get doctorGridEPrescription;

  /// No description provided for @doctorGridOrderLab.
  ///
  /// In en, this message translates to:
  /// **'Order Lab Test'**
  String get doctorGridOrderLab;

  /// No description provided for @doctorGridOrderImaging.
  ///
  /// In en, this message translates to:
  /// **'Order Imaging'**
  String get doctorGridOrderImaging;

  /// No description provided for @doctorGridClinicAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Clinic Analytics'**
  String get doctorGridClinicAnalytics;

  /// No description provided for @doctorGridIncomingMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get doctorGridIncomingMessages;

  /// No description provided for @doctorGridActivePatients.
  ///
  /// In en, this message translates to:
  /// **'Active Patients'**
  String get doctorGridActivePatients;

  /// No description provided for @doctorGridCompletedVisits.
  ///
  /// In en, this message translates to:
  /// **'Completed Visits'**
  String get doctorGridCompletedVisits;

  /// No description provided for @doctorGridDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get doctorGridDashboard;

  /// No description provided for @doctorGridPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get doctorGridPatients;

  /// No description provided for @doctorGridLabResults.
  ///
  /// In en, this message translates to:
  /// **'Lab Results'**
  String get doctorGridLabResults;

  /// No description provided for @doctorGridRadiologyResults.
  ///
  /// In en, this message translates to:
  /// **'Radiology Results'**
  String get doctorGridRadiologyResults;

  /// No description provided for @doctorGridProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get doctorGridProfile;

  /// No description provided for @doctorGridMyPatients.
  ///
  /// In en, this message translates to:
  /// **'My Patients'**
  String get doctorGridMyPatients;

  /// No description provided for @doctorLanguageToggle.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get doctorLanguageToggle;

  /// No description provided for @doctorGridAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get doctorGridAvailability;

  /// No description provided for @doctorGridTodaysQueue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s queue'**
  String get doctorGridTodaysQueue;

  /// No description provided for @doctorGridNoPatientsToday.
  ///
  /// In en, this message translates to:
  /// **'No patients scheduled today.'**
  String get doctorGridNoPatientsToday;

  /// No description provided for @doctorGridAdrReports.
  ///
  /// In en, this message translates to:
  /// **'ADR reports'**
  String get doctorGridAdrReports;

  /// No description provided for @doctorGridNoAdrReports.
  ///
  /// In en, this message translates to:
  /// **'No adverse drug reports.'**
  String get doctorGridNoAdrReports;

  /// No description provided for @doctorGridDailyCases.
  ///
  /// In en, this message translates to:
  /// **'Daily cases'**
  String get doctorGridDailyCases;

  /// No description provided for @doctorGridChronic.
  ///
  /// In en, this message translates to:
  /// **'Chronic'**
  String get doctorGridChronic;

  /// No description provided for @doctorGridFollowUps.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups'**
  String get doctorGridFollowUps;

  /// No description provided for @doctorGridClinicalOverview.
  ///
  /// In en, this message translates to:
  /// **'Clinical overview'**
  String get doctorGridClinicalOverview;

  /// No description provided for @doctorGridQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get doctorGridQuickActions;

  /// No description provided for @superAdminPlatformTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Super Admin'**
  String get superAdminPlatformTitle;

  /// No description provided for @superAdminPlatformSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Control Center'**
  String get superAdminPlatformSubtitle;

  /// No description provided for @superAdminMedicalOrdersFeed.
  ///
  /// In en, this message translates to:
  /// **'Medical Orders'**
  String get superAdminMedicalOrdersFeed;

  /// No description provided for @superAdminRegisteredOrganizations.
  ///
  /// In en, this message translates to:
  /// **'Registered Organizations'**
  String get superAdminRegisteredOrganizations;

  /// No description provided for @superAdminPendingApplications.
  ///
  /// In en, this message translates to:
  /// **'Pending Applications'**
  String get superAdminPendingApplications;

  /// No description provided for @superAdminFinancialLedger.
  ///
  /// In en, this message translates to:
  /// **'Financial Ledger'**
  String get superAdminFinancialLedger;

  /// No description provided for @superAdminMedicalOrdersFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'All Medical Orders Feed'**
  String get superAdminMedicalOrdersFeedTitle;

  /// No description provided for @superAdminMedicalOrdersFeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lab, imaging, and e-prescription requests across all facilities — live tracking'**
  String get superAdminMedicalOrdersFeedSubtitle;

  /// No description provided for @superAdminPlatformOverview.
  ///
  /// In en, this message translates to:
  /// **'Platform overview'**
  String get superAdminPlatformOverview;

  /// No description provided for @superAdminLiveOrderActivity.
  ///
  /// In en, this message translates to:
  /// **'Live medical activity'**
  String get superAdminLiveOrderActivity;

  /// No description provided for @superAdminStatClinics.
  ///
  /// In en, this message translates to:
  /// **'Clinics'**
  String get superAdminStatClinics;

  /// No description provided for @superAdminStatSystemUsers.
  ///
  /// In en, this message translates to:
  /// **'System Users'**
  String get superAdminStatSystemUsers;

  /// No description provided for @superAdminStatDoctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get superAdminStatDoctors;

  /// No description provided for @superAdminStatTotalPatients.
  ///
  /// In en, this message translates to:
  /// **'Total Patients'**
  String get superAdminStatTotalPatients;

  /// No description provided for @superAdminOrdersTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get superAdminOrdersTotal;

  /// No description provided for @superAdminOrdersLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get superAdminOrdersLab;

  /// No description provided for @superAdminOrdersImaging.
  ///
  /// In en, this message translates to:
  /// **'Imaging'**
  String get superAdminOrdersImaging;

  /// No description provided for @superAdminOrdersRx.
  ///
  /// In en, this message translates to:
  /// **'Rx'**
  String get superAdminOrdersRx;

  /// No description provided for @superAdminNoMedicalOrders.
  ///
  /// In en, this message translates to:
  /// **'No medical orders recorded yet.'**
  String get superAdminNoMedicalOrders;

  /// No description provided for @superAdminPatientIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get superAdminPatientIdLabel;

  /// No description provided for @superAdminOrderTypeLab.
  ///
  /// In en, this message translates to:
  /// **'LAB TEST'**
  String get superAdminOrderTypeLab;

  /// No description provided for @superAdminOrderTypeImaging.
  ///
  /// In en, this message translates to:
  /// **'IMAGING'**
  String get superAdminOrderTypeImaging;

  /// No description provided for @superAdminOrderTypePrescription.
  ///
  /// In en, this message translates to:
  /// **'PRESCRIPTION'**
  String get superAdminOrderTypePrescription;

  /// No description provided for @superAdminOrderStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get superAdminOrderStatusRequested;

  /// No description provided for @superAdminOrderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get superAdminOrderStatusPending;

  /// No description provided for @superAdminOrderStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get superAdminOrderStatusCompleted;

  /// No description provided for @superAdminLanguageToggle.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get superAdminLanguageToggle;

  /// No description provided for @superAdminFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get superAdminFilterAll;

  /// No description provided for @superAdminFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get superAdminFilterActive;

  /// No description provided for @superAdminFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get superAdminFilterPending;

  /// No description provided for @superAdminFilterSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get superAdminFilterSuspended;

  /// No description provided for @superAdminNoOrganizations.
  ///
  /// In en, this message translates to:
  /// **'No organizations registered yet.'**
  String get superAdminNoOrganizations;

  /// No description provided for @superAdminRegisteredOn.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get superAdminRegisteredOn;

  /// No description provided for @superAdminNoPendingFacilities.
  ///
  /// In en, this message translates to:
  /// **'No pending facility registrations.'**
  String get superAdminNoPendingFacilities;

  /// No description provided for @superAdminNoPendingStaffRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending staff registration requests.'**
  String get superAdminNoPendingStaffRequests;

  /// No description provided for @superAdminNoPendingStaffAccounts.
  ///
  /// In en, this message translates to:
  /// **'No pending staff user accounts.'**
  String get superAdminNoPendingStaffAccounts;

  /// No description provided for @superAdminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get superAdminApprove;

  /// No description provided for @superAdminApproving.
  ///
  /// In en, this message translates to:
  /// **'…'**
  String get superAdminApproving;

  /// No description provided for @superAdminOrganizationApproved.
  ///
  /// In en, this message translates to:
  /// **'Organization approved.'**
  String get superAdminOrganizationApproved;

  /// No description provided for @superAdminLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Ledger & Billing'**
  String get superAdminLedgerTitle;

  /// No description provided for @superAdminOrganizationsMetric.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get superAdminOrganizationsMetric;

  /// No description provided for @superAdminActiveMetric.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get superAdminActiveMetric;

  /// No description provided for @superAdminPaymentsMetric.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get superAdminPaymentsMetric;

  /// No description provided for @superAdminPendingInvoicesMetric.
  ///
  /// In en, this message translates to:
  /// **'Pending invoices'**
  String get superAdminPendingInvoicesMetric;

  /// No description provided for @superAdminEntitySubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Entity subscriptions'**
  String get superAdminEntitySubscriptions;

  /// No description provided for @superAdminRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get superAdminRecentTransactions;

  /// No description provided for @superAdminNoBillingEntities.
  ///
  /// In en, this message translates to:
  /// **'No billing entities yet.'**
  String get superAdminNoBillingEntities;

  /// No description provided for @superAdminNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions recorded yet.'**
  String get superAdminNoTransactions;

  /// No description provided for @superAdminPharmacyDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy Dashboard'**
  String get superAdminPharmacyDashboardTitle;

  /// No description provided for @superAdminSalesAndFinancials.
  ///
  /// In en, this message translates to:
  /// **'Sales & Financials'**
  String get superAdminSalesAndFinancials;

  /// No description provided for @superAdminTotalSales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get superAdminTotalSales;

  /// No description provided for @superAdminMonthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue'**
  String get superAdminMonthlyRevenue;

  /// No description provided for @superAdminWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get superAdminWalletBalance;

  /// No description provided for @superAdminInventoryShortages.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock / Low Inventory'**
  String get superAdminInventoryShortages;

  /// No description provided for @superAdminMedicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine Name'**
  String get superAdminMedicineName;

  /// No description provided for @superAdminStockStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get superAdminStockStatus;

  /// No description provided for @superAdminActivePrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Active Prescriptions'**
  String get superAdminActivePrescriptions;

  /// No description provided for @superAdminPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get superAdminPendingOrders;

  /// No description provided for @superAdminProcessedOrders.
  ///
  /// In en, this message translates to:
  /// **'Processed Orders'**
  String get superAdminProcessedOrders;

  /// No description provided for @superAdminTotalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get superAdminTotalOrders;

  /// No description provided for @superAdminNoShortages.
  ///
  /// In en, this message translates to:
  /// **'No inventory shortages.'**
  String get superAdminNoShortages;

  /// No description provided for @superAdminTapToViewPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Tap to open pharmacy dashboard'**
  String get superAdminTapToViewPharmacy;

  /// No description provided for @superAdminPendingQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Applications Queue ({count})'**
  String superAdminPendingQueueTitle(int count);

  /// No description provided for @superAdminFacilityRegistrations.
  ///
  /// In en, this message translates to:
  /// **'Facility registrations ({count})'**
  String superAdminFacilityRegistrations(int count);

  /// No description provided for @superAdminStaffRegistrationRequests.
  ///
  /// In en, this message translates to:
  /// **'Staff registration requests ({count})'**
  String superAdminStaffRegistrationRequests(int count);

  /// No description provided for @superAdminPendingStaffAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending staff accounts ({count})'**
  String superAdminPendingStaffAccountsTitle(int count);

  /// No description provided for @superAdminOrgStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} · {subscription}'**
  String superAdminOrgStatusLine(String status, String subscription);

  /// No description provided for @superAdminPendingAmount.
  ///
  /// In en, this message translates to:
  /// **'Pending {amount}'**
  String superAdminPendingAmount(String amount);

  /// No description provided for @superAdminInventoryOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get superAdminInventoryOutOfStock;

  /// No description provided for @superAdminInventoryLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get superAdminInventoryLowStock;

  /// No description provided for @superAdminInventoryAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get superAdminInventoryAvailable;

  /// No description provided for @superAdminSubscriptionFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get superAdminSubscriptionFree;

  /// No description provided for @superAdminSubscriptionPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get superAdminSubscriptionPremium;

  /// No description provided for @superAdminSubscriptionEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get superAdminSubscriptionEnterprise;

  /// No description provided for @nurseNavPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get nurseNavPatients;

  /// No description provided for @nurseNavTriageQueue.
  ///
  /// In en, this message translates to:
  /// **'Triage queue'**
  String get nurseNavTriageQueue;

  /// No description provided for @nurseNavVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get nurseNavVitals;

  /// No description provided for @nurseNavNursingNotes.
  ///
  /// In en, this message translates to:
  /// **'Nursing notes'**
  String get nurseNavNursingNotes;

  /// No description provided for @nurseNavMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get nurseNavMedications;

  /// No description provided for @nurseNavLabs.
  ///
  /// In en, this message translates to:
  /// **'Labs'**
  String get nurseNavLabs;

  /// No description provided for @nurseNavAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get nurseNavAlerts;

  /// No description provided for @nurseNavProfileHr.
  ///
  /// In en, this message translates to:
  /// **'Profile & HR'**
  String get nurseNavProfileHr;

  /// No description provided for @nurseStationTitle.
  ///
  /// In en, this message translates to:
  /// **'Nurse Station'**
  String get nurseStationTitle;

  /// No description provided for @nurseActivePatient.
  ///
  /// In en, this message translates to:
  /// **'Active: {patientLabel}'**
  String nurseActivePatient(String patientLabel);

  /// No description provided for @adminNavDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminNavDashboard;

  /// No description provided for @adminNavDoctorAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Doctor analytics'**
  String get adminNavDoctorAnalytics;

  /// No description provided for @adminNavStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get adminNavStaff;

  /// No description provided for @adminNavPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get adminNavPatients;

  /// No description provided for @adminNavAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get adminNavAppointments;

  /// No description provided for @adminNavLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get adminNavLeave;

  /// No description provided for @adminNavMedicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical records'**
  String get adminNavMedicalRecords;

  /// No description provided for @adminNavBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get adminNavBilling;

  /// No description provided for @adminNavPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get adminNavPermissions;

  /// No description provided for @adminNavInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get adminNavInventory;

  /// No description provided for @adminNavAuditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get adminNavAuditLog;

  /// No description provided for @adminNavBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get adminNavBroadcast;

  /// No description provided for @adminNavSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get adminNavSettings;

  /// No description provided for @adminClinicAdmin.
  ///
  /// In en, this message translates to:
  /// **'Clinic Admin'**
  String get adminClinicAdmin;

  /// No description provided for @adminAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get adminAdministrator;

  /// No description provided for @pharmacistNavDashboardOverview.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Overview'**
  String get pharmacistNavDashboardOverview;

  /// No description provided for @pharmacistNavInventoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management'**
  String get pharmacistNavInventoryManagement;

  /// No description provided for @pharmacistNavInventoryLogs.
  ///
  /// In en, this message translates to:
  /// **'Inventory Logs'**
  String get pharmacistNavInventoryLogs;

  /// No description provided for @pharmacistNavDispensingTerminal.
  ///
  /// In en, this message translates to:
  /// **'Dispensing Terminal'**
  String get pharmacistNavDispensingTerminal;

  /// No description provided for @pharmacistNavMedicationRequests.
  ///
  /// In en, this message translates to:
  /// **'Medication Requests'**
  String get pharmacistNavMedicationRequests;

  /// No description provided for @pharmacistNavSystemNotifications.
  ///
  /// In en, this message translates to:
  /// **'System Notifications'**
  String get pharmacistNavSystemNotifications;

  /// No description provided for @pharmacistNavAnalyticReports.
  ///
  /// In en, this message translates to:
  /// **'Analytic Reports'**
  String get pharmacistNavAnalyticReports;

  /// No description provided for @pharmacistNavPharmacySettings.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy Settings'**
  String get pharmacistNavPharmacySettings;

  /// No description provided for @pharmacistNavPharmacistProfile.
  ///
  /// In en, this message translates to:
  /// **'Pharmacist Profile'**
  String get pharmacistNavPharmacistProfile;

  /// No description provided for @pharmacistBrandTitle.
  ///
  /// In en, this message translates to:
  /// **'Rafeeq Pharmacy'**
  String get pharmacistBrandTitle;

  /// No description provided for @pharmacistDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Rafeeq Pharmacy'**
  String get pharmacistDefaultName;

  /// No description provided for @technicianRoleRadiologyTech.
  ///
  /// In en, this message translates to:
  /// **'Radiology Tech'**
  String get technicianRoleRadiologyTech;

  /// No description provided for @technicianRoleLabTechnician.
  ///
  /// In en, this message translates to:
  /// **'Laboratory Technician'**
  String get technicianRoleLabTechnician;

  /// No description provided for @technicianNavOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get technicianNavOverview;

  /// No description provided for @technicianNavIncomingOrders.
  ///
  /// In en, this message translates to:
  /// **'Incoming Orders'**
  String get technicianNavIncomingOrders;

  /// No description provided for @technicianNavIncomingOrdersAr.
  ///
  /// In en, this message translates to:
  /// **'الطلبات الواردة'**
  String get technicianNavIncomingOrdersAr;

  /// No description provided for @technicianImagingWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Imaging Workflow'**
  String get technicianImagingWorkflow;

  /// No description provided for @technicianWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get technicianWelcome;

  /// No description provided for @technicianWelcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String technicianWelcomeName(String name);

  /// No description provided for @technicianRadiologyOverviewHint.
  ///
  /// In en, this message translates to:
  /// **'Review imaging orders under Incoming Orders and upload DICOM, PDF, or image reports.'**
  String get technicianRadiologyOverviewHint;

  /// No description provided for @technicianLabOverviewHint.
  ///
  /// In en, this message translates to:
  /// **'Review doctor lab requests under Incoming Orders and submit finalized reports.'**
  String get technicianLabOverviewHint;

  /// No description provided for @technicianPendingOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pending order} other{{count} pending orders}}'**
  String technicianPendingOrdersCount(int count);

  /// No description provided for @technicianOpenIncomingOrders.
  ///
  /// In en, this message translates to:
  /// **'Open incoming orders'**
  String get technicianOpenIncomingOrders;

  /// No description provided for @technicianRadiologyGreetingHint.
  ///
  /// In en, this message translates to:
  /// **'Incoming imaging orders from the radiology queue.'**
  String get technicianRadiologyGreetingHint;

  /// No description provided for @technicianLabGreetingHint.
  ///
  /// In en, this message translates to:
  /// **'Incoming laboratory orders from the lab queue.'**
  String get technicianLabGreetingHint;

  /// No description provided for @technicianTabIncomingRequests.
  ///
  /// In en, this message translates to:
  /// **'Incoming Requests'**
  String get technicianTabIncomingRequests;

  /// No description provided for @technicianTabCompletedExams.
  ///
  /// In en, this message translates to:
  /// **'Completed Exams'**
  String get technicianTabCompletedExams;

  /// No description provided for @technicianNoPendingImagingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending imaging requests found'**
  String get technicianNoPendingImagingRequests;

  /// No description provided for @technicianNoPendingImagingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor imaging orders (X-Ray, CT, MRI, Ultrasound) for your clinic will appear here.'**
  String get technicianNoPendingImagingSubtitle;

  /// No description provided for @technicianNoCompletedImagingExams.
  ///
  /// In en, this message translates to:
  /// **'No completed imaging exams found'**
  String get technicianNoCompletedImagingExams;

  /// No description provided for @technicianNoCompletedImagingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted imaging reports will appear here for your reference.'**
  String get technicianNoCompletedImagingSubtitle;

  /// No description provided for @technicianNoIncomingOrders.
  ///
  /// In en, this message translates to:
  /// **'No incoming orders'**
  String get technicianNoIncomingOrders;

  /// No description provided for @technicianNoIncomingOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor laboratory requests for your clinic will appear here.'**
  String get technicianNoIncomingOrdersSubtitle;

  /// No description provided for @technicianLabTest.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get technicianLabTest;

  /// No description provided for @technicianImagingStudy.
  ///
  /// In en, this message translates to:
  /// **'Imaging study'**
  String get technicianImagingStudy;

  /// No description provided for @technicianPatientId.
  ///
  /// In en, this message translates to:
  /// **'Patient ID'**
  String get technicianPatientId;

  /// No description provided for @technicianModalityExamType.
  ///
  /// In en, this message translates to:
  /// **'Modality / Exam Type'**
  String get technicianModalityExamType;

  /// No description provided for @technicianBodyPart.
  ///
  /// In en, this message translates to:
  /// **'Body Part'**
  String get technicianBodyPart;

  /// No description provided for @technicianOrderingPhysician.
  ///
  /// In en, this message translates to:
  /// **'Ordering Physician'**
  String get technicianOrderingPhysician;

  /// No description provided for @technicianReasonForExam.
  ///
  /// In en, this message translates to:
  /// **'Reason for Exam'**
  String get technicianReasonForExam;

  /// No description provided for @technicianTestRequested.
  ///
  /// In en, this message translates to:
  /// **'Test requested'**
  String get technicianTestRequested;

  /// No description provided for @technicianOrderedAt.
  ///
  /// In en, this message translates to:
  /// **'Ordered: {dateTime}'**
  String technicianOrderedAt(String dateTime);

  /// No description provided for @technicianCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed: {dateTime}'**
  String technicianCompletedAt(String dateTime);

  /// No description provided for @technicianReportFinalized.
  ///
  /// In en, this message translates to:
  /// **'Report finalized — read-only. No further edits permitted.'**
  String get technicianReportFinalized;

  /// No description provided for @technicianEnterImagingResults.
  ///
  /// In en, this message translates to:
  /// **'Enter Imaging Results'**
  String get technicianEnterImagingResults;

  /// No description provided for @technicianEnterResults.
  ///
  /// In en, this message translates to:
  /// **'Enter Results'**
  String get technicianEnterResults;

  /// No description provided for @technicianResultAnalysisNotes.
  ///
  /// In en, this message translates to:
  /// **'Result analysis / notes'**
  String get technicianResultAnalysisNotes;

  /// No description provided for @technicianEnterDiagnosticFindings.
  ///
  /// In en, this message translates to:
  /// **'Enter diagnostic findings and analysis'**
  String get technicianEnterDiagnosticFindings;

  /// No description provided for @technicianAnalysisNotesRequired.
  ///
  /// In en, this message translates to:
  /// **'Analysis notes are required'**
  String get technicianAnalysisNotesRequired;

  /// No description provided for @technicianAttachDocument.
  ///
  /// In en, this message translates to:
  /// **'Attach document (PDF/Image)'**
  String get technicianAttachDocument;

  /// No description provided for @technicianSubmitImagingReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Imaging Report'**
  String get technicianSubmitImagingReport;

  /// No description provided for @technicianSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get technicianSubmitReport;

  /// No description provided for @technicianAttachImagingBeforeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Attach an imaging file or add technician notes before submitting.'**
  String get technicianAttachImagingBeforeSubmit;

  /// No description provided for @technicianImagingReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Imaging report submitted — record locked and removed from queue.'**
  String get technicianImagingReportSubmitted;

  /// No description provided for @technicianReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted — record locked and removed from queue.'**
  String get technicianReportSubmitted;

  /// No description provided for @technicianStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get technicianStatusPending;

  /// No description provided for @technicianStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get technicianStatusCompleted;

  /// No description provided for @landingMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get landingMenu;

  /// No description provided for @landingLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get landingLogin;

  /// No description provided for @landingSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get landingSignUp;

  /// No description provided for @landingRefreshClinics.
  ///
  /// In en, this message translates to:
  /// **'Refresh clinics'**
  String get landingRefreshClinics;

  /// No description provided for @landingRafeeqClinic.
  ///
  /// In en, this message translates to:
  /// **'Rafeeq Clinic'**
  String get landingRafeeqClinic;

  /// No description provided for @landingRegisterFacility.
  ///
  /// In en, this message translates to:
  /// **'Register your facility'**
  String get landingRegisterFacility;

  /// No description provided for @landingRegisterFacilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clinic / hospital setup — organization + admin account'**
  String get landingRegisterFacilitySubtitle;

  /// No description provided for @landingOurFacilities.
  ///
  /// In en, this message translates to:
  /// **'Our facilities'**
  String get landingOurFacilities;

  /// No description provided for @landingTapFacilityHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a facility to view details.'**
  String get landingTapFacilityHint;

  /// No description provided for @landingNoFacilities.
  ///
  /// In en, this message translates to:
  /// **'No registered facilities found. Be the first to set up your organization!'**
  String get landingNoFacilities;

  /// No description provided for @landingCouldNotLoadFacilities.
  ///
  /// In en, this message translates to:
  /// **'Could not load facilities.'**
  String get landingCouldNotLoadFacilities;

  /// No description provided for @landingContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get landingContactUs;

  /// No description provided for @landingContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'d love to hear from you.\nSend us a message.'**
  String get landingContactSubtitle;

  /// No description provided for @landingContactName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get landingContactName;

  /// No description provided for @landingContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get landingContactEmail;

  /// No description provided for @landingContactMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get landingContactMessage;

  /// No description provided for @landingSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get landingSendMessage;

  /// No description provided for @landingVideoLoadError.
  ///
  /// In en, this message translates to:
  /// **'Video failed to load.\n\n{details}'**
  String landingVideoLoadError(String details);

  /// No description provided for @landingFacilityFallback.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get landingFacilityFallback;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginWelcomeBack;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue caring, together.'**
  String get loginTagline;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @loginRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get loginRememberMe;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginForgotPasswordNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Forgot password is not implemented yet.'**
  String get loginForgotPasswordNotImplemented;

  /// No description provided for @loginSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get loginSigningIn;

  /// No description provided for @loginSignInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Email'**
  String get loginSignInWithEmail;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginOr;

  /// No description provided for @loginSignInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginSignInWithGoogle;

  /// No description provided for @loginSignInWithFacebook.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Facebook'**
  String get loginSignInWithFacebook;

  /// No description provided for @loginDontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginDontHaveAccount;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginSignUp;

  /// No description provided for @loginYourHealth.
  ///
  /// In en, this message translates to:
  /// **'Your health.'**
  String get loginYourHealth;

  /// No description provided for @loginOurCommitment.
  ///
  /// In en, this message translates to:
  /// **'Our commitment.'**
  String get loginOurCommitment;

  /// No description provided for @loginSuperAdminMissingToken.
  ///
  /// In en, this message translates to:
  /// **'Super Admin login missing token.'**
  String get loginSuperAdminMissingToken;

  /// No description provided for @loginRoleMissing.
  ///
  /// In en, this message translates to:
  /// **'Login succeeded but role is missing.'**
  String get loginRoleMissing;

  /// No description provided for @loginUserIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Login succeeded but user id is missing.'**
  String get loginUserIdMissing;

  /// No description provided for @loginOrgIdMissingDoctor.
  ///
  /// In en, this message translates to:
  /// **'Login succeeded but facility orgId is missing. Contact your clinic admin.'**
  String get loginOrgIdMissingDoctor;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get loginInvalidCredentials;

  /// No description provided for @loginConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get loginConnectionFailed;

  /// No description provided for @loginGoogleTokenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get Google ID token. Check Web client ID / OAuth consent.'**
  String get loginGoogleTokenFailed;

  /// No description provided for @loginGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {error}'**
  String loginGoogleSignInFailed(String error);

  /// No description provided for @loginFacebookCancelled.
  ///
  /// In en, this message translates to:
  /// **'Facebook login cancelled or no token.'**
  String get loginFacebookCancelled;

  /// No description provided for @loginFacebookSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Facebook sign-in failed: {error}'**
  String loginFacebookSignInFailed(String error);

  /// No description provided for @loginFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {message}'**
  String loginFailedMessage(String message);

  /// No description provided for @loginClinicUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Clinic under review'**
  String get loginClinicUnderReview;

  /// No description provided for @loginClinicUnderReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Your clinic is under review. Please wait for Super Admin activation.'**
  String get loginClinicUnderReviewMessage;

  /// No description provided for @loginOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get loginOk;

  /// No description provided for @loginFacilityPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Your facility registration request is still pending approval from the Super Admin.'**
  String get loginFacilityPendingApproval;

  /// No description provided for @loginUnknownRole.
  ///
  /// In en, this message translates to:
  /// **'Unknown role: {role}'**
  String loginUnknownRole(String role);

  /// No description provided for @logoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutDialogTitle;

  /// No description provided for @logoutDialogReturnToLanding.
  ///
  /// In en, this message translates to:
  /// **'Return to the public landing page.'**
  String get logoutDialogReturnToLanding;

  /// No description provided for @logoutDialogReturnToLogin.
  ///
  /// In en, this message translates to:
  /// **'You will return to the login screen.'**
  String get logoutDialogReturnToLogin;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logoutDialogReturnToLandingAdmin.
  ///
  /// In en, this message translates to:
  /// **'You will return to the public landing page.'**
  String get logoutDialogReturnToLandingAdmin;

  /// No description provided for @patientEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get patientEmergency;

  /// No description provided for @patientEmergencyHint.
  ///
  /// In en, this message translates to:
  /// **'Use these numbers in an emergency. On phone, \"Call now\" opens your dialer.'**
  String get patientEmergencyHint;

  /// No description provided for @patientEmergencyNational.
  ///
  /// In en, this message translates to:
  /// **'National emergency'**
  String get patientEmergencyNational;

  /// No description provided for @patientEmergencyCivilDefense.
  ///
  /// In en, this message translates to:
  /// **'Civil defense'**
  String get patientEmergencyCivilDefense;

  /// No description provided for @patientEmergencyPolice.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get patientEmergencyPolice;

  /// No description provided for @patientEmergencyClinic24h.
  ///
  /// In en, this message translates to:
  /// **'Rafeeq clinic (24h)'**
  String get patientEmergencyClinic24h;

  /// No description provided for @patientCallNow.
  ///
  /// In en, this message translates to:
  /// **'Call now'**
  String get patientCallNow;

  /// No description provided for @patientDialerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open dialer for {label}'**
  String patientDialerFailed(String label);

  /// No description provided for @patientCallFailed.
  ///
  /// In en, this message translates to:
  /// **'Call failed: {error}'**
  String patientCallFailed(String error);

  /// No description provided for @patientCancelAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment?'**
  String get patientCancelAppointmentTitle;

  /// No description provided for @patientCancelAppointmentBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel your visit on {date} at {time}? The next patient on the waiting list may be promoted automatically.'**
  String patientCancelAppointmentBody(String date, String time);

  /// No description provided for @patientKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get patientKeep;

  /// No description provided for @patientCancelVisit.
  ///
  /// In en, this message translates to:
  /// **'Cancel visit'**
  String get patientCancelVisit;

  /// No description provided for @patientAppointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled.'**
  String get patientAppointmentCancelled;

  /// No description provided for @patientAppointmentCancelledPromoted.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled. Next patient on the waitlist was confirmed.'**
  String get patientAppointmentCancelledPromoted;

  /// No description provided for @patientCancelRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel request?'**
  String get patientCancelRequestTitle;

  /// No description provided for @patientCancelRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Leave the waiting list for {doctor} on {date} at {time}? You can join again later if the slot is still full.'**
  String patientCancelRequestBody(String doctor, String date, String time);

  /// No description provided for @patientStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get patientStay;

  /// No description provided for @patientCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get patientCancelRequest;

  /// No description provided for @patientRemovedFromWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Removed from waiting list.'**
  String get patientRemovedFromWaitlist;

  /// No description provided for @patientMyBookings.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get patientMyBookings;

  /// No description provided for @patientConfirmedBookings.
  ///
  /// In en, this message translates to:
  /// **'Confirmed Bookings'**
  String get patientConfirmedBookings;

  /// No description provided for @patientNoUpcomingVisits.
  ///
  /// In en, this message translates to:
  /// **'No upcoming confirmed visits.'**
  String get patientNoUpcomingVisits;

  /// No description provided for @patientWaitingLists.
  ///
  /// In en, this message translates to:
  /// **'Waiting Lists'**
  String get patientWaitingLists;

  /// No description provided for @patientNotOnWaitingLists.
  ///
  /// In en, this message translates to:
  /// **'You are not on any waiting lists.'**
  String get patientNotOnWaitingLists;

  /// No description provided for @patientConfirmedFromWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Confirmed from Waitlist'**
  String get patientConfirmedFromWaitlist;

  /// No description provided for @patientDoctorApproved.
  ///
  /// In en, this message translates to:
  /// **'Doctor approved'**
  String get patientDoctorApproved;

  /// No description provided for @patientAppointmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get patientAppointmentLabel;

  /// No description provided for @patientCancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel Appointment'**
  String get patientCancelAppointment;

  /// No description provided for @patientOnWaitingListHint.
  ///
  /// In en, this message translates to:
  /// **'On waiting list — you will be notified if a slot opens'**
  String get patientOnWaitingListHint;

  /// No description provided for @patientLeaveWaitingList.
  ///
  /// In en, this message translates to:
  /// **'Leave Waiting List'**
  String get patientLeaveWaitingList;

  /// No description provided for @patientConfirmBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your Appointment Reservation'**
  String get patientConfirmBookingTitle;

  /// No description provided for @patientConfirmBookingBody.
  ///
  /// In en, this message translates to:
  /// **'Book an appointment with Dr. {doctor} on {date} at {time}?'**
  String patientConfirmBookingBody(String doctor, String date, String time);

  /// No description provided for @patientConfirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get patientConfirmBooking;

  /// No description provided for @patientJoinWaitingListTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Waiting List'**
  String get patientJoinWaitingListTitle;

  /// No description provided for @patientJoinWaitingListBody.
  ///
  /// In en, this message translates to:
  /// **'This appointment slot with Dr. {doctor} is currently full. Would you like to join the waiting list? You will receive an immediate notification if this appointment is canceled.'**
  String patientJoinWaitingListBody(String doctor);

  /// No description provided for @patientJoinList.
  ///
  /// In en, this message translates to:
  /// **'Join List'**
  String get patientJoinList;

  /// No description provided for @patientSlotFullWaitlist.
  ///
  /// In en, this message translates to:
  /// **'This slot is full. You have been added to the waiting list.'**
  String get patientSlotFullWaitlist;

  /// No description provided for @patientAppointmentBooked.
  ///
  /// In en, this message translates to:
  /// **'Appointment booked with Dr. {doctor}'**
  String patientAppointmentBooked(String doctor);

  /// No description provided for @patientSelectDoctor.
  ///
  /// In en, this message translates to:
  /// **'Select doctor'**
  String get patientSelectDoctor;

  /// No description provided for @patientChooseDoctor.
  ///
  /// In en, this message translates to:
  /// **'Choose a doctor'**
  String get patientChooseDoctor;

  /// No description provided for @patientLoadingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Loading schedule for {doctor}…'**
  String patientLoadingSchedule(String doctor);

  /// No description provided for @patientNoWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'No working days with bookable slots for {doctor}.'**
  String patientNoWorkingDays(String doctor);

  /// No description provided for @patientDoctorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{doctor} is not available on this day.'**
  String patientDoctorUnavailable(String doctor);

  /// No description provided for @patientNoSlotsOnDay.
  ///
  /// In en, this message translates to:
  /// **'No slots on {day}.\nPick another day above.'**
  String patientNoSlotsOnDay(String day);

  /// No description provided for @patientThisDay.
  ///
  /// In en, this message translates to:
  /// **'this day'**
  String get patientThisDay;

  /// No description provided for @patientAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get patientAvailable;

  /// No description provided for @patientOnWaitlist.
  ///
  /// In en, this message translates to:
  /// **'On waitlist'**
  String get patientOnWaitlist;

  /// No description provided for @patientFullTapToWait.
  ///
  /// In en, this message translates to:
  /// **'Full · tap to wait'**
  String get patientFullTapToWait;

  /// No description provided for @patientBookWithDoctor.
  ///
  /// In en, this message translates to:
  /// **'Book with your doctor'**
  String get patientBookWithDoctor;

  /// No description provided for @patientBookFlowHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a doctor, then a day they see patients, then a time slot.'**
  String get patientBookFlowHint;

  /// No description provided for @patientAvailableDays.
  ///
  /// In en, this message translates to:
  /// **'Available days · {doctor}'**
  String patientAvailableDays(String doctor);

  /// No description provided for @patientTimeSlots.
  ///
  /// In en, this message translates to:
  /// **'Time slots'**
  String get patientTimeSlots;

  /// No description provided for @patientSelectSlotHint.
  ///
  /// In en, this message translates to:
  /// **'Available slots: tap to confirm your reservation. Full slots: tap to join the waiting list for Dr. {doctor}.'**
  String patientSelectSlotHint(String doctor);

  /// No description provided for @patientAlreadyOnWaitlist.
  ///
  /// In en, this message translates to:
  /// **'You cannot join the waiting list for a slot you have already booked or requested.'**
  String get patientAlreadyOnWaitlist;

  /// No description provided for @patientPrescribedMedsMissingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Prescribed medications are missing catalog ids — contact your clinic.'**
  String get patientPrescribedMedsMissingCatalog;

  /// No description provided for @patientOpeningPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Opening pharmacy with {count, plural, =1{1 prescribed medication} other{{count} prescribed medications}}…'**
  String patientOpeningPharmacy(int count);

  /// No description provided for @patientRxItemMissingDrugId.
  ///
  /// In en, this message translates to:
  /// **'This prescription item is missing a catalog drug id.'**
  String get patientRxItemMissingDrugId;

  /// No description provided for @patientPrescriptionIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Prescription record id missing — refresh and try again.'**
  String get patientPrescriptionIdMissing;

  /// No description provided for @patientEPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'E-Prescriptions'**
  String get patientEPrescriptions;

  /// No description provided for @patientNoEPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'No electronic prescriptions yet.\nYour physician will issue Rx here when needed.'**
  String get patientNoEPrescriptions;

  /// No description provided for @patientIssuedExpires.
  ///
  /// In en, this message translates to:
  /// **'Issued {issued} · Expires {expires}'**
  String patientIssuedExpires(String issued, String expires);

  /// No description provided for @patientESignature.
  ///
  /// In en, this message translates to:
  /// **'e-Signature: {signature}'**
  String patientESignature(String signature);

  /// No description provided for @patientRx.
  ///
  /// In en, this message translates to:
  /// **'Rx'**
  String get patientRx;

  /// No description provided for @patientAllowedDispensedPending.
  ///
  /// In en, this message translates to:
  /// **'Allowed: {allowed} · Dispensed: {dispensed} · Pending: {pending}'**
  String patientAllowedDispensedPending(
    String allowed,
    String dispensed,
    String pending,
  );

  /// No description provided for @patientFullyFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Fully fulfilled'**
  String get patientFullyFulfilled;

  /// No description provided for @patientTapToPurchaseRx.
  ///
  /// In en, this message translates to:
  /// **'Tap to purchase with this prescription'**
  String get patientTapToPurchaseRx;

  /// No description provided for @patientOrderViaPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Order via Pharmacy'**
  String get patientOrderViaPharmacy;

  /// No description provided for @patientStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get patientStatusActive;

  /// No description provided for @patientStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get patientStatusCompleted;

  /// No description provided for @patientStartMedicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Start medication?'**
  String get patientStartMedicationTitle;

  /// No description provided for @patientStartMedicationBody.
  ///
  /// In en, this message translates to:
  /// **'Start taking this medication today?'**
  String get patientStartMedicationBody;

  /// No description provided for @patientStartToday.
  ///
  /// In en, this message translates to:
  /// **'Start today'**
  String get patientStartToday;

  /// No description provided for @patientMyPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'My Prescriptions'**
  String get patientMyPrescriptions;

  /// No description provided for @patientNoPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions on file.'**
  String get patientNoPrescriptions;

  /// No description provided for @patientCurrentPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Current prescriptions'**
  String get patientCurrentPrescriptions;

  /// No description provided for @patientCompletedHistory.
  ///
  /// In en, this message translates to:
  /// **'Completed history'**
  String get patientCompletedHistory;

  /// No description provided for @patientExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get patientExpired;

  /// No description provided for @patientCourseNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Course: {days} days (not started)'**
  String patientCourseNotStarted(String days);

  /// No description provided for @patientStartedEnds.
  ///
  /// In en, this message translates to:
  /// **'Started {start} · ends {end}'**
  String patientStartedEnds(String start, String end);

  /// No description provided for @patientCourseLength.
  ///
  /// In en, this message translates to:
  /// **'Course length: {days} days'**
  String patientCourseLength(String days);

  /// No description provided for @patientDoseFrequency.
  ///
  /// In en, this message translates to:
  /// **'Dose: {dose} · {frequency}'**
  String patientDoseFrequency(String dose, String frequency);

  /// No description provided for @patientPrescriber.
  ///
  /// In en, this message translates to:
  /// **'Prescriber: {name}'**
  String patientPrescriber(String name);

  /// No description provided for @patientTapForAiDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap medication name for AI details'**
  String get patientTapForAiDetails;

  /// No description provided for @patientReportSideEffect.
  ///
  /// In en, this message translates to:
  /// **'Report Side Effect / بلغ عن مشكلة مع الدواء'**
  String get patientReportSideEffect;

  /// No description provided for @patientUnknownMedication.
  ///
  /// In en, this message translates to:
  /// **'Unknown medication'**
  String get patientUnknownMedication;

  /// No description provided for @patientSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get patientSearchFailed;

  /// No description provided for @patientCatalogIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Medication catalog id missing — refresh search.'**
  String get patientCatalogIdMissing;

  /// No description provided for @patientGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get patientGo;

  /// No description provided for @patientPrescriptionRequiredPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Prescription required — use Order via Pharmacy from your E-Prescriptions.'**
  String get patientPrescriptionRequiredPharmacy;

  /// No description provided for @patientSearchClinicStock.
  ///
  /// In en, this message translates to:
  /// **'Search clinic stock'**
  String get patientSearchClinicStock;

  /// No description provided for @patientClinicPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Clinic pharmacy'**
  String get patientClinicPharmacy;

  /// No description provided for @patientInStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get patientInStock;

  /// No description provided for @patientOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get patientOutOfStock;

  /// No description provided for @patientRxAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Rx ✓'**
  String get patientRxAuthorized;

  /// No description provided for @patientPrescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Prescription Required'**
  String get patientPrescriptionRequired;

  /// No description provided for @patientBuyRx.
  ///
  /// In en, this message translates to:
  /// **'Buy (Rx)'**
  String get patientBuyRx;

  /// No description provided for @patientBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get patientBuy;

  /// No description provided for @patientNearbyPharmacies.
  ///
  /// In en, this message translates to:
  /// **'Nearby pharmacies (if unavailable)'**
  String get patientNearbyPharmacies;

  /// No description provided for @patientDigitalHealthProfile.
  ///
  /// In en, this message translates to:
  /// **'Digital health profile'**
  String get patientDigitalHealthProfile;

  /// No description provided for @patientOfficialMedicalReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Official medical reference — read only'**
  String get patientOfficialMedicalReadOnly;

  /// No description provided for @patientDoctorChat.
  ///
  /// In en, this message translates to:
  /// **'Doctor chat'**
  String get patientDoctorChat;

  /// No description provided for @patientClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get patientClinic;

  /// No description provided for @patientSelectClinicDoctor.
  ///
  /// In en, this message translates to:
  /// **'Select a clinic with an assigned doctor to start chatting.'**
  String get patientSelectClinicDoctor;

  /// No description provided for @patientSelectDoctorChat.
  ///
  /// In en, this message translates to:
  /// **'Select a doctor to view messages.'**
  String get patientSelectDoctorChat;

  /// No description provided for @patientNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Send a message to start the conversation.'**
  String get patientNoMessagesYet;

  /// No description provided for @patientMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get patientMessageHint;

  /// No description provided for @patientSessionRequired.
  ///
  /// In en, this message translates to:
  /// **'This feature requires an active clinic session. You can still view your past reports below.'**
  String get patientSessionRequired;

  /// No description provided for @patientMoreMyMedications.
  ///
  /// In en, this message translates to:
  /// **'My medications'**
  String get patientMoreMyMedications;

  /// No description provided for @patientMoreControlledRx.
  ///
  /// In en, this message translates to:
  /// **'Controlled Rx'**
  String get patientMoreControlledRx;

  /// No description provided for @patientMorePharmacyRequests.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy requests'**
  String get patientMorePharmacyRequests;

  /// No description provided for @patientMoreLabResults.
  ///
  /// In en, this message translates to:
  /// **'Lab results'**
  String get patientMoreLabResults;

  /// No description provided for @patientLabDiagnosticResults.
  ///
  /// In en, this message translates to:
  /// **'Lab & diagnostic results'**
  String get patientLabDiagnosticResults;

  /// No description provided for @patientNoCompletedResults.
  ///
  /// In en, this message translates to:
  /// **'No completed results yet'**
  String get patientNoCompletedResults;

  /// No description provided for @patientDiagnosticTest.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic test'**
  String get patientDiagnosticTest;

  /// No description provided for @patientRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get patientRadiology;

  /// No description provided for @patientLaboratory.
  ///
  /// In en, this message translates to:
  /// **'Laboratory'**
  String get patientLaboratory;

  /// No description provided for @patientPatientId.
  ///
  /// In en, this message translates to:
  /// **'Patient ID'**
  String get patientPatientId;

  /// No description provided for @patientFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get patientFullName;

  /// No description provided for @patientAgeGender.
  ///
  /// In en, this message translates to:
  /// **'Age / Gender'**
  String get patientAgeGender;

  /// No description provided for @patientClinicLabel.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get patientClinicLabel;

  /// No description provided for @patientDoctorLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get patientDoctorLabel;

  /// No description provided for @patientDownloadViewFile.
  ///
  /// In en, this message translates to:
  /// **'Download / view file'**
  String get patientDownloadViewFile;

  /// No description provided for @patientNoAnalysisProvided.
  ///
  /// In en, this message translates to:
  /// **'No analysis provided'**
  String get patientNoAnalysisProvided;

  /// No description provided for @patientExamDate.
  ///
  /// In en, this message translates to:
  /// **'Exam date'**
  String get patientExamDate;

  /// No description provided for @patientExamType.
  ///
  /// In en, this message translates to:
  /// **'Exam type'**
  String get patientExamType;

  /// No description provided for @patientBodyPart.
  ///
  /// In en, this message translates to:
  /// **'Body part'**
  String get patientBodyPart;

  /// No description provided for @patientPartnerMedicalCenter.
  ///
  /// In en, this message translates to:
  /// **'Partner Medical Center'**
  String get patientPartnerMedicalCenter;

  /// No description provided for @patientRateYourVisit.
  ///
  /// In en, this message translates to:
  /// **'Rate your visit'**
  String get patientRateYourVisit;

  /// No description provided for @patientReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get patientReminders;

  /// No description provided for @patientMedicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get patientMedicineName;

  /// No description provided for @patientDoseTimes.
  ///
  /// In en, this message translates to:
  /// **'Dose times (comma)'**
  String get patientDoseTimes;

  /// No description provided for @patientAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get patientAdd;

  /// No description provided for @patientMarkTaken.
  ///
  /// In en, this message translates to:
  /// **'Mark taken'**
  String get patientMarkTaken;

  /// No description provided for @patientRemindersWebHint.
  ///
  /// In en, this message translates to:
  /// **'Web: reminders stay in-app; use Android/iOS for scheduled push alerts.'**
  String get patientRemindersWebHint;

  /// No description provided for @patientRemindersDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Daily dose alerts are scheduled on this device from your list. Grant notification permission if prompted.'**
  String get patientRemindersDeviceHint;

  /// No description provided for @patientYourAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Your analytics'**
  String get patientYourAnalytics;

  /// No description provided for @patientVisitCount.
  ///
  /// In en, this message translates to:
  /// **'Visit count'**
  String get patientVisitCount;

  /// No description provided for @patientActiveMedicationReminders.
  ///
  /// In en, this message translates to:
  /// **'Active medication reminders'**
  String get patientActiveMedicationReminders;

  /// No description provided for @patientTotalPaymentsSar.
  ///
  /// In en, this message translates to:
  /// **'Total payments (ILS)'**
  String get patientTotalPaymentsSar;

  /// No description provided for @patientLastCheckupLabel.
  ///
  /// In en, this message translates to:
  /// **'Last checkup label'**
  String get patientLastCheckupLabel;

  /// No description provided for @patientGoNearestMedicalCenter.
  ///
  /// In en, this message translates to:
  /// **'Go to the nearest medical center'**
  String get patientGoNearestMedicalCenter;

  /// No description provided for @patientErAlertFromDoctor.
  ///
  /// In en, this message translates to:
  /// **'تنبيه طوارئ من الطبيب'**
  String get patientErAlertFromDoctor;

  /// No description provided for @patientPharmacyActivity.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy Activity'**
  String get patientPharmacyActivity;

  /// No description provided for @patientPharmacyActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'طلبات الأدوية والمشتريات'**
  String get patientPharmacyActivitySubtitle;

  /// No description provided for @patientMyRequests.
  ///
  /// In en, this message translates to:
  /// **'My Requests'**
  String get patientMyRequests;

  /// No description provided for @patientPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get patientPurchased;

  /// No description provided for @patientNoMedicationRequests.
  ///
  /// In en, this message translates to:
  /// **'No medication requests yet.'**
  String get patientNoMedicationRequests;

  /// No description provided for @patientNoPurchases.
  ///
  /// In en, this message translates to:
  /// **'No purchases recorded yet.'**
  String get patientNoPurchases;

  /// No description provided for @patientPaidConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Paid · Confirmed'**
  String get patientPaidConfirmed;

  /// No description provided for @patientPartiallyFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Partially Fulfilled'**
  String get patientPartiallyFulfilled;

  /// No description provided for @patientPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get patientPaymentFailed;

  /// No description provided for @patientPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get patientPending;

  /// No description provided for @patientRequestedQty.
  ///
  /// In en, this message translates to:
  /// **'Requested: {qty}'**
  String patientRequestedQty(String qty);

  /// No description provided for @patientFulfilledUnits.
  ///
  /// In en, this message translates to:
  /// **'Fulfilled: {qty} units'**
  String patientFulfilledUnits(int qty);

  /// No description provided for @patientBackorderUnits.
  ///
  /// In en, this message translates to:
  /// **'Backorder: {qty} units'**
  String patientBackorderUnits(int qty);

  /// No description provided for @patientUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated: {dateTime}'**
  String patientUpdatedAt(String dateTime);

  /// No description provided for @patientNotifyWhenInStock.
  ///
  /// In en, this message translates to:
  /// **'Notify when in stock'**
  String get patientNotifyWhenInStock;

  /// No description provided for @patientFindRemainingNearby.
  ///
  /// In en, this message translates to:
  /// **'Find Remaining in Nearby Pharmacies'**
  String get patientFindRemainingNearby;

  /// No description provided for @patientClinicInternalPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Clinic Internal Pharmacy'**
  String get patientClinicInternalPharmacy;

  /// No description provided for @patientExternalCommunityPharmacy.
  ///
  /// In en, this message translates to:
  /// **'External Community Pharmacy'**
  String get patientExternalCommunityPharmacy;

  /// No description provided for @patientQty.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String patientQty(String qty);

  /// No description provided for @patientPrescribingPhysician.
  ///
  /// In en, this message translates to:
  /// **'Prescribing physician: {doctor}'**
  String patientPrescribingPhysician(String doctor);

  /// No description provided for @patientMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get patientMedication;

  /// No description provided for @patientBookingFailed.
  ///
  /// In en, this message translates to:
  /// **'Booking failed'**
  String get patientBookingFailed;

  /// No description provided for @patientRescheduleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Appointment updated successfully'**
  String get patientRescheduleSuccess;

  /// No description provided for @patientBookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get patientBookAppointment;

  /// No description provided for @patientSelectNewAppointment.
  ///
  /// In en, this message translates to:
  /// **'Select new appointment'**
  String get patientSelectNewAppointment;

  /// No description provided for @patientClinicSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Clinic / specialty'**
  String get patientClinicSpecialty;

  /// No description provided for @patientSelectSpecialtyFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a specialty first.'**
  String get patientSelectSpecialtyFirst;

  /// No description provided for @patientNoDoctorsForSpecialty.
  ///
  /// In en, this message translates to:
  /// **'No doctors for this specialty.'**
  String get patientNoDoctorsForSpecialty;

  /// No description provided for @patientChooseDoctorTime.
  ///
  /// In en, this message translates to:
  /// **'Choose doctor & time'**
  String get patientChooseDoctorTime;

  /// No description provided for @patientBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get patientBook;

  /// No description provided for @patientConfirmAppointment.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get patientConfirmAppointment;

  /// No description provided for @patientDoctorOnLeave.
  ///
  /// In en, this message translates to:
  /// **'Doctor on leave'**
  String get patientDoctorOnLeave;

  /// No description provided for @patientNoOpenSlots.
  ///
  /// In en, this message translates to:
  /// **'No open slots on this date'**
  String get patientNoOpenSlots;

  /// No description provided for @patientSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select a time'**
  String get patientSelectTime;

  /// No description provided for @patientAppointmentBookedShort.
  ///
  /// In en, this message translates to:
  /// **'Appointment booked'**
  String get patientAppointmentBookedShort;

  /// No description provided for @patientSlotFullWaitlistShort.
  ///
  /// In en, this message translates to:
  /// **'Slot full — you have been added to the waiting list'**
  String get patientSlotFullWaitlistShort;

  /// No description provided for @patientYearsShort.
  ///
  /// In en, this message translates to:
  /// **'{age} yrs'**
  String patientYearsShort(String age);

  /// No description provided for @patientEmDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get patientEmDash;

  /// No description provided for @nurseSelectPatientHint.
  ///
  /// In en, this message translates to:
  /// **'Select a patient from the Patients or Triage tab.'**
  String get nurseSelectPatientHint;

  /// No description provided for @nurseClinicalSummary.
  ///
  /// In en, this message translates to:
  /// **'Clinical summary'**
  String get nurseClinicalSummary;

  /// No description provided for @nurseReadOnlyEssentials.
  ///
  /// In en, this message translates to:
  /// **'Read-only · medical essentials'**
  String get nurseReadOnlyEssentials;

  /// No description provided for @nurseClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get nurseClose;

  /// No description provided for @nurseNoneRecorded.
  ///
  /// In en, this message translates to:
  /// **'None recorded'**
  String get nurseNoneRecorded;

  /// No description provided for @nurseAgeDob.
  ///
  /// In en, this message translates to:
  /// **'Age / date of birth'**
  String get nurseAgeDob;

  /// No description provided for @nurseGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get nurseGender;

  /// No description provided for @nurseBloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood type'**
  String get nurseBloodType;

  /// No description provided for @nurseChronicConditions.
  ///
  /// In en, this message translates to:
  /// **'Chronic conditions'**
  String get nurseChronicConditions;

  /// No description provided for @nurseActiveAllergies.
  ///
  /// In en, this message translates to:
  /// **'Active allergies'**
  String get nurseActiveAllergies;

  /// No description provided for @nursePrivacyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Contact details, government IDs, addresses, and financial records are not shown in this view.'**
  String get nursePrivacyDisclaimer;

  /// No description provided for @nursePatientRegistry.
  ///
  /// In en, this message translates to:
  /// **'Patient registry'**
  String get nursePatientRegistry;

  /// No description provided for @nurseSearchPatientHint.
  ///
  /// In en, this message translates to:
  /// **'Search by patient name to view a read-only clinical summary.'**
  String get nurseSearchPatientHint;

  /// No description provided for @nurseSearchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by patient name'**
  String get nurseSearchByName;

  /// No description provided for @nurseSearchPatients.
  ///
  /// In en, this message translates to:
  /// **'Search patients'**
  String get nurseSearchPatients;

  /// No description provided for @nurseNoPatientsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No patients loaded yet. Enter a name and tap Search.'**
  String get nurseNoPatientsLoaded;

  /// No description provided for @nursePatientFallback.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get nursePatientFallback;

  /// No description provided for @nurseTapClinicalSummary.
  ///
  /// In en, this message translates to:
  /// **'Tap to view clinical summary'**
  String get nurseTapClinicalSummary;

  /// No description provided for @nurseDailyTriageDesk.
  ///
  /// In en, this message translates to:
  /// **'Daily triage desk'**
  String get nurseDailyTriageDesk;

  /// No description provided for @nurseTriageAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Appointment triage is not enabled for your account. Use Patient registry or contact your supervisor for access.'**
  String get nurseTriageAccessDenied;

  /// No description provided for @nurseSymptomsForVisit.
  ///
  /// In en, this message translates to:
  /// **'Symptoms (for selected visit)'**
  String get nurseSymptomsForVisit;

  /// No description provided for @nurseLoadTodaysQueue.
  ///
  /// In en, this message translates to:
  /// **'Load today\'s queue'**
  String get nurseLoadTodaysQueue;

  /// No description provided for @nurseRefreshQueue.
  ///
  /// In en, this message translates to:
  /// **'Refresh queue'**
  String get nurseRefreshQueue;

  /// No description provided for @nurseCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get nurseCheckIn;

  /// No description provided for @nurseForwardToDoctor.
  ///
  /// In en, this message translates to:
  /// **'Forward to doctor'**
  String get nurseForwardToDoctor;

  /// No description provided for @nurseForwardedToDoctor.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to doctor'**
  String get nurseForwardedToDoctor;

  /// No description provided for @nurseVitalsRecording.
  ///
  /// In en, this message translates to:
  /// **'Vitals recording'**
  String get nurseVitalsRecording;

  /// No description provided for @nurseSelectPatientFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a patient first'**
  String get nurseSelectPatientFirst;

  /// No description provided for @nurseVitalsSaved.
  ///
  /// In en, this message translates to:
  /// **'Vitals saved to patient record'**
  String get nurseVitalsSaved;

  /// No description provided for @nurseBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get nurseBloodPressure;

  /// No description provided for @nurseTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature °C'**
  String get nurseTemperature;

  /// No description provided for @nurseWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight kg'**
  String get nurseWeightKg;

  /// No description provided for @nurseHeightCm.
  ///
  /// In en, this message translates to:
  /// **'Height cm'**
  String get nurseHeightCm;

  /// No description provided for @nursePulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get nursePulse;

  /// No description provided for @nurseOxygen.
  ///
  /// In en, this message translates to:
  /// **'Oxygen %'**
  String get nurseOxygen;

  /// No description provided for @nurseBloodSugar.
  ///
  /// In en, this message translates to:
  /// **'Blood sugar'**
  String get nurseBloodSugar;

  /// No description provided for @nurseSaveVitals.
  ///
  /// In en, this message translates to:
  /// **'Save vitals'**
  String get nurseSaveVitals;

  /// No description provided for @nurseTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get nurseTimeline;

  /// No description provided for @nurseClinicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Clinical nursing notes'**
  String get nurseClinicalNotes;

  /// No description provided for @nurseNoteType.
  ///
  /// In en, this message translates to:
  /// **'Note type'**
  String get nurseNoteType;

  /// No description provided for @nurseNoteObservation.
  ///
  /// In en, this message translates to:
  /// **'Observation'**
  String get nurseNoteObservation;

  /// No description provided for @nurseNoteShiftLog.
  ///
  /// In en, this message translates to:
  /// **'Shift log'**
  String get nurseNoteShiftLog;

  /// No description provided for @nurseNoteDoctorAlert.
  ///
  /// In en, this message translates to:
  /// **'Doctor alert'**
  String get nurseNoteDoctorAlert;

  /// No description provided for @nurseNoteInitialSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Initial symptoms'**
  String get nurseNoteInitialSymptoms;

  /// No description provided for @nurseUrgentForDoctor.
  ///
  /// In en, this message translates to:
  /// **'Urgent for doctor'**
  String get nurseUrgentForDoctor;

  /// No description provided for @nurseNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get nurseNote;

  /// No description provided for @nurseSaveNote.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get nurseSaveNote;

  /// No description provided for @nurseNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved — visible to treating physician'**
  String get nurseNoteSaved;

  /// No description provided for @nurseMedicationTreatment.
  ///
  /// In en, this message translates to:
  /// **'Medication & treatment'**
  String get nurseMedicationTreatment;

  /// No description provided for @nurseMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get nurseMedication;

  /// No description provided for @nurseDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get nurseDosage;

  /// No description provided for @nurseAdverseReaction.
  ///
  /// In en, this message translates to:
  /// **'Adverse reaction (if any)'**
  String get nurseAdverseReaction;

  /// No description provided for @nurseLogAdministration.
  ///
  /// In en, this message translates to:
  /// **'Log administration'**
  String get nurseLogAdministration;

  /// No description provided for @nurseDoseLogged.
  ///
  /// In en, this message translates to:
  /// **'Dose logged'**
  String get nurseDoseLogged;

  /// No description provided for @nurseIncomingLabOrders.
  ///
  /// In en, this message translates to:
  /// **'Incoming lab orders'**
  String get nurseIncomingLabOrders;

  /// No description provided for @nurseLabOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'Doctor requests from the labrequests queue — enter results to finalize.'**
  String get nurseLabOrdersHint;

  /// No description provided for @nurseLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Load orders'**
  String get nurseLoadOrders;

  /// No description provided for @nurseRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get nurseRefresh;

  /// No description provided for @nursePendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String nursePendingCount(int count);

  /// No description provided for @nurseNoIncomingLabOrders.
  ///
  /// In en, this message translates to:
  /// **'No incoming lab orders with status Requested.'**
  String get nurseNoIncomingLabOrders;

  /// No description provided for @nursePatientId.
  ///
  /// In en, this message translates to:
  /// **'Patient ID: {id}'**
  String nursePatientId(String id);

  /// No description provided for @nurseTestLabel.
  ///
  /// In en, this message translates to:
  /// **'Test: {name} ({type})'**
  String nurseTestLabel(String name, String type);

  /// No description provided for @nurseEnterResults.
  ///
  /// In en, this message translates to:
  /// **'Enter Results'**
  String get nurseEnterResults;

  /// No description provided for @nurseResultEntry.
  ///
  /// In en, this message translates to:
  /// **'{type} result entry'**
  String nurseResultEntry(String type);

  /// No description provided for @nurseSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get nurseSubmitReport;

  /// No description provided for @nurseCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get nurseCancel;

  /// No description provided for @nurseEnterResultBeforeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one result value before submitting.'**
  String get nurseEnterResultBeforeSubmit;

  /// No description provided for @nurseReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted — order completed and locked.'**
  String get nurseReportSubmitted;

  /// No description provided for @nursePrintsAlerts.
  ///
  /// In en, this message translates to:
  /// **'Prints & alert dispatches'**
  String get nursePrintsAlerts;

  /// No description provided for @nurseAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert title'**
  String get nurseAlertTitle;

  /// No description provided for @nurseMessageBody.
  ///
  /// In en, this message translates to:
  /// **'Message body'**
  String get nurseMessageBody;

  /// No description provided for @nurseSendNotification.
  ///
  /// In en, this message translates to:
  /// **'Send patient notification'**
  String get nurseSendNotification;

  /// No description provided for @nurseAlertDispatched.
  ///
  /// In en, this message translates to:
  /// **'Alert dispatched to patient'**
  String get nurseAlertDispatched;

  /// No description provided for @nursePrintShiftReference.
  ///
  /// In en, this message translates to:
  /// **'Print shift reference'**
  String get nursePrintShiftReference;

  /// No description provided for @nursePrintBrowserHint.
  ///
  /// In en, this message translates to:
  /// **'Use browser print (Ctrl+P) for shift log printout'**
  String get nursePrintBrowserHint;

  /// No description provided for @nurseProfileHr.
  ///
  /// In en, this message translates to:
  /// **'Profile & HR contract'**
  String get nurseProfileHr;

  /// No description provided for @nurseProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Update your personal credentials below. Administrative contract terms are assigned by your clinic administrator.'**
  String get nurseProfileHint;

  /// No description provided for @nurseAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get nurseAccountSettings;

  /// No description provided for @nurseFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get nurseFullName;

  /// No description provided for @nurseEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get nurseEmail;

  /// No description provided for @nursePhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get nursePhoneNumber;

  /// No description provided for @nurseChangePasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'Change password (optional)'**
  String get nurseChangePasswordOptional;

  /// No description provided for @nurseCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get nurseCurrentPassword;

  /// No description provided for @nurseNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get nurseNewPassword;

  /// No description provided for @nurseSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get nurseSaving;

  /// No description provided for @nurseSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get nurseSaveChanges;

  /// No description provided for @nursePasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 6 characters'**
  String get nursePasswordMinLength;

  /// No description provided for @nurseCurrentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password to set a new one'**
  String get nurseCurrentPasswordRequired;

  /// No description provided for @nurseAccountSaved.
  ///
  /// In en, this message translates to:
  /// **'Account settings saved'**
  String get nurseAccountSaved;

  /// No description provided for @nurseAdminContract.
  ///
  /// In en, this message translates to:
  /// **'Administrative contract'**
  String get nurseAdminContract;

  /// No description provided for @nurseReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get nurseReadOnly;

  /// No description provided for @nurseContractReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Assigned by clinic admin — cannot be edited here'**
  String get nurseContractReadOnlyHint;

  /// No description provided for @nurseAssignedDepartment.
  ///
  /// In en, this message translates to:
  /// **'ASSIGNED DEPARTMENT'**
  String get nurseAssignedDepartment;

  /// No description provided for @nurseShiftTimings.
  ///
  /// In en, this message translates to:
  /// **'SHIFT TIMINGS'**
  String get nurseShiftTimings;

  /// No description provided for @nurseWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'WORKING DAYS'**
  String get nurseWorkingDays;

  /// No description provided for @nurseMonthlySalary.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY SALARY'**
  String get nurseMonthlySalary;

  /// No description provided for @nurseNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get nurseNotAssigned;

  /// No description provided for @nursePendingAdminAssignment.
  ///
  /// In en, this message translates to:
  /// **'Pending admin assignment'**
  String get nursePendingAdminAssignment;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard & quick stats'**
  String get adminDashboardTitle;

  /// No description provided for @adminRevenueToday.
  ///
  /// In en, this message translates to:
  /// **'Revenue today'**
  String get adminRevenueToday;

  /// No description provided for @adminAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get adminAppointments;

  /// No description provided for @adminPendingBills.
  ///
  /// In en, this message translates to:
  /// **'Pending bills'**
  String get adminPendingBills;

  /// No description provided for @adminStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get adminStaff;

  /// No description provided for @adminPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get adminPatients;

  /// No description provided for @adminTopDoctor.
  ///
  /// In en, this message translates to:
  /// **'Top doctor'**
  String get adminTopDoctor;

  /// No description provided for @adminLeaveQueue.
  ///
  /// In en, this message translates to:
  /// **'Leave queue: {count}'**
  String adminLeaveQueue(int count);

  /// No description provided for @adminRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get adminRefresh;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get adminReview;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminClose;

  /// No description provided for @adminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminSave;

  /// No description provided for @adminProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get adminProcessing;

  /// No description provided for @adminDoctorAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor cancellation analytics'**
  String get adminDoctorAnalyticsTitle;

  /// No description provided for @adminRollingWeek.
  ///
  /// In en, this message translates to:
  /// **'Rolling week: {start} → {end}'**
  String adminRollingWeek(String start, String end);

  /// No description provided for @adminDoctorName.
  ///
  /// In en, this message translates to:
  /// **'Doctor Name'**
  String get adminDoctorName;

  /// No description provided for @adminTotalAppointments.
  ///
  /// In en, this message translates to:
  /// **'Total Appointments'**
  String get adminTotalAppointments;

  /// No description provided for @adminCancellations.
  ///
  /// In en, this message translates to:
  /// **'Cancellations'**
  String get adminCancellations;

  /// No description provided for @adminCancellationRate.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Rate (%)'**
  String get adminCancellationRate;

  /// No description provided for @adminTopReason.
  ///
  /// In en, this message translates to:
  /// **'Top Reason'**
  String get adminTopReason;

  /// No description provided for @adminAlertLevel.
  ///
  /// In en, this message translates to:
  /// **'Alert Level'**
  String get adminAlertLevel;

  /// No description provided for @adminAlertCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical review'**
  String get adminAlertCritical;

  /// No description provided for @adminAlertAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin alert'**
  String get adminAlertAdmin;

  /// No description provided for @adminAlertWarning.
  ///
  /// In en, this message translates to:
  /// **'Low warning'**
  String get adminAlertWarning;

  /// No description provided for @adminAlertNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get adminAlertNormal;

  /// No description provided for @adminActionRequired.
  ///
  /// In en, this message translates to:
  /// **'Action required: urgent review recommended; booking restrictions may apply.'**
  String get adminActionRequired;

  /// No description provided for @adminLegendNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal < 15%'**
  String get adminLegendNormal;

  /// No description provided for @adminLegendWarning.
  ///
  /// In en, this message translates to:
  /// **'Low warning 15–20%'**
  String get adminLegendWarning;

  /// No description provided for @adminLegendAlert.
  ///
  /// In en, this message translates to:
  /// **'Admin alert > 20%'**
  String get adminLegendAlert;

  /// No description provided for @adminLegendCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical > 30%'**
  String get adminLegendCritical;

  /// No description provided for @adminDepartmentsWizard.
  ///
  /// In en, this message translates to:
  /// **'Departments wizard'**
  String get adminDepartmentsWizard;

  /// No description provided for @adminCreateDepartment.
  ///
  /// In en, this message translates to:
  /// **'Create department'**
  String get adminCreateDepartment;

  /// No description provided for @adminDepartmentName.
  ///
  /// In en, this message translates to:
  /// **'Department name (e.g. Bones, Pediatrics)'**
  String get adminDepartmentName;

  /// No description provided for @adminSearchDoctors.
  ///
  /// In en, this message translates to:
  /// **'Search doctors'**
  String get adminSearchDoctors;

  /// No description provided for @adminSupervisorDoctor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor doctor'**
  String get adminSupervisorDoctor;

  /// No description provided for @adminNoneOption.
  ///
  /// In en, this message translates to:
  /// **'— None —'**
  String get adminNoneOption;

  /// No description provided for @adminCreateDepartmentBtn.
  ///
  /// In en, this message translates to:
  /// **'Create department'**
  String get adminCreateDepartmentBtn;

  /// No description provided for @adminDepartmentCreated.
  ///
  /// In en, this message translates to:
  /// **'Department created'**
  String get adminDepartmentCreated;

  /// No description provided for @adminAddClinic.
  ///
  /// In en, this message translates to:
  /// **'Add clinic inside department'**
  String get adminAddClinic;

  /// No description provided for @adminSelectDepartment.
  ///
  /// In en, this message translates to:
  /// **'Select department'**
  String get adminSelectDepartment;

  /// No description provided for @adminClinicName.
  ///
  /// In en, this message translates to:
  /// **'Clinic name'**
  String get adminClinicName;

  /// No description provided for @adminPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get adminPhone;

  /// No description provided for @adminRoomNumber.
  ///
  /// In en, this message translates to:
  /// **'Room number (optional)'**
  String get adminRoomNumber;

  /// No description provided for @adminAddClinicBtn.
  ///
  /// In en, this message translates to:
  /// **'Add clinic to department'**
  String get adminAddClinicBtn;

  /// No description provided for @adminClinicAdded.
  ///
  /// In en, this message translates to:
  /// **'Clinic added to department'**
  String get adminClinicAdded;

  /// No description provided for @adminRegisteredDepartments.
  ///
  /// In en, this message translates to:
  /// **'Registered departments'**
  String get adminRegisteredDepartments;

  /// No description provided for @adminNoDepartments.
  ///
  /// In en, this message translates to:
  /// **'No departments yet. Create one above.'**
  String get adminNoDepartments;

  /// No description provided for @adminNoSupervisor.
  ///
  /// In en, this message translates to:
  /// **'No supervisor assigned'**
  String get adminNoSupervisor;

  /// No description provided for @adminSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor: {name}'**
  String adminSupervisor(String name);

  /// No description provided for @adminClinicsCount.
  ///
  /// In en, this message translates to:
  /// **'Clinics ({count})'**
  String adminClinicsCount(int count);

  /// No description provided for @adminNoClinics.
  ///
  /// In en, this message translates to:
  /// **'No clinics registered yet.'**
  String get adminNoClinics;

  /// No description provided for @adminDepartmentFallback.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get adminDepartmentFallback;

  /// No description provided for @adminClinicFallback.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get adminClinicFallback;

  /// No description provided for @adminRoom.
  ///
  /// In en, this message translates to:
  /// **'Room {room}'**
  String adminRoom(String room);

  /// No description provided for @adminStaffOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Staff & clinical onboarding'**
  String get adminStaffOnboarding;

  /// No description provided for @adminSearchActiveStaff.
  ///
  /// In en, this message translates to:
  /// **'Search active staff'**
  String get adminSearchActiveStaff;

  /// No description provided for @adminPendingRegistrations.
  ///
  /// In en, this message translates to:
  /// **'Pending doctor & staff requests ({count})'**
  String adminPendingRegistrations(int count);

  /// No description provided for @adminNoPendingRegistrations.
  ///
  /// In en, this message translates to:
  /// **'No pending doctor or legacy staff registration requests.'**
  String get adminNoPendingRegistrations;

  /// No description provided for @adminApplicant.
  ///
  /// In en, this message translates to:
  /// **'Applicant'**
  String get adminApplicant;

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminRole;

  /// No description provided for @adminSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get adminSpecialty;

  /// No description provided for @adminApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get adminApplied;

  /// No description provided for @adminRegistrationApproved.
  ///
  /// In en, this message translates to:
  /// **'Registration approved — account activated'**
  String get adminRegistrationApproved;

  /// No description provided for @adminRegistrationRejected.
  ///
  /// In en, this message translates to:
  /// **'Registration rejected'**
  String get adminRegistrationRejected;

  /// No description provided for @adminPendingScheduleChanges.
  ///
  /// In en, this message translates to:
  /// **'Pending doctor schedule changes ({count})'**
  String adminPendingScheduleChanges(int count);

  /// No description provided for @adminNoPendingSchedule.
  ///
  /// In en, this message translates to:
  /// **'No pending working-hours change requests.'**
  String get adminNoPendingSchedule;

  /// No description provided for @adminSchedulePreview.
  ///
  /// In en, this message translates to:
  /// **'Schedule preview'**
  String get adminSchedulePreview;

  /// No description provided for @adminRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get adminRequested;

  /// No description provided for @adminActiveDays.
  ///
  /// In en, this message translates to:
  /// **'{count} active day(s)'**
  String adminActiveDays(int count);

  /// No description provided for @adminScheduleApproved.
  ///
  /// In en, this message translates to:
  /// **'Schedule approved — doctor hours updated'**
  String get adminScheduleApproved;

  /// No description provided for @adminScheduleRejected.
  ///
  /// In en, this message translates to:
  /// **'Schedule change rejected'**
  String get adminScheduleRejected;

  /// No description provided for @adminPendingNurseApps.
  ///
  /// In en, this message translates to:
  /// **'Pending nurse applications ({count})'**
  String adminPendingNurseApps(int count);

  /// No description provided for @adminNoPendingStaff.
  ///
  /// In en, this message translates to:
  /// **'No pending clinical staff registrations.'**
  String get adminNoPendingStaff;

  /// No description provided for @adminLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get adminLicense;

  /// No description provided for @adminActiveStaffRoster.
  ///
  /// In en, this message translates to:
  /// **'Active staff roster'**
  String get adminActiveStaffRoster;

  /// No description provided for @adminNoStaffRecords.
  ///
  /// In en, this message translates to:
  /// **'No staff records.'**
  String get adminNoStaffRecords;

  /// No description provided for @adminName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminName;

  /// No description provided for @adminDepartment.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get adminDepartment;

  /// No description provided for @adminStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminStatus;

  /// No description provided for @adminReviewApplicant.
  ///
  /// In en, this message translates to:
  /// **'Review: {name}'**
  String adminReviewApplicant(String name);

  /// No description provided for @adminApproveActivate.
  ///
  /// In en, this message translates to:
  /// **'Approve & activate'**
  String get adminApproveActivate;

  /// No description provided for @adminStaffApproved.
  ///
  /// In en, this message translates to:
  /// **'Staff approved and account activated'**
  String get adminStaffApproved;

  /// No description provided for @adminPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get adminPersonal;

  /// No description provided for @adminProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get adminProfessional;

  /// No description provided for @adminUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get adminUsername;

  /// No description provided for @adminBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get adminBirthDate;

  /// No description provided for @adminEmployeeId.
  ///
  /// In en, this message translates to:
  /// **'Employee ID'**
  String get adminEmployeeId;

  /// No description provided for @adminExperienceYears.
  ///
  /// In en, this message translates to:
  /// **'{years} years'**
  String adminExperienceYears(int years);

  /// No description provided for @adminEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get adminEducation;

  /// No description provided for @adminUniversity.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get adminUniversity;

  /// No description provided for @adminLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'License #'**
  String get adminLicenseNumber;

  /// No description provided for @adminLicenseExpiry.
  ///
  /// In en, this message translates to:
  /// **'License expiry'**
  String get adminLicenseExpiry;

  /// No description provided for @adminEmployment.
  ///
  /// In en, this message translates to:
  /// **'Employment'**
  String get adminEmployment;

  /// No description provided for @adminAdminAssignment.
  ///
  /// In en, this message translates to:
  /// **'Administrative assignment'**
  String get adminAdminAssignment;

  /// No description provided for @adminMonthlySalary.
  ///
  /// In en, this message translates to:
  /// **'Monthly salary (optional)'**
  String get adminMonthlySalary;

  /// No description provided for @adminWorkingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Working schedule'**
  String get adminWorkingSchedule;

  /// No description provided for @adminShiftStart.
  ///
  /// In en, this message translates to:
  /// **'Start (HH:mm)'**
  String get adminShiftStart;

  /// No description provided for @adminShiftEnd.
  ///
  /// In en, this message translates to:
  /// **'End (HH:mm)'**
  String get adminShiftEnd;

  /// No description provided for @adminPermissionFlags.
  ///
  /// In en, this message translates to:
  /// **'Permission flags'**
  String get adminPermissionFlags;

  /// No description provided for @adminPatientDirectory.
  ///
  /// In en, this message translates to:
  /// **'Patient directory'**
  String get adminPatientDirectory;

  /// No description provided for @adminUnpaidOnly.
  ///
  /// In en, this message translates to:
  /// **'Unpaid balances only'**
  String get adminUnpaidOnly;

  /// No description provided for @adminUnpaidBalance.
  ///
  /// In en, this message translates to:
  /// **'unpaid {amount}'**
  String adminUnpaidBalance(String amount);

  /// No description provided for @adminAppointmentPlanner.
  ///
  /// In en, this message translates to:
  /// **'Appointment planner'**
  String get adminAppointmentPlanner;

  /// No description provided for @adminAttendanceLeave.
  ///
  /// In en, this message translates to:
  /// **'Attendance & leave'**
  String get adminAttendanceLeave;

  /// No description provided for @adminRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason (optional)'**
  String get adminRejectionReason;

  /// No description provided for @adminStaffLeave.
  ///
  /// In en, this message translates to:
  /// **'Staff leave'**
  String get adminStaffLeave;

  /// No description provided for @adminDoctorLeave.
  ///
  /// In en, this message translates to:
  /// **'Doctor leave'**
  String get adminDoctorLeave;

  /// No description provided for @adminLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get adminLeave;

  /// No description provided for @adminMedicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical records tracker'**
  String get adminMedicalRecords;

  /// No description provided for @adminRecordFallback.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get adminRecordFallback;

  /// No description provided for @adminInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance: {status}'**
  String adminInsurance(String status);

  /// No description provided for @adminInvoicingBilling.
  ///
  /// In en, this message translates to:
  /// **'Invoicing & billing'**
  String get adminInvoicingBilling;

  /// No description provided for @adminPaidTotal.
  ///
  /// In en, this message translates to:
  /// **'Paid total'**
  String get adminPaidTotal;

  /// No description provided for @adminPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminPending;

  /// No description provided for @adminLateCycles.
  ///
  /// In en, this message translates to:
  /// **'Late cycles'**
  String get adminLateCycles;

  /// No description provided for @adminGranularPermissions.
  ///
  /// In en, this message translates to:
  /// **'Granular access permissions'**
  String get adminGranularPermissions;

  /// No description provided for @adminSaveMatrix.
  ///
  /// In en, this message translates to:
  /// **'Save matrix'**
  String get adminSaveMatrix;

  /// No description provided for @adminPermissionsSaved.
  ///
  /// In en, this message translates to:
  /// **'Permissions saved'**
  String get adminPermissionsSaved;

  /// No description provided for @adminPharmacyLabInventory.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy & lab inventory'**
  String get adminPharmacyLabInventory;

  /// No description provided for @adminDrugSkus.
  ///
  /// In en, this message translates to:
  /// **'Drug SKUs'**
  String get adminDrugSkus;

  /// No description provided for @adminAssaysInProgress.
  ///
  /// In en, this message translates to:
  /// **'Assays in progress'**
  String get adminAssaysInProgress;

  /// No description provided for @adminLowStockAlerts.
  ///
  /// In en, this message translates to:
  /// **'Low stock alerts'**
  String get adminLowStockAlerts;

  /// No description provided for @adminSimulateReplenishment.
  ///
  /// In en, this message translates to:
  /// **'Simulate replenishment (+1 SKU)'**
  String get adminSimulateReplenishment;

  /// No description provided for @adminAuditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit activity log'**
  String get adminAuditLog;

  /// No description provided for @adminGlobalBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Global broadcast'**
  String get adminGlobalBroadcast;

  /// No description provided for @adminAudience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get adminAudience;

  /// No description provided for @adminAudienceAll.
  ///
  /// In en, this message translates to:
  /// **'Staff + patients'**
  String get adminAudienceAll;

  /// No description provided for @adminAudienceStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff only'**
  String get adminAudienceStaff;

  /// No description provided for @adminAudiencePatients.
  ///
  /// In en, this message translates to:
  /// **'Patients only'**
  String get adminAudiencePatients;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminTitle;

  /// No description provided for @adminMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get adminMessage;

  /// No description provided for @adminSendNotification.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get adminSendNotification;

  /// No description provided for @adminBroadcastSent.
  ///
  /// In en, this message translates to:
  /// **'Broadcast sent'**
  String get adminBroadcastSent;

  /// No description provided for @adminSystemConfig.
  ///
  /// In en, this message translates to:
  /// **'System configuration'**
  String get adminSystemConfig;

  /// No description provided for @adminDefaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get adminDefaultCurrency;

  /// No description provided for @adminLocale.
  ///
  /// In en, this message translates to:
  /// **'Locale (en/ar)'**
  String get adminLocale;

  /// No description provided for @adminCancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Cancellation penalty policy'**
  String get adminCancellationPolicy;

  /// No description provided for @adminSaveConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Save configuration'**
  String get adminSaveConfiguration;

  /// No description provided for @adminSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get adminSettingsSaved;

  /// No description provided for @adminRequestBackup.
  ///
  /// In en, this message translates to:
  /// **'Request database backup'**
  String get adminRequestBackup;

  /// No description provided for @adminBackupLogged.
  ///
  /// In en, this message translates to:
  /// **'Backup request logged — implement server export hook as needed.'**
  String get adminBackupLogged;

  /// No description provided for @adminUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get adminUnassigned;

  /// No description provided for @adminGeneralPractice.
  ///
  /// In en, this message translates to:
  /// **'General Practice'**
  String get adminGeneralPractice;

  /// No description provided for @pharmacistDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enterprise inventory command center'**
  String get pharmacistDashboardSubtitle;

  /// No description provided for @pharmacistTotalDrugs.
  ///
  /// In en, this message translates to:
  /// **'Total Drugs'**
  String get pharmacistTotalDrugs;

  /// No description provided for @pharmacistAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get pharmacistAvailable;

  /// No description provided for @pharmacistLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get pharmacistLowStock;

  /// No description provided for @pharmacistOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get pharmacistOutOfStock;

  /// No description provided for @pharmacistQuickAlerts.
  ///
  /// In en, this message translates to:
  /// **'Quick Alerts'**
  String get pharmacistQuickAlerts;

  /// No description provided for @pharmacistNoCriticalAlerts.
  ///
  /// In en, this message translates to:
  /// **'No critical alerts right now.'**
  String get pharmacistNoCriticalAlerts;

  /// No description provided for @pharmacistDispensed.
  ///
  /// In en, this message translates to:
  /// **'Dispensed {qty} × {name}'**
  String pharmacistDispensed(int qty, String name);

  /// No description provided for @pharmacistQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get pharmacistQuantity;

  /// No description provided for @pharmacistApproveProcess.
  ///
  /// In en, this message translates to:
  /// **'Approve & Process Payment'**
  String get pharmacistApproveProcess;

  /// No description provided for @pharmacistSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get pharmacistSaveSettings;

  /// No description provided for @pharmacistPharmacyLocation.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy Location'**
  String get pharmacistPharmacyLocation;

  /// No description provided for @pharmacistNameEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and email are required'**
  String get pharmacistNameEmailRequired;

  /// No description provided for @pharmacistProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get pharmacistProfileUpdated;

  /// No description provided for @pharmacistUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get pharmacistUpdateProfile;

  /// No description provided for @pharmacistAddNewDrug.
  ///
  /// In en, this message translates to:
  /// **'Add New Drug'**
  String get pharmacistAddNewDrug;

  /// No description provided for @pharmacistDrugName.
  ///
  /// In en, this message translates to:
  /// **'Drug Name'**
  String get pharmacistDrugName;

  /// No description provided for @pharmacistCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get pharmacistCategory;

  /// No description provided for @pharmacistStockQty.
  ///
  /// In en, this message translates to:
  /// **'Stock Qty'**
  String get pharmacistStockQty;

  /// No description provided for @pharmacistPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get pharmacistPrice;

  /// No description provided for @pharmacistManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get pharmacistManufacturer;

  /// No description provided for @pharmacistExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get pharmacistExpiryDate;

  /// No description provided for @pharmacistRequiresPrescription.
  ///
  /// In en, this message translates to:
  /// **'Requires Prescription'**
  String get pharmacistRequiresPrescription;

  /// No description provided for @pharmacistRxRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'If enabled, this medication will require an active physician prescription before purchase.'**
  String get pharmacistRxRequiredHint;

  /// No description provided for @pharmacistAddToInventory.
  ///
  /// In en, this message translates to:
  /// **'Add to Inventory'**
  String get pharmacistAddToInventory;

  /// No description provided for @pharmacistDrugAdded.
  ///
  /// In en, this message translates to:
  /// **'Drug added successfully.'**
  String get pharmacistDrugAdded;

  /// No description provided for @pharmacistEditStock.
  ///
  /// In en, this message translates to:
  /// **'Edit Stock — {name}'**
  String pharmacistEditStock(String name);

  /// No description provided for @pharmacistStockQuantity.
  ///
  /// In en, this message translates to:
  /// **'Stock quantity'**
  String get pharmacistStockQuantity;

  /// No description provided for @pharmacistQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get pharmacistQty;

  /// No description provided for @pharmacistSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get pharmacistSaveChanges;

  /// No description provided for @pharmacistStockUpdated.
  ///
  /// In en, this message translates to:
  /// **'Stock updated.'**
  String get pharmacistStockUpdated;

  /// No description provided for @pharmacistRemoveInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from inventory?'**
  String get pharmacistRemoveInventoryTitle;

  /// No description provided for @pharmacistRemoveInventoryBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from this pharmacy stock?'**
  String pharmacistRemoveInventoryBody(String name);

  /// No description provided for @pharmacistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pharmacistDelete;

  /// No description provided for @pharmacistRemovedFromInventory.
  ///
  /// In en, this message translates to:
  /// **'Removed from inventory.'**
  String get pharmacistRemovedFromInventory;

  /// No description provided for @pharmacistInventorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live catalog — search, update, and manage stock'**
  String get pharmacistInventorySubtitle;

  /// No description provided for @pharmacistSearchDrugs.
  ///
  /// In en, this message translates to:
  /// **'Search drugs'**
  String get pharmacistSearchDrugs;

  /// No description provided for @pharmacistSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Type a letter — filters instantly…'**
  String get pharmacistSearchHint;

  /// No description provided for @pharmacistAddNewDrugBtn.
  ///
  /// In en, this message translates to:
  /// **'+ Add New Drug'**
  String get pharmacistAddNewDrugBtn;

  /// No description provided for @pharmacistShowingAll.
  ///
  /// In en, this message translates to:
  /// **'Showing all {count} medications'**
  String pharmacistShowingAll(int count);

  /// No description provided for @pharmacistShowingMatches.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} matches'**
  String pharmacistShowingMatches(int shown, int total);

  /// No description provided for @pharmacistRefreshCatalog.
  ///
  /// In en, this message translates to:
  /// **'Refresh catalog'**
  String get pharmacistRefreshCatalog;

  /// No description provided for @pharmacistNoInventory.
  ///
  /// In en, this message translates to:
  /// **'No inventory loaded.'**
  String get pharmacistNoInventory;

  /// No description provided for @pharmacistNoDrugsMatch.
  ///
  /// In en, this message translates to:
  /// **'No drugs match \"{query}\".'**
  String pharmacistNoDrugsMatch(String query);

  /// No description provided for @pharmacistColDrugName.
  ///
  /// In en, this message translates to:
  /// **'Drug Name'**
  String get pharmacistColDrugName;

  /// No description provided for @pharmacistColCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get pharmacistColCategory;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authSelectYourRole.
  ///
  /// In en, this message translates to:
  /// **'Select Your Role'**
  String get authSelectYourRole;

  /// No description provided for @authChooseHowToUse.
  ///
  /// In en, this message translates to:
  /// **'Choose how you will use Rafeeq'**
  String get authChooseHowToUse;

  /// No description provided for @authFacility.
  ///
  /// In en, this message translates to:
  /// **'Facility: {name}'**
  String authFacility(String name);

  /// No description provided for @authRolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get authRolePatient;

  /// No description provided for @authRoleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get authRoleDoctor;

  /// No description provided for @authRolePharmacist.
  ///
  /// In en, this message translates to:
  /// **'Pharmacist'**
  String get authRolePharmacist;

  /// No description provided for @authRoleNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get authRoleNurse;

  /// No description provided for @authRoleLabTech.
  ///
  /// In en, this message translates to:
  /// **'Laboratory Technician'**
  String get authRoleLabTech;

  /// No description provided for @authRoleRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology Technologist'**
  String get authRoleRadiology;

  /// No description provided for @authSelectFacilityFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select your facility before submitting.'**
  String get authSelectFacilityFirst;

  /// No description provided for @authDoctorDetails.
  ///
  /// In en, this message translates to:
  /// **'Doctor details'**
  String get authDoctorDetails;

  /// No description provided for @authDoctorRegistration.
  ///
  /// In en, this message translates to:
  /// **'Doctor registration'**
  String get authDoctorRegistration;

  /// No description provided for @authLabTechRegistration.
  ///
  /// In en, this message translates to:
  /// **'Laboratory technician registration'**
  String get authLabTechRegistration;

  /// No description provided for @authRadiologyRegistration.
  ///
  /// In en, this message translates to:
  /// **'Radiology technologist registration'**
  String get authRadiologyRegistration;

  /// No description provided for @authSignupPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Complete all sections — pending admin approval'**
  String get authSignupPendingApproval;

  /// No description provided for @authDiscoverFacilities.
  ///
  /// In en, this message translates to:
  /// **'Discover Facilities'**
  String get authDiscoverFacilities;

  /// No description provided for @authChooseFacility.
  ///
  /// In en, this message translates to:
  /// **'Choose a hospital / clinic to continue'**
  String get authChooseFacility;

  /// No description provided for @authSearchFacilityHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, specialty, or location'**
  String get authSearchFacilityHint;

  /// No description provided for @authNoFacilitiesFound.
  ///
  /// In en, this message translates to:
  /// **'No facilities found'**
  String get authNoFacilitiesFound;

  /// No description provided for @authFacilityNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the clinic / hospital name.'**
  String get authFacilityNameRequired;

  /// No description provided for @authConfirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm your facility location on the map.'**
  String get authConfirmLocation;

  /// No description provided for @authCompleteAdminFields.
  ///
  /// In en, this message translates to:
  /// **'Complete all primary admin fields.'**
  String get authCompleteAdminFields;

  /// No description provided for @authInvalidMapLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid map link.'**
  String get authInvalidMapLink;

  /// No description provided for @authCouldNotOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Could not open map link.'**
  String get authCouldNotOpenMap;

  /// No description provided for @authPortalPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get authPortalPatient;

  /// No description provided for @authPortalPatientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Portal, appointments, and health records'**
  String get authPortalPatientSubtitle;

  /// No description provided for @authPortalDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get authPortalDoctor;

  /// No description provided for @authPortalDoctorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in or request physician access'**
  String get authPortalDoctorSubtitle;

  /// No description provided for @authPortalPharmacist.
  ///
  /// In en, this message translates to:
  /// **'Pharmacist'**
  String get authPortalPharmacist;

  /// No description provided for @authPortalPharmacistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy module is enabled for this facility'**
  String get authPortalPharmacistSubtitle;

  /// No description provided for @authPortalLabTech.
  ///
  /// In en, this message translates to:
  /// **'Lab technician'**
  String get authPortalLabTech;

  /// No description provided for @authPortalLabTechSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Laboratory under Lab & Radiology'**
  String get authPortalLabTechSubtitle;

  /// No description provided for @authPortalRadiologist.
  ///
  /// In en, this message translates to:
  /// **'Radiologist'**
  String get authPortalRadiologist;

  /// No description provided for @authPortalRadiologistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Imaging under Lab & Radiology'**
  String get authPortalRadiologistSubtitle;

  /// No description provided for @authPortalEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency staff'**
  String get authPortalEmergency;

  /// No description provided for @authPortalEmergencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Operations / emergency coverage'**
  String get authPortalEmergencySubtitle;

  /// No description provided for @authNurseDashboard.
  ///
  /// In en, this message translates to:
  /// **'Nurse Dashboard'**
  String get authNurseDashboard;

  /// No description provided for @authNurseDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vitals & patient monitoring (placeholder).'**
  String get authNurseDashboardSubtitle;

  /// No description provided for @authPharmacistDashboard.
  ///
  /// In en, this message translates to:
  /// **'Pharmacist Dashboard'**
  String get authPharmacistDashboard;

  /// No description provided for @authPharmacistDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fulfill electronic prescriptions (placeholder).'**
  String get authPharmacistDashboardSubtitle;

  /// No description provided for @authInternDashboard.
  ///
  /// In en, this message translates to:
  /// **'Intern/Trainee Dashboard'**
  String get authInternDashboard;

  /// No description provided for @authInternDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View-only access to cases (placeholder).'**
  String get authInternDashboardSubtitle;

  /// No description provided for @authStaffDashboard.
  ///
  /// In en, this message translates to:
  /// **'Staff/Operations Dashboard'**
  String get authStaffDashboard;

  /// No description provided for @authStaffDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks & facility operations (placeholder).'**
  String get authStaffDashboardSubtitle;

  /// No description provided for @authUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID: {id}'**
  String authUserId(String id);

  /// No description provided for @authReceptionistPortal.
  ///
  /// In en, this message translates to:
  /// **'Receptionist Portal'**
  String get authReceptionistPortal;

  /// No description provided for @authFrontDesk.
  ///
  /// In en, this message translates to:
  /// **'Front Desk'**
  String get authFrontDesk;

  /// No description provided for @authDailySchedule.
  ///
  /// In en, this message translates to:
  /// **'Daily Schedule'**
  String get authDailySchedule;

  /// No description provided for @authPatientRegistration.
  ///
  /// In en, this message translates to:
  /// **'Patient Registration'**
  String get authPatientRegistration;

  /// No description provided for @authBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get authBilling;

  /// No description provided for @authPharmacyPortal.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy Portal'**
  String get authPharmacyPortal;

  /// No description provided for @authPrescriptionsQueue.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions Queue'**
  String get authPrescriptionsQueue;

  /// No description provided for @authInventoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management'**
  String get authInventoryManagement;

  /// No description provided for @authMedicationHistory.
  ///
  /// In en, this message translates to:
  /// **'Medication History'**
  String get authMedicationHistory;

  /// No description provided for @authLearningPortal.
  ///
  /// In en, this message translates to:
  /// **'Learning Portal'**
  String get authLearningPortal;

  /// No description provided for @authObservationMode.
  ///
  /// In en, this message translates to:
  /// **'Observation Mode'**
  String get authObservationMode;

  /// No description provided for @authMedicalLibrary.
  ///
  /// In en, this message translates to:
  /// **'Medical Library'**
  String get authMedicalLibrary;

  /// No description provided for @authTrainingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Training Schedule'**
  String get authTrainingSchedule;

  /// No description provided for @authPatientDetails.
  ///
  /// In en, this message translates to:
  /// **'Patient Details'**
  String get authPatientDetails;

  /// No description provided for @doctorPatientFallback.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get doctorPatientFallback;

  /// No description provided for @doctorMedicationFallback.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get doctorMedicationFallback;

  /// No description provided for @doctorAdrUrgent.
  ///
  /// In en, this message translates to:
  /// **'URGENT — review immediately'**
  String get doctorAdrUrgent;

  /// No description provided for @doctorAdrReviewed.
  ///
  /// In en, this message translates to:
  /// **'REVIEWED'**
  String get doctorAdrReviewed;

  /// No description provided for @doctorAdrPatientRef.
  ///
  /// In en, this message translates to:
  /// **'Patient ref: {ref}'**
  String doctorAdrPatientRef(String ref);

  /// No description provided for @doctorAdrTapDetail.
  ///
  /// In en, this message translates to:
  /// **'Tap for CDSS detail'**
  String get doctorAdrTapDetail;

  /// No description provided for @doctorProposeSuspension.
  ///
  /// In en, this message translates to:
  /// **'Propose suspension'**
  String get doctorProposeSuspension;

  /// No description provided for @doctorPatientMissingExam.
  ///
  /// In en, this message translates to:
  /// **'Patient record is missing — cannot open examination panel.'**
  String get doctorPatientMissingExam;

  /// No description provided for @doctorNoCancelledAppointments.
  ///
  /// In en, this message translates to:
  /// **'No cancelled appointments'**
  String get doctorNoCancelledAppointments;

  /// No description provided for @doctorNoActiveAppointments.
  ///
  /// In en, this message translates to:
  /// **'No active appointments'**
  String get doctorNoActiveAppointments;

  /// No description provided for @doctorTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get doctorTabActive;

  /// No description provided for @doctorTabCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get doctorTabCancelled;

  /// No description provided for @doctorPostpone.
  ///
  /// In en, this message translates to:
  /// **'Postpone'**
  String get doctorPostpone;

  /// No description provided for @doctorCancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel Appointment'**
  String get doctorCancelAppointment;

  /// No description provided for @doctorOpenExamination.
  ///
  /// In en, this message translates to:
  /// **'Open Examination'**
  String get doctorOpenExamination;

  /// No description provided for @doctorTerminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate'**
  String get doctorTerminate;

  /// No description provided for @doctorViewMedicalRecord.
  ///
  /// In en, this message translates to:
  /// **'View Medical Record'**
  String get doctorViewMedicalRecord;

  /// No description provided for @doctorSelectReason.
  ///
  /// In en, this message translates to:
  /// **'Select Reason'**
  String get doctorSelectReason;

  /// No description provided for @doctorReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get doctorReason;

  /// No description provided for @doctorNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get doctorNotesOptional;

  /// No description provided for @doctorBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get doctorBack;

  /// No description provided for @doctorConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancel'**
  String get doctorConfirmCancel;

  /// No description provided for @doctorAppointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled — patient notified'**
  String get doctorAppointmentCancelled;

  /// No description provided for @doctorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get doctorCancelled;

  /// No description provided for @doctorPatientIdMissingExam.
  ///
  /// In en, this message translates to:
  /// **'Patient ID missing on this appointment — cannot open examination.'**
  String get doctorPatientIdMissingExam;

  /// No description provided for @doctorPatientIdMissingStart.
  ///
  /// In en, this message translates to:
  /// **'Patient ID missing on this appointment — cannot start examination.'**
  String get doctorPatientIdMissingStart;

  /// No description provided for @doctorPatientIdMissingRecord.
  ///
  /// In en, this message translates to:
  /// **'Patient ID missing — cannot open medical record.'**
  String get doctorPatientIdMissingRecord;

  /// No description provided for @doctorSearchPatients.
  ///
  /// In en, this message translates to:
  /// **'Search patients'**
  String get doctorSearchPatients;

  /// No description provided for @doctorWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get doctorWarning;

  /// No description provided for @doctorProceedAnyway.
  ///
  /// In en, this message translates to:
  /// **'Proceed anyway'**
  String get doctorProceedAnyway;

  /// No description provided for @doctorLabTestNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a lab test name.'**
  String get doctorLabTestNameRequired;

  /// No description provided for @doctorLabOrderSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Order submitted to laboratory successfully!'**
  String get doctorLabOrderSubmitted;

  /// No description provided for @doctorStudyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a study name.'**
  String get doctorStudyNameRequired;

  /// No description provided for @doctorImagingOrderSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Order submitted to radiology successfully!'**
  String get doctorImagingOrderSubmitted;

  /// No description provided for @doctorEnterConditionPlan.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least the Condition and Treatment Plan.'**
  String get doctorEnterConditionPlan;

  /// No description provided for @doctorSessionUpdatedDiagnosisRx.
  ///
  /// In en, this message translates to:
  /// **'Active session updated — diagnosis and prescription saved.'**
  String get doctorSessionUpdatedDiagnosisRx;

  /// No description provided for @doctorSessionUpdatedDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Active session updated — diagnosis saved.'**
  String get doctorSessionUpdatedDiagnosis;

  /// No description provided for @doctorRecordSavedDiagnosisRx.
  ///
  /// In en, this message translates to:
  /// **'Medical record saved — diagnosis and prescription submitted.'**
  String get doctorRecordSavedDiagnosisRx;

  /// No description provided for @doctorRecordSavedDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Medical record saved — diagnosis submitted.'**
  String get doctorRecordSavedDiagnosis;
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
    'that was used.',
  );
}
