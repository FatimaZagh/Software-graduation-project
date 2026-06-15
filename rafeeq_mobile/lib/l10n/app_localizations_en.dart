// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rafeeq';

  @override
  String get navHome => 'Home';

  @override
  String get navBook => 'Book';

  @override
  String get navPharmacy => 'Pharmacy';

  @override
  String get navHealth => 'Health';

  @override
  String get navMore => 'More';

  @override
  String get profileSettings => 'Profile Settings';

  @override
  String get medicalRecords => 'Medical Records';

  @override
  String get medicalRecordBloodType => 'Blood Type';

  @override
  String get medicalRecordAllergies => 'Allergies';

  @override
  String get medicalRecordChronicConditions => 'Chronic Conditions';

  @override
  String get medicalRecordNoneReported => 'None reported';

  @override
  String get medicalRecordNone => 'None';

  @override
  String get medicalRecordEncounterTimeline => 'Encounter Timeline';

  @override
  String get medicalRecordNoVisits => 'No registered visits yet';

  @override
  String get medicalRecordNoVisitsHint =>
      'Your clinical visit history will appear here after you complete appointments with your care team.';

  @override
  String get medicalRecordChiefComplaint => 'Symptoms & Complaint';

  @override
  String get medicalRecordDiagnosis => 'Clinical Diagnosis';

  @override
  String get medicalRecordVitals => 'Recorded Vital Signs';

  @override
  String get medicalRecordDoctorNotes => 'Physician Assessment Notes';

  @override
  String get paymentHistory => 'Payment History';

  @override
  String get logout => 'Logout';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get doctorDashboardTitle => 'Doctor workspace';

  @override
  String get doctorNavOverview => 'Overview';

  @override
  String get doctorNavAppointments => 'Appointments';

  @override
  String get doctorNavMessages => 'Messages';

  @override
  String get doctorNavReviews => 'Reviews';

  @override
  String get doctorDrawerProfile => 'Professional profile';

  @override
  String get doctorRetry => 'Retry';

  @override
  String get doctorPatientsToday => 'Patients today';

  @override
  String get doctorTotalAppointments => 'Your appointments';

  @override
  String get doctorEarningsToday => 'Earnings today (ILS)';

  @override
  String get doctorPatientsUnique => 'Distinct patients';

  @override
  String get doctorCancellationRate => 'Cancellation rate %';

  @override
  String get doctorQueueTitle => 'Upcoming & queue';

  @override
  String get doctorNoAppointments => 'No appointments match your profile.';

  @override
  String get doctorBookingPending => 'Pending';

  @override
  String get doctorBookingAccepted => 'Accepted';

  @override
  String get doctorBookingRejected => 'Rejected';

  @override
  String get doctorVisitWaiting => 'Waiting';

  @override
  String get doctorVisitInProgress => 'In progress';

  @override
  String get doctorVisitCompleted => 'Completed';

  @override
  String get doctorAccept => 'Accept';

  @override
  String get doctorReject => 'Reject';

  @override
  String get doctorReschedule => 'Reschedule';

  @override
  String get doctorStartVisit => 'Start visit';

  @override
  String get doctorEndVisit => 'End visit';

  @override
  String get doctorOpenConsultation => 'Consultation';

  @override
  String get doctorWaitingList => 'Waiting list';

  @override
  String get doctorWaitingListEmpty => 'No active waiting-list entries.';

  @override
  String get doctorChatTitle => 'Patient messages';

  @override
  String get doctorSelectPatient => 'Select patient';

  @override
  String get doctorChatHint => 'Type a message (updates every few seconds).';

  @override
  String get doctorSend => 'Send';

  @override
  String get doctorReviewsTitle => 'Ratings';

  @override
  String get doctorNoReviews => 'No ratings linked to your account yet.';

  @override
  String get doctorStars => 'Stars';

  @override
  String get doctorPunctuality => 'Punctuality';

  @override
  String get doctorCleanliness => 'Cleanliness';

  @override
  String get doctorBehavior => 'Doctor behavior';

  @override
  String get doctorComment => 'Comment';

  @override
  String get doctorTabPreconsult => 'Pre-consult';

  @override
  String get doctorTabSession => 'Session';

  @override
  String get doctorTabRx => 'E-prescription';

  @override
  String get doctorSessionSaved => 'Session saved';

  @override
  String get doctorRxNeedMed => 'Add at least one medication name.';

  @override
  String get doctorRxSaved => 'Prescription sent to patient & pharmacy';

  @override
  String get doctorChronic => 'Chronic diseases';

  @override
  String get doctorNone => 'None on file';

  @override
  String get doctorAllergies => 'Allergies';

  @override
  String get doctorSurgeries => 'Past surgeries';

  @override
  String get doctorMeds => 'Current medications';

  @override
  String get doctorPrevVisits => 'Previous visits';

  @override
  String get doctorPatientRecord => 'Patient record';

  @override
  String get doctorDiagnosis => 'Diagnosis';

  @override
  String get doctorNotes => 'Notes';

  @override
  String get doctorVitals => 'Vitals';

  @override
  String get doctorWeightKg => 'Weight (kg)';

  @override
  String get doctorBpSys => 'BP systolic';

  @override
  String get doctorBpDia => 'BP diastolic';

  @override
  String get doctorHeartRate => 'Heart rate';

  @override
  String get doctorAttachScan => 'Attach scan / lab image';

  @override
  String doctorAttachmentsCount(int count) {
    return '$count attachments on file';
  }

  @override
  String get doctorSaveSession => 'Save session';

  @override
  String get doctorMedName => 'Medication name';

  @override
  String get doctorMedDosage => 'Dosage';

  @override
  String get doctorMedDuration => 'Duration';

  @override
  String get doctorMedInstructions => 'Instructions';

  @override
  String get doctorMedFrequency => 'Frequency';

  @override
  String get doctorAddMedLine => 'Add medication line';

  @override
  String get doctorPickSignature => 'Pick signature image';

  @override
  String get doctorSignatureReady => 'Signature attached';

  @override
  String get doctorSubmitRx => 'Submit prescription';

  @override
  String get doctorProfileTitle => 'Professional profile';

  @override
  String get doctorFieldDisplayName => 'Display name';

  @override
  String get doctorFieldSpecialization => 'Specialization';

  @override
  String get doctorFieldYears => 'Years of experience';

  @override
  String get doctorFieldCertifications => 'Certifications (comma-separated)';

  @override
  String get doctorFieldFee => 'Consultation fee (ILS)';

  @override
  String get doctorFieldPhoto => 'Profile photo';

  @override
  String get doctorPickPhoto => 'Choose photo';

  @override
  String get doctorApplySchedule =>
      'Apply Mon–Fri 09:00–17:00 with lunch break';

  @override
  String get doctorScheduleApplied =>
      'Standard work schedule applied (save to persist).';

  @override
  String get doctorSaveProfile => 'Save profile';

  @override
  String get doctorProfileSaved => 'Profile saved';

  @override
  String get doctorPollHint => 'Lists refresh automatically every 8 seconds.';

  @override
  String get doctorLabelBooking => 'Booking';

  @override
  String get doctorLabelVisit => 'Visit';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get confirm => 'Confirm';

  @override
  String get close => 'Close';

  @override
  String get submit => 'Submit';

  @override
  String get continueAction => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get loading => 'Loading';

  @override
  String get error => 'Error';

  @override
  String get patient => 'Patient';

  @override
  String get doctor => 'Doctor';

  @override
  String get status => 'Status';

  @override
  String get notifications => 'Notifications';

  @override
  String get messages => 'Messages';

  @override
  String get doctorGridAppointments => 'Appointments';

  @override
  String get doctorGridWaitingList => 'Waiting List';

  @override
  String get doctorGridMySchedule => 'My Schedule';

  @override
  String get doctorGridPatientRecords => 'Patient Records';

  @override
  String get doctorGridEPrescription => 'E-Prescription';

  @override
  String get doctorGridOrderLab => 'Order Lab Test';

  @override
  String get doctorGridOrderImaging => 'Order Imaging';

  @override
  String get doctorGridClinicAnalytics => 'Clinic Analytics';

  @override
  String get doctorGridIncomingMessages => 'Messages';

  @override
  String get doctorGridActivePatients => 'Active Patients';

  @override
  String get doctorGridCompletedVisits => 'Completed Visits';

  @override
  String get doctorGridDashboard => 'Dashboard';

  @override
  String get doctorGridPatients => 'Patients';

  @override
  String get doctorGridLabResults => 'Lab Results';

  @override
  String get doctorGridRadiologyResults => 'Radiology Results';

  @override
  String get doctorGridProfile => 'Profile';

  @override
  String get doctorGridMyPatients => 'My Patients';

  @override
  String get doctorLanguageToggle => 'العربية';

  @override
  String get doctorGridAvailability => 'Availability';

  @override
  String get doctorGridTodaysQueue => 'Today\'s queue';

  @override
  String get doctorGridNoPatientsToday => 'No patients scheduled today.';

  @override
  String get doctorGridAdrReports => 'ADR reports';

  @override
  String get doctorGridNoAdrReports => 'No adverse drug reports.';

  @override
  String get doctorGridDailyCases => 'Daily cases';

  @override
  String get doctorGridChronic => 'Chronic';

  @override
  String get doctorGridFollowUps => 'Follow-ups';

  @override
  String get doctorGridClinicalOverview => 'Clinical overview';

  @override
  String get doctorGridQuickActions => 'Quick actions';

  @override
  String get superAdminPlatformTitle => 'Platform Super Admin';

  @override
  String get superAdminPlatformSubtitle => 'Platform Control Center';

  @override
  String get superAdminMedicalOrdersFeed => 'Medical Orders';

  @override
  String get superAdminRegisteredOrganizations => 'Registered Organizations';

  @override
  String get superAdminPendingApplications => 'Pending Applications';

  @override
  String get superAdminFinancialLedger => 'Financial Ledger';

  @override
  String get superAdminMedicalOrdersFeedTitle => 'All Medical Orders Feed';

  @override
  String get superAdminMedicalOrdersFeedSubtitle =>
      'Lab, imaging, and e-prescription requests across all facilities — live tracking';

  @override
  String get superAdminPlatformOverview => 'Platform overview';

  @override
  String get superAdminLiveOrderActivity => 'Live medical activity';

  @override
  String get superAdminStatClinics => 'Clinics';

  @override
  String get superAdminStatSystemUsers => 'System Users';

  @override
  String get superAdminStatDoctors => 'Doctors';

  @override
  String get superAdminStatTotalPatients => 'Total Patients';

  @override
  String get superAdminOrdersTotal => 'Total';

  @override
  String get superAdminOrdersLab => 'Lab';

  @override
  String get superAdminOrdersImaging => 'Imaging';

  @override
  String get superAdminOrdersRx => 'Rx';

  @override
  String get superAdminNoMedicalOrders => 'No medical orders recorded yet.';

  @override
  String get superAdminPatientIdLabel => 'Patient';

  @override
  String get superAdminOrderTypeLab => 'LAB TEST';

  @override
  String get superAdminOrderTypeImaging => 'IMAGING';

  @override
  String get superAdminOrderTypePrescription => 'PRESCRIPTION';

  @override
  String get superAdminOrderStatusRequested => 'Requested';

  @override
  String get superAdminOrderStatusPending => 'Pending';

  @override
  String get superAdminOrderStatusCompleted => 'Completed';

  @override
  String get superAdminLanguageToggle => 'العربية';

  @override
  String get superAdminFilterAll => 'All';

  @override
  String get superAdminFilterActive => 'Active';

  @override
  String get superAdminFilterPending => 'Pending';

  @override
  String get superAdminFilterSuspended => 'Suspended';

  @override
  String get superAdminNoOrganizations => 'No organizations registered yet.';

  @override
  String get superAdminRegisteredOn => 'Registered';

  @override
  String get superAdminNoPendingFacilities =>
      'No pending facility registrations.';

  @override
  String get superAdminNoPendingStaffRequests =>
      'No pending staff registration requests.';

  @override
  String get superAdminNoPendingStaffAccounts =>
      'No pending staff user accounts.';

  @override
  String get superAdminApprove => 'Approve';

  @override
  String get superAdminApproving => '…';

  @override
  String get superAdminOrganizationApproved => 'Organization approved.';

  @override
  String get superAdminLedgerTitle => 'Financial Ledger & Billing';

  @override
  String get superAdminOrganizationsMetric => 'Organizations';

  @override
  String get superAdminActiveMetric => 'Active';

  @override
  String get superAdminPaymentsMetric => 'Payments';

  @override
  String get superAdminPendingInvoicesMetric => 'Pending invoices';

  @override
  String get superAdminEntitySubscriptions => 'Entity subscriptions';

  @override
  String get superAdminRecentTransactions => 'Recent transactions';

  @override
  String get superAdminNoBillingEntities => 'No billing entities yet.';

  @override
  String get superAdminNoTransactions => 'No transactions recorded yet.';

  @override
  String get superAdminPharmacyDashboardTitle => 'Pharmacy Dashboard';

  @override
  String get superAdminSalesAndFinancials => 'Sales & Financials';

  @override
  String get superAdminTotalSales => 'Total Sales';

  @override
  String get superAdminMonthlyRevenue => 'Monthly Revenue';

  @override
  String get superAdminWalletBalance => 'Wallet Balance';

  @override
  String get superAdminInventoryShortages => 'Out of Stock / Low Inventory';

  @override
  String get superAdminMedicineName => 'Medicine Name';

  @override
  String get superAdminStockStatus => 'Status';

  @override
  String get superAdminActivePrescriptions => 'Active Prescriptions';

  @override
  String get superAdminPendingOrders => 'Pending Orders';

  @override
  String get superAdminProcessedOrders => 'Processed Orders';

  @override
  String get superAdminTotalOrders => 'Total Orders';

  @override
  String get superAdminNoShortages => 'No inventory shortages.';

  @override
  String get superAdminTapToViewPharmacy => 'Tap to open pharmacy dashboard';

  @override
  String superAdminPendingQueueTitle(int count) {
    return 'Pending Applications Queue ($count)';
  }

  @override
  String superAdminFacilityRegistrations(int count) {
    return 'Facility registrations ($count)';
  }

  @override
  String superAdminStaffRegistrationRequests(int count) {
    return 'Staff registration requests ($count)';
  }

  @override
  String superAdminPendingStaffAccountsTitle(int count) {
    return 'Pending staff accounts ($count)';
  }

  @override
  String superAdminOrgStatusLine(String status, String subscription) {
    return 'Status: $status · $subscription';
  }

  @override
  String superAdminPendingAmount(String amount) {
    return 'Pending $amount';
  }

  @override
  String get superAdminInventoryOutOfStock => 'Out of Stock';

  @override
  String get superAdminInventoryLowStock => 'Low Stock';

  @override
  String get superAdminInventoryAvailable => 'Available';

  @override
  String get superAdminSubscriptionFree => 'Free';

  @override
  String get superAdminSubscriptionPremium => 'Premium';

  @override
  String get superAdminSubscriptionEnterprise => 'Enterprise';

  @override
  String get nurseNavPatients => 'Patients';

  @override
  String get nurseNavTriageQueue => 'Triage queue';

  @override
  String get nurseNavVitals => 'Vitals';

  @override
  String get nurseNavNursingNotes => 'Nursing notes';

  @override
  String get nurseNavMedications => 'Medications';

  @override
  String get nurseNavLabs => 'Labs';

  @override
  String get nurseNavAlerts => 'Alerts';

  @override
  String get nurseNavProfileHr => 'Profile & HR';

  @override
  String get nurseStationTitle => 'Nurse Station';

  @override
  String nurseActivePatient(String patientLabel) {
    return 'Active: $patientLabel';
  }

  @override
  String get adminNavDashboard => 'Dashboard';

  @override
  String get adminNavDoctorAnalytics => 'Doctor analytics';

  @override
  String get adminNavStaff => 'Staff';

  @override
  String get adminNavPatients => 'Patients';

  @override
  String get adminNavAppointments => 'Appointments';

  @override
  String get adminNavLeave => 'Leave';

  @override
  String get adminNavMedicalRecords => 'Medical records';

  @override
  String get adminNavBilling => 'Billing';

  @override
  String get adminNavPermissions => 'Permissions';

  @override
  String get adminNavInventory => 'Inventory';

  @override
  String get adminNavAuditLog => 'Audit log';

  @override
  String get adminNavBroadcast => 'Broadcast';

  @override
  String get adminNavSettings => 'Settings';

  @override
  String get adminClinicAdmin => 'Clinic Admin';

  @override
  String get adminAdministrator => 'Administrator';

  @override
  String get pharmacistNavDashboardOverview => 'Dashboard Overview';

  @override
  String get pharmacistNavInventoryManagement => 'Inventory Management';

  @override
  String get pharmacistNavInventoryLogs => 'Inventory Logs';

  @override
  String get pharmacistNavDispensingTerminal => 'Dispensing Terminal';

  @override
  String get pharmacistNavMedicationRequests => 'Medication Requests';

  @override
  String get pharmacistNavSystemNotifications => 'System Notifications';

  @override
  String get pharmacistNavAnalyticReports => 'Analytic Reports';

  @override
  String get pharmacistNavPharmacySettings => 'Pharmacy Settings';

  @override
  String get pharmacistNavPharmacistProfile => 'Pharmacist Profile';

  @override
  String get pharmacistBrandTitle => 'Rafeeq Pharmacy';

  @override
  String get pharmacistDefaultName => 'Rafeeq Pharmacy';

  @override
  String get technicianRoleRadiologyTech => 'Radiology Tech';

  @override
  String get technicianRoleLabTechnician => 'Laboratory Technician';

  @override
  String get technicianNavOverview => 'Overview';

  @override
  String get technicianNavIncomingOrders => 'Incoming Orders';

  @override
  String get technicianNavIncomingOrdersAr => 'الطلبات الواردة';

  @override
  String get technicianImagingWorkflow => 'Imaging Workflow';

  @override
  String get technicianWelcome => 'Welcome';

  @override
  String technicianWelcomeName(String name) {
    return 'Welcome, $name';
  }

  @override
  String get technicianRadiologyOverviewHint =>
      'Review imaging orders under Incoming Orders and upload DICOM, PDF, or image reports.';

  @override
  String get technicianLabOverviewHint =>
      'Review doctor lab requests under Incoming Orders and submit finalized reports.';

  @override
  String technicianPendingOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending orders',
      one: '1 pending order',
    );
    return '$_temp0';
  }

  @override
  String get technicianOpenIncomingOrders => 'Open incoming orders';

  @override
  String get technicianRadiologyGreetingHint =>
      'Incoming imaging orders from the radiology queue.';

  @override
  String get technicianLabGreetingHint =>
      'Incoming laboratory orders from the lab queue.';

  @override
  String get technicianTabIncomingRequests => 'Incoming Requests';

  @override
  String get technicianTabCompletedExams => 'Completed Exams';

  @override
  String get technicianNoPendingImagingRequests =>
      'No pending imaging requests found';

  @override
  String get technicianNoPendingImagingSubtitle =>
      'Doctor imaging orders (X-Ray, CT, MRI, Ultrasound) for your clinic will appear here.';

  @override
  String get technicianNoCompletedImagingExams =>
      'No completed imaging exams found';

  @override
  String get technicianNoCompletedImagingSubtitle =>
      'Submitted imaging reports will appear here for your reference.';

  @override
  String get technicianNoIncomingOrders => 'No incoming orders';

  @override
  String get technicianNoIncomingOrdersSubtitle =>
      'Doctor laboratory requests for your clinic will appear here.';

  @override
  String get technicianLabTest => 'Lab test';

  @override
  String get technicianImagingStudy => 'Imaging study';

  @override
  String get technicianPatientId => 'Patient ID';

  @override
  String get technicianModalityExamType => 'Modality / Exam Type';

  @override
  String get technicianBodyPart => 'Body Part';

  @override
  String get technicianOrderingPhysician => 'Ordering Physician';

  @override
  String get technicianReasonForExam => 'Reason for Exam';

  @override
  String get technicianTestRequested => 'Test requested';

  @override
  String technicianOrderedAt(String dateTime) {
    return 'Ordered: $dateTime';
  }

  @override
  String technicianCompletedAt(String dateTime) {
    return 'Completed: $dateTime';
  }

  @override
  String get technicianReportFinalized =>
      'Report finalized — read-only. No further edits permitted.';

  @override
  String get technicianEnterImagingResults => 'Enter Imaging Results';

  @override
  String get technicianEnterResults => 'Enter Results';

  @override
  String get technicianResultAnalysisNotes => 'Result analysis / notes';

  @override
  String get technicianEnterDiagnosticFindings =>
      'Enter diagnostic findings and analysis';

  @override
  String get technicianAnalysisNotesRequired => 'Analysis notes are required';

  @override
  String get technicianAttachDocument => 'Attach document (PDF/Image)';

  @override
  String get technicianSubmitImagingReport => 'Submit Imaging Report';

  @override
  String get technicianSubmitReport => 'Submit Report';

  @override
  String get technicianAttachImagingBeforeSubmit =>
      'Attach an imaging file or add technician notes before submitting.';

  @override
  String get technicianImagingReportSubmitted =>
      'Imaging report submitted — record locked and removed from queue.';

  @override
  String get technicianReportSubmitted =>
      'Report submitted — record locked and removed from queue.';

  @override
  String get technicianStatusPending => 'Pending';

  @override
  String get technicianStatusCompleted => 'Completed';

  @override
  String get landingMenu => 'Menu';

  @override
  String get landingLogin => 'Login';

  @override
  String get landingSignUp => 'Sign Up';

  @override
  String get landingRefreshClinics => 'Refresh clinics';

  @override
  String get landingRafeeqClinic => 'Rafeeq Clinic';

  @override
  String get landingRegisterFacility => 'Register your facility';

  @override
  String get landingRegisterFacilitySubtitle =>
      'Clinic / hospital setup — organization + admin account';

  @override
  String get landingOurFacilities => 'Our facilities';

  @override
  String get landingTapFacilityHint => 'Tap a facility to view details.';

  @override
  String get landingNoFacilities =>
      'No registered facilities found. Be the first to set up your organization!';

  @override
  String get landingCouldNotLoadFacilities => 'Could not load facilities.';

  @override
  String get landingContactUs => 'Contact Us';

  @override
  String get landingContactSubtitle =>
      'We\'d love to hear from you.\nSend us a message.';

  @override
  String get landingContactName => 'Name';

  @override
  String get landingContactEmail => 'Email';

  @override
  String get landingContactMessage => 'Message';

  @override
  String get landingSendMessage => 'Send Message';

  @override
  String landingVideoLoadError(String details) {
    return 'Video failed to load.\n\n$details';
  }

  @override
  String get landingFacilityFallback => 'Facility';

  @override
  String get loginWelcomeBack => 'Welcome Back';

  @override
  String get loginTagline => 'Sign in to continue caring, together.';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get loginRememberMe => 'Remember me';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginForgotPasswordNotImplemented =>
      'Forgot password is not implemented yet.';

  @override
  String get loginSigningIn => 'Signing in…';

  @override
  String get loginSignInWithEmail => 'Sign in with Email';

  @override
  String get loginOr => 'or';

  @override
  String get loginSignInWithGoogle => 'Sign in with Google';

  @override
  String get loginSignInWithFacebook => 'Sign in with Facebook';

  @override
  String get loginDontHaveAccount => 'Don\'t have an account? ';

  @override
  String get loginSignUp => 'Sign up';

  @override
  String get loginYourHealth => 'Your health.';

  @override
  String get loginOurCommitment => 'Our commitment.';

  @override
  String get loginSuperAdminMissingToken => 'Super Admin login missing token.';

  @override
  String get loginRoleMissing => 'Login succeeded but role is missing.';

  @override
  String get loginUserIdMissing => 'Login succeeded but user id is missing.';

  @override
  String get loginOrgIdMissingDoctor =>
      'Login succeeded but facility orgId is missing. Contact your clinic admin.';

  @override
  String get loginInvalidCredentials => 'Invalid email or password';

  @override
  String get loginConnectionFailed => 'Connection failed';

  @override
  String get loginGoogleTokenFailed =>
      'Could not get Google ID token. Check Web client ID / OAuth consent.';

  @override
  String loginGoogleSignInFailed(String error) {
    return 'Google sign-in failed: $error';
  }

  @override
  String get loginFacebookCancelled => 'Facebook login cancelled or no token.';

  @override
  String loginFacebookSignInFailed(String error) {
    return 'Facebook sign-in failed: $error';
  }

  @override
  String loginFailedMessage(String message) {
    return 'Login failed: $message';
  }

  @override
  String get loginClinicUnderReview => 'Clinic under review';

  @override
  String get loginClinicUnderReviewMessage =>
      'Your clinic is under review. Please wait for Super Admin activation.';

  @override
  String get loginOk => 'OK';

  @override
  String get loginFacilityPendingApproval =>
      'Your facility registration request is still pending approval from the Super Admin.';

  @override
  String loginUnknownRole(String role) {
    return 'Unknown role: $role';
  }

  @override
  String get logoutDialogTitle => 'Log out?';

  @override
  String get logoutDialogReturnToLanding =>
      'Return to the public landing page.';

  @override
  String get logoutDialogReturnToLogin =>
      'You will return to the login screen.';

  @override
  String get logOut => 'Log out';

  @override
  String get logoutDialogReturnToLandingAdmin =>
      'You will return to the public landing page.';

  @override
  String get patientEmergency => 'Emergency';

  @override
  String get patientEmergencyHint =>
      'Use these numbers in an emergency. On phone, \"Call now\" opens your dialer.';

  @override
  String get patientEmergencyNational => 'National emergency';

  @override
  String get patientEmergencyCivilDefense => 'Civil defense';

  @override
  String get patientEmergencyPolice => 'Police';

  @override
  String get patientEmergencyClinic24h => 'Rafeeq clinic (24h)';

  @override
  String get patientCallNow => 'Call now';

  @override
  String patientDialerFailed(String label) {
    return 'Could not open dialer for $label';
  }

  @override
  String patientCallFailed(String error) {
    return 'Call failed: $error';
  }

  @override
  String get patientCancelAppointmentTitle => 'Cancel appointment?';

  @override
  String patientCancelAppointmentBody(String date, String time) {
    return 'Cancel your visit on $date at $time? The next patient on the waiting list may be promoted automatically.';
  }

  @override
  String get patientKeep => 'Keep';

  @override
  String get patientCancelVisit => 'Cancel visit';

  @override
  String get patientAppointmentCancelled => 'Appointment cancelled.';

  @override
  String get patientAppointmentCancelledPromoted =>
      'Appointment cancelled. Next patient on the waitlist was confirmed.';

  @override
  String get patientCancelRequestTitle => 'Cancel request?';

  @override
  String patientCancelRequestBody(String doctor, String date, String time) {
    return 'Leave the waiting list for $doctor on $date at $time? You can join again later if the slot is still full.';
  }

  @override
  String get patientStay => 'Stay';

  @override
  String get patientCancelRequest => 'Cancel request';

  @override
  String get patientRemovedFromWaitlist => 'Removed from waiting list.';

  @override
  String get patientMyBookings => 'My Bookings';

  @override
  String get patientConfirmedBookings => 'Confirmed Bookings';

  @override
  String get patientNoUpcomingVisits => 'No upcoming confirmed visits.';

  @override
  String get patientWaitingLists => 'Waiting Lists';

  @override
  String get patientNotOnWaitingLists => 'You are not on any waiting lists.';

  @override
  String get patientConfirmedFromWaitlist => 'Confirmed from Waitlist';

  @override
  String get patientDoctorApproved => 'Doctor approved';

  @override
  String get patientAppointmentLabel => 'Appointment';

  @override
  String get patientCancelAppointment => 'Cancel Appointment';

  @override
  String get patientOnWaitingListHint =>
      'On waiting list — you will be notified if a slot opens';

  @override
  String get patientLeaveWaitingList => 'Leave Waiting List';

  @override
  String get patientConfirmBookingTitle =>
      'Confirm your Appointment Reservation';

  @override
  String patientConfirmBookingBody(String doctor, String date, String time) {
    return 'Book an appointment with Dr. $doctor on $date at $time?';
  }

  @override
  String get patientConfirmBooking => 'Confirm booking';

  @override
  String get patientJoinWaitingListTitle => 'Join Waiting List';

  @override
  String patientJoinWaitingListBody(String doctor) {
    return 'This appointment slot with Dr. $doctor is currently full. Would you like to join the waiting list? You will receive an immediate notification if this appointment is canceled.';
  }

  @override
  String get patientJoinList => 'Join List';

  @override
  String get patientSlotFullWaitlist =>
      'This slot is full. You have been added to the waiting list.';

  @override
  String patientAppointmentBooked(String doctor) {
    return 'Appointment booked with Dr. $doctor';
  }

  @override
  String get patientSelectDoctor => 'Select doctor';

  @override
  String get patientChooseDoctor => 'Choose a doctor';

  @override
  String patientLoadingSchedule(String doctor) {
    return 'Loading schedule for $doctor…';
  }

  @override
  String patientNoWorkingDays(String doctor) {
    return 'No working days with bookable slots for $doctor.';
  }

  @override
  String patientDoctorUnavailable(String doctor) {
    return '$doctor is not available on this day.';
  }

  @override
  String patientNoSlotsOnDay(String day) {
    return 'No slots on $day.\nPick another day above.';
  }

  @override
  String get patientThisDay => 'this day';

  @override
  String get patientAvailable => 'Available';

  @override
  String get patientOnWaitlist => 'On waitlist';

  @override
  String get patientFullTapToWait => 'Full · tap to wait';

  @override
  String get patientBookWithDoctor => 'Book with your doctor';

  @override
  String get patientBookFlowHint =>
      'Choose a doctor, then a day they see patients, then a time slot.';

  @override
  String patientAvailableDays(String doctor) {
    return 'Available days · $doctor';
  }

  @override
  String get patientTimeSlots => 'Time slots';

  @override
  String patientSelectSlotHint(String doctor) {
    return 'Available slots: tap to confirm your reservation. Full slots: tap to join the waiting list for Dr. $doctor.';
  }

  @override
  String get patientAlreadyOnWaitlist =>
      'You cannot join the waiting list for a slot you have already booked or requested.';

  @override
  String get patientPrescribedMedsMissingCatalog =>
      'Prescribed medications are missing catalog ids — contact your clinic.';

  @override
  String patientOpeningPharmacy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prescribed medications',
      one: '1 prescribed medication',
    );
    return 'Opening pharmacy with $_temp0…';
  }

  @override
  String get patientRxItemMissingDrugId =>
      'This prescription item is missing a catalog drug id.';

  @override
  String get patientPrescriptionIdMissing =>
      'Prescription record id missing — refresh and try again.';

  @override
  String get patientEPrescriptions => 'E-Prescriptions';

  @override
  String get patientNoEPrescriptions =>
      'No electronic prescriptions yet.\nYour physician will issue Rx here when needed.';

  @override
  String patientIssuedExpires(String issued, String expires) {
    return 'Issued $issued · Expires $expires';
  }

  @override
  String patientESignature(String signature) {
    return 'e-Signature: $signature';
  }

  @override
  String get patientRx => 'Rx';

  @override
  String patientAllowedDispensedPending(
    String allowed,
    String dispensed,
    String pending,
  ) {
    return 'Allowed: $allowed · Dispensed: $dispensed · Pending: $pending';
  }

  @override
  String get patientFullyFulfilled => 'Fully fulfilled';

  @override
  String get patientTapToPurchaseRx => 'Tap to purchase with this prescription';

  @override
  String get patientOrderViaPharmacy => 'Order via Pharmacy';

  @override
  String get patientStatusActive => 'Active';

  @override
  String get patientStatusCompleted => 'Completed';

  @override
  String get patientStartMedicationTitle => 'Start medication?';

  @override
  String get patientStartMedicationBody =>
      'Start taking this medication today?';

  @override
  String get patientStartToday => 'Start today';

  @override
  String get patientMyPrescriptions => 'My Prescriptions';

  @override
  String get patientNoPrescriptions => 'No prescriptions on file.';

  @override
  String get patientCurrentPrescriptions => 'Current prescriptions';

  @override
  String get patientCompletedHistory => 'Completed history';

  @override
  String get patientExpired => 'Expired';

  @override
  String patientCourseNotStarted(String days) {
    return 'Course: $days days (not started)';
  }

  @override
  String patientStartedEnds(String start, String end) {
    return 'Started $start · ends $end';
  }

  @override
  String patientCourseLength(String days) {
    return 'Course length: $days days';
  }

  @override
  String patientDoseFrequency(String dose, String frequency) {
    return 'Dose: $dose · $frequency';
  }

  @override
  String patientPrescriber(String name) {
    return 'Prescriber: $name';
  }

  @override
  String get patientTapForAiDetails => 'Tap medication name for AI details';

  @override
  String get patientReportSideEffect =>
      'Report Side Effect / بلغ عن مشكلة مع الدواء';

  @override
  String get patientUnknownMedication => 'Unknown medication';

  @override
  String get patientSearchFailed => 'Search failed';

  @override
  String get patientCatalogIdMissing =>
      'Medication catalog id missing — refresh search.';

  @override
  String get patientGo => 'Go';

  @override
  String get patientPrescriptionRequiredPharmacy =>
      'Prescription required — use Order via Pharmacy from your E-Prescriptions.';

  @override
  String get patientSearchClinicStock => 'Search clinic stock';

  @override
  String get patientClinicPharmacy => 'Clinic pharmacy';

  @override
  String get patientInStock => 'In stock';

  @override
  String get patientOutOfStock => 'Out of stock';

  @override
  String get patientRxAuthorized => 'Rx ✓';

  @override
  String get patientPrescriptionRequired => 'Prescription Required';

  @override
  String get patientBuyRx => 'Buy (Rx)';

  @override
  String get patientBuy => 'Buy';

  @override
  String get patientNearbyPharmacies => 'Nearby pharmacies (if unavailable)';

  @override
  String get patientDigitalHealthProfile => 'Digital health profile';

  @override
  String get patientOfficialMedicalReadOnly =>
      'Official medical reference — read only';

  @override
  String get patientDoctorChat => 'Doctor chat';

  @override
  String get patientClinic => 'Clinic';

  @override
  String get patientSelectClinicDoctor =>
      'Select a clinic with an assigned doctor to start chatting.';

  @override
  String get patientSelectDoctorChat => 'Select a doctor to view messages.';

  @override
  String get patientNoMessagesYet =>
      'No messages yet. Send a message to start the conversation.';

  @override
  String get patientMessageHint => 'Message...';

  @override
  String get patientSessionRequired =>
      'This feature requires an active clinic session. You can still view your past reports below.';

  @override
  String get patientMoreMyMedications => 'My medications';

  @override
  String get patientMoreControlledRx => 'Controlled Rx';

  @override
  String get patientMorePharmacyRequests => 'Pharmacy requests';

  @override
  String get patientMoreLabResults => 'Lab results';

  @override
  String get patientLabDiagnosticResults => 'Lab & diagnostic results';

  @override
  String get patientNoCompletedResults => 'No completed results yet';

  @override
  String get patientDiagnosticTest => 'Diagnostic test';

  @override
  String get patientRadiology => 'Radiology';

  @override
  String get patientLaboratory => 'Laboratory';

  @override
  String get patientPatientId => 'Patient ID';

  @override
  String get patientFullName => 'Full name';

  @override
  String get patientAgeGender => 'Age / Gender';

  @override
  String get patientClinicLabel => 'Clinic';

  @override
  String get patientDoctorLabel => 'Doctor';

  @override
  String get patientDownloadViewFile => 'Download / view file';

  @override
  String get patientNoAnalysisProvided => 'No analysis provided';

  @override
  String get patientExamDate => 'Exam date';

  @override
  String get patientExamType => 'Exam type';

  @override
  String get patientBodyPart => 'Body part';

  @override
  String get patientPartnerMedicalCenter => 'Partner Medical Center';

  @override
  String get patientRateYourVisit => 'Rate your visit';

  @override
  String get patientReminders => 'Reminders';

  @override
  String get patientMedicineName => 'Medicine name';

  @override
  String get patientDoseTimes => 'Dose times (comma)';

  @override
  String get patientAdd => 'Add';

  @override
  String get patientMarkTaken => 'Mark taken';

  @override
  String get patientRemindersWebHint =>
      'Web: reminders stay in-app; use Android/iOS for scheduled push alerts.';

  @override
  String get patientRemindersDeviceHint =>
      'Daily dose alerts are scheduled on this device from your list. Grant notification permission if prompted.';

  @override
  String get patientYourAnalytics => 'Your analytics';

  @override
  String get patientVisitCount => 'Visit count';

  @override
  String get patientActiveMedicationReminders => 'Active medication reminders';

  @override
  String get patientTotalPaymentsSar => 'Total payments (ILS)';

  @override
  String get patientLastCheckupLabel => 'Last checkup label';

  @override
  String get patientGoNearestMedicalCenter =>
      'Go to the nearest medical center';

  @override
  String get patientErAlertFromDoctor => 'تنبيه طوارئ من الطبيب';

  @override
  String get patientPharmacyActivity => 'Pharmacy Activity';

  @override
  String get patientPharmacyActivitySubtitle => 'طلبات الأدوية والمشتريات';

  @override
  String get patientMyRequests => 'My Requests';

  @override
  String get patientPurchased => 'Purchased';

  @override
  String get patientNoMedicationRequests => 'No medication requests yet.';

  @override
  String get patientNoPurchases => 'No purchases recorded yet.';

  @override
  String get patientPaidConfirmed => 'Paid · Confirmed';

  @override
  String get patientPartiallyFulfilled => 'Partially Fulfilled';

  @override
  String get patientPaymentFailed => 'Payment Failed';

  @override
  String get patientPending => 'Pending';

  @override
  String patientRequestedQty(String qty) {
    return 'Requested: $qty';
  }

  @override
  String patientFulfilledUnits(int qty) {
    return 'Fulfilled: $qty units';
  }

  @override
  String patientBackorderUnits(int qty) {
    return 'Backorder: $qty units';
  }

  @override
  String patientUpdatedAt(String dateTime) {
    return 'Updated: $dateTime';
  }

  @override
  String get patientNotifyWhenInStock => 'Notify when in stock';

  @override
  String get patientFindRemainingNearby =>
      'Find Remaining in Nearby Pharmacies';

  @override
  String get patientClinicInternalPharmacy => 'Clinic Internal Pharmacy';

  @override
  String get patientExternalCommunityPharmacy => 'External Community Pharmacy';

  @override
  String patientQty(String qty) {
    return 'Qty: $qty';
  }

  @override
  String patientPrescribingPhysician(String doctor) {
    return 'Prescribing physician: $doctor';
  }

  @override
  String get patientMedication => 'Medication';

  @override
  String get patientBookingFailed => 'Booking failed';

  @override
  String get patientRescheduleSuccess => 'Appointment updated successfully';

  @override
  String get patientBookAppointment => 'Book appointment';

  @override
  String get patientSelectNewAppointment => 'Select new appointment';

  @override
  String get patientClinicSpecialty => 'Clinic / specialty';

  @override
  String get patientSelectSpecialtyFirst => 'Select a specialty first.';

  @override
  String get patientNoDoctorsForSpecialty => 'No doctors for this specialty.';

  @override
  String get patientChooseDoctorTime => 'Choose doctor & time';

  @override
  String get patientBook => 'Book';

  @override
  String get patientConfirmAppointment => 'Confirm';

  @override
  String get patientDoctorOnLeave => 'Doctor on leave';

  @override
  String get patientNoOpenSlots => 'No open slots on this date';

  @override
  String get patientSelectTime => 'Select a time';

  @override
  String get patientAppointmentBookedShort => 'Appointment booked';

  @override
  String get patientSlotFullWaitlistShort =>
      'Slot full — you have been added to the waiting list';

  @override
  String patientYearsShort(String age) {
    return '$age yrs';
  }

  @override
  String get patientEmDash => '—';

  @override
  String get nurseSelectPatientHint =>
      'Select a patient from the Patients or Triage tab.';

  @override
  String get nurseClinicalSummary => 'Clinical summary';

  @override
  String get nurseReadOnlyEssentials => 'Read-only · medical essentials';

  @override
  String get nurseClose => 'Close';

  @override
  String get nurseNoneRecorded => 'None recorded';

  @override
  String get nurseAgeDob => 'Age / date of birth';

  @override
  String get nurseGender => 'Gender';

  @override
  String get nurseBloodType => 'Blood type';

  @override
  String get nurseChronicConditions => 'Chronic conditions';

  @override
  String get nurseActiveAllergies => 'Active allergies';

  @override
  String get nursePrivacyDisclaimer =>
      'Contact details, government IDs, addresses, and financial records are not shown in this view.';

  @override
  String get nursePatientRegistry => 'Patient registry';

  @override
  String get nurseSearchPatientHint =>
      'Search by patient name to view a read-only clinical summary.';

  @override
  String get nurseSearchByName => 'Search by patient name';

  @override
  String get nurseSearchPatients => 'Search patients';

  @override
  String get nurseNoPatientsLoaded =>
      'No patients loaded yet. Enter a name and tap Search.';

  @override
  String get nursePatientFallback => 'Patient';

  @override
  String get nurseTapClinicalSummary => 'Tap to view clinical summary';

  @override
  String get nurseDailyTriageDesk => 'Daily triage desk';

  @override
  String get nurseTriageAccessDenied =>
      'Appointment triage is not enabled for your account. Use Patient registry or contact your supervisor for access.';

  @override
  String get nurseSymptomsForVisit => 'Symptoms (for selected visit)';

  @override
  String get nurseLoadTodaysQueue => 'Load today\'s queue';

  @override
  String get nurseRefreshQueue => 'Refresh queue';

  @override
  String get nurseCheckIn => 'Check in';

  @override
  String get nurseForwardToDoctor => 'Forward to doctor';

  @override
  String get nurseForwardedToDoctor => 'Forwarded to doctor';

  @override
  String get nurseVitalsRecording => 'Vitals recording';

  @override
  String get nurseSelectPatientFirst => 'Select a patient first';

  @override
  String get nurseVitalsSaved => 'Vitals saved to patient record';

  @override
  String get nurseBloodPressure => 'Blood pressure';

  @override
  String get nurseTemperature => 'Temperature °C';

  @override
  String get nurseWeightKg => 'Weight kg';

  @override
  String get nurseHeightCm => 'Height cm';

  @override
  String get nursePulse => 'Pulse';

  @override
  String get nurseOxygen => 'Oxygen %';

  @override
  String get nurseBloodSugar => 'Blood sugar';

  @override
  String get nurseSaveVitals => 'Save vitals';

  @override
  String get nurseTimeline => 'Timeline';

  @override
  String get nurseClinicalNotes => 'Clinical nursing notes';

  @override
  String get nurseNoteType => 'Note type';

  @override
  String get nurseNoteObservation => 'Observation';

  @override
  String get nurseNoteShiftLog => 'Shift log';

  @override
  String get nurseNoteDoctorAlert => 'Doctor alert';

  @override
  String get nurseNoteInitialSymptoms => 'Initial symptoms';

  @override
  String get nurseUrgentForDoctor => 'Urgent for doctor';

  @override
  String get nurseNote => 'Note';

  @override
  String get nurseSaveNote => 'Save note';

  @override
  String get nurseNoteSaved => 'Note saved — visible to treating physician';

  @override
  String get nurseMedicationTreatment => 'Medication & treatment';

  @override
  String get nurseMedication => 'Medication';

  @override
  String get nurseDosage => 'Dosage';

  @override
  String get nurseAdverseReaction => 'Adverse reaction (if any)';

  @override
  String get nurseLogAdministration => 'Log administration';

  @override
  String get nurseDoseLogged => 'Dose logged';

  @override
  String get nurseIncomingLabOrders => 'Incoming lab orders';

  @override
  String get nurseLabOrdersHint =>
      'Doctor requests from the labrequests queue — enter results to finalize.';

  @override
  String get nurseLoadOrders => 'Load orders';

  @override
  String get nurseRefresh => 'Refresh';

  @override
  String nursePendingCount(int count) {
    return '$count pending';
  }

  @override
  String get nurseNoIncomingLabOrders =>
      'No incoming lab orders with status Requested.';

  @override
  String nursePatientId(String id) {
    return 'Patient ID: $id';
  }

  @override
  String nurseTestLabel(String name, String type) {
    return 'Test: $name ($type)';
  }

  @override
  String get nurseEnterResults => 'Enter Results';

  @override
  String nurseResultEntry(String type) {
    return '$type result entry';
  }

  @override
  String get nurseSubmitReport => 'Submit Report';

  @override
  String get nurseCancel => 'Cancel';

  @override
  String get nurseEnterResultBeforeSubmit =>
      'Enter at least one result value before submitting.';

  @override
  String get nurseReportSubmitted =>
      'Report submitted — order completed and locked.';

  @override
  String get nursePrintsAlerts => 'Prints & alert dispatches';

  @override
  String get nurseAlertTitle => 'Alert title';

  @override
  String get nurseMessageBody => 'Message body';

  @override
  String get nurseSendNotification => 'Send patient notification';

  @override
  String get nurseAlertDispatched => 'Alert dispatched to patient';

  @override
  String get nursePrintShiftReference => 'Print shift reference';

  @override
  String get nursePrintBrowserHint =>
      'Use browser print (Ctrl+P) for shift log printout';

  @override
  String get nurseProfileHr => 'Profile & HR contract';

  @override
  String get nurseProfileHint =>
      'Update your personal credentials below. Administrative contract terms are assigned by your clinic administrator.';

  @override
  String get nurseAccountSettings => 'Account settings';

  @override
  String get nurseFullName => 'Full name';

  @override
  String get nurseEmail => 'Email';

  @override
  String get nursePhoneNumber => 'Phone number';

  @override
  String get nurseChangePasswordOptional => 'Change password (optional)';

  @override
  String get nurseCurrentPassword => 'Current password';

  @override
  String get nurseNewPassword => 'New password';

  @override
  String get nurseSaving => 'Saving…';

  @override
  String get nurseSaveChanges => 'Save changes';

  @override
  String get nursePasswordMinLength =>
      'New password must be at least 6 characters';

  @override
  String get nurseCurrentPasswordRequired =>
      'Enter your current password to set a new one';

  @override
  String get nurseAccountSaved => 'Account settings saved';

  @override
  String get nurseAdminContract => 'Administrative contract';

  @override
  String get nurseReadOnly => 'Read only';

  @override
  String get nurseContractReadOnlyHint =>
      'Assigned by clinic admin — cannot be edited here';

  @override
  String get nurseAssignedDepartment => 'ASSIGNED DEPARTMENT';

  @override
  String get nurseShiftTimings => 'SHIFT TIMINGS';

  @override
  String get nurseWorkingDays => 'WORKING DAYS';

  @override
  String get nurseMonthlySalary => 'MONTHLY SALARY';

  @override
  String get nurseNotAssigned => 'Not assigned';

  @override
  String get nursePendingAdminAssignment => 'Pending admin assignment';

  @override
  String get adminDashboardTitle => 'Dashboard & quick stats';

  @override
  String get adminRevenueToday => 'Revenue today';

  @override
  String get adminAppointments => 'Appointments';

  @override
  String get adminPendingBills => 'Pending bills';

  @override
  String get adminStaff => 'Staff';

  @override
  String get adminPatients => 'Patients';

  @override
  String get adminTopDoctor => 'Top doctor';

  @override
  String adminLeaveQueue(int count) {
    return 'Leave queue: $count';
  }

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminRetry => 'Retry';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminReview => 'Review';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminClose => 'Close';

  @override
  String get adminSave => 'Save';

  @override
  String get adminProcessing => 'Processing…';

  @override
  String get adminDoctorAnalyticsTitle => 'Doctor cancellation analytics';

  @override
  String adminRollingWeek(String start, String end) {
    return 'Rolling week: $start → $end';
  }

  @override
  String get adminDoctorName => 'Doctor Name';

  @override
  String get adminTotalAppointments => 'Total Appointments';

  @override
  String get adminCancellations => 'Cancellations';

  @override
  String get adminCancellationRate => 'Cancellation Rate (%)';

  @override
  String get adminTopReason => 'Top Reason';

  @override
  String get adminAlertLevel => 'Alert Level';

  @override
  String get adminAlertCritical => 'Critical review';

  @override
  String get adminAlertAdmin => 'Admin alert';

  @override
  String get adminAlertWarning => 'Low warning';

  @override
  String get adminAlertNormal => 'Normal';

  @override
  String get adminActionRequired =>
      'Action required: urgent review recommended; booking restrictions may apply.';

  @override
  String get adminLegendNormal => 'Normal < 15%';

  @override
  String get adminLegendWarning => 'Low warning 15–20%';

  @override
  String get adminLegendAlert => 'Admin alert > 20%';

  @override
  String get adminLegendCritical => 'Critical > 30%';

  @override
  String get adminDepartmentsWizard => 'Departments wizard';

  @override
  String get adminCreateDepartment => 'Create department';

  @override
  String get adminDepartmentName => 'Department name (e.g. Bones, Pediatrics)';

  @override
  String get adminSearchDoctors => 'Search doctors';

  @override
  String get adminSupervisorDoctor => 'Supervisor doctor';

  @override
  String get adminNoneOption => '— None —';

  @override
  String get adminCreateDepartmentBtn => 'Create department';

  @override
  String get adminDepartmentCreated => 'Department created';

  @override
  String get adminAddClinic => 'Add clinic inside department';

  @override
  String get adminSelectDepartment => 'Select department';

  @override
  String get adminClinicName => 'Clinic name';

  @override
  String get adminPhone => 'Phone';

  @override
  String get adminRoomNumber => 'Room number (optional)';

  @override
  String get adminAddClinicBtn => 'Add clinic to department';

  @override
  String get adminClinicAdded => 'Clinic added to department';

  @override
  String get adminRegisteredDepartments => 'Registered departments';

  @override
  String get adminNoDepartments => 'No departments yet. Create one above.';

  @override
  String get adminNoSupervisor => 'No supervisor assigned';

  @override
  String adminSupervisor(String name) {
    return 'Supervisor: $name';
  }

  @override
  String adminClinicsCount(int count) {
    return 'Clinics ($count)';
  }

  @override
  String get adminNoClinics => 'No clinics registered yet.';

  @override
  String get adminDepartmentFallback => 'Department';

  @override
  String get adminClinicFallback => 'Clinic';

  @override
  String adminRoom(String room) {
    return 'Room $room';
  }

  @override
  String get adminStaffOnboarding => 'Staff & clinical onboarding';

  @override
  String get adminSearchActiveStaff => 'Search active staff';

  @override
  String adminPendingRegistrations(int count) {
    return 'Pending doctor & staff requests ($count)';
  }

  @override
  String get adminNoPendingRegistrations =>
      'No pending doctor or legacy staff registration requests.';

  @override
  String get adminApplicant => 'Applicant';

  @override
  String get adminRole => 'Role';

  @override
  String get adminSpecialty => 'Specialty';

  @override
  String get adminApplied => 'Applied';

  @override
  String get adminRegistrationApproved =>
      'Registration approved — account activated';

  @override
  String get adminRegistrationRejected => 'Registration rejected';

  @override
  String adminPendingScheduleChanges(int count) {
    return 'Pending doctor schedule changes ($count)';
  }

  @override
  String get adminNoPendingSchedule =>
      'No pending working-hours change requests.';

  @override
  String get adminSchedulePreview => 'Schedule preview';

  @override
  String get adminRequested => 'Requested';

  @override
  String adminActiveDays(int count) {
    return '$count active day(s)';
  }

  @override
  String get adminScheduleApproved =>
      'Schedule approved — doctor hours updated';

  @override
  String get adminScheduleRejected => 'Schedule change rejected';

  @override
  String adminPendingNurseApps(int count) {
    return 'Pending nurse applications ($count)';
  }

  @override
  String get adminNoPendingStaff => 'No pending clinical staff registrations.';

  @override
  String get adminLicense => 'License';

  @override
  String get adminActiveStaffRoster => 'Active staff roster';

  @override
  String get adminNoStaffRecords => 'No staff records.';

  @override
  String get adminName => 'Name';

  @override
  String get adminDepartment => 'Department';

  @override
  String get adminStatus => 'Status';

  @override
  String adminReviewApplicant(String name) {
    return 'Review: $name';
  }

  @override
  String get adminApproveActivate => 'Approve & activate';

  @override
  String get adminStaffApproved => 'Staff approved and account activated';

  @override
  String get adminPersonal => 'Personal';

  @override
  String get adminProfessional => 'Professional';

  @override
  String get adminUsername => 'Username';

  @override
  String get adminBirthDate => 'Birth date';

  @override
  String get adminEmployeeId => 'Employee ID';

  @override
  String adminExperienceYears(int years) {
    return '$years years';
  }

  @override
  String get adminEducation => 'Education';

  @override
  String get adminUniversity => 'University';

  @override
  String get adminLicenseNumber => 'License #';

  @override
  String get adminLicenseExpiry => 'License expiry';

  @override
  String get adminEmployment => 'Employment';

  @override
  String get adminAdminAssignment => 'Administrative assignment';

  @override
  String get adminMonthlySalary => 'Monthly salary (optional)';

  @override
  String get adminWorkingSchedule => 'Working schedule';

  @override
  String get adminShiftStart => 'Start (HH:mm)';

  @override
  String get adminShiftEnd => 'End (HH:mm)';

  @override
  String get adminPermissionFlags => 'Permission flags';

  @override
  String get adminPatientDirectory => 'Patient directory';

  @override
  String get adminUnpaidOnly => 'Unpaid balances only';

  @override
  String adminUnpaidBalance(String amount) {
    return 'unpaid $amount';
  }

  @override
  String get adminAppointmentPlanner => 'Appointment planner';

  @override
  String get adminAttendanceLeave => 'Attendance & leave';

  @override
  String get adminRejectionReason => 'Rejection reason (optional)';

  @override
  String get adminStaffLeave => 'Staff leave';

  @override
  String get adminDoctorLeave => 'Doctor leave';

  @override
  String get adminLeave => 'Leave';

  @override
  String get adminMedicalRecords => 'Medical records tracker';

  @override
  String get adminRecordFallback => 'Record';

  @override
  String adminInsurance(String status) {
    return 'Insurance: $status';
  }

  @override
  String get adminInvoicingBilling => 'Invoicing & billing';

  @override
  String get adminPaidTotal => 'Paid total';

  @override
  String get adminPending => 'Pending';

  @override
  String get adminLateCycles => 'Late cycles';

  @override
  String get adminGranularPermissions => 'Granular access permissions';

  @override
  String get adminSaveMatrix => 'Save matrix';

  @override
  String get adminPermissionsSaved => 'Permissions saved';

  @override
  String get adminPharmacyLabInventory => 'Pharmacy & lab inventory';

  @override
  String get adminDrugSkus => 'Drug SKUs';

  @override
  String get adminAssaysInProgress => 'Assays in progress';

  @override
  String get adminLowStockAlerts => 'Low stock alerts';

  @override
  String get adminSimulateReplenishment => 'Simulate replenishment (+1 SKU)';

  @override
  String get adminAuditLog => 'Audit activity log';

  @override
  String get adminGlobalBroadcast => 'Global broadcast';

  @override
  String get adminAudience => 'Audience';

  @override
  String get adminAudienceAll => 'Staff + patients';

  @override
  String get adminAudienceStaff => 'Staff only';

  @override
  String get adminAudiencePatients => 'Patients only';

  @override
  String get adminTitle => 'Title';

  @override
  String get adminMessage => 'Message';

  @override
  String get adminSendNotification => 'Send notification';

  @override
  String get adminBroadcastSent => 'Broadcast sent';

  @override
  String get adminSystemConfig => 'System configuration';

  @override
  String get adminDefaultCurrency => 'Default currency';

  @override
  String get adminLocale => 'Locale (en/ar)';

  @override
  String get adminCancellationPolicy => 'Cancellation penalty policy';

  @override
  String get adminSaveConfiguration => 'Save configuration';

  @override
  String get adminSettingsSaved => 'Settings saved';

  @override
  String get adminRequestBackup => 'Request database backup';

  @override
  String get adminBackupLogged =>
      'Backup request logged — implement server export hook as needed.';

  @override
  String get adminUnassigned => 'Unassigned';

  @override
  String get adminGeneralPractice => 'General Practice';

  @override
  String get pharmacistDashboardSubtitle =>
      'Enterprise inventory command center';

  @override
  String get pharmacistTotalDrugs => 'Total Drugs';

  @override
  String get pharmacistAvailable => 'Available';

  @override
  String get pharmacistLowStock => 'Low Stock';

  @override
  String get pharmacistOutOfStock => 'Out of Stock';

  @override
  String get pharmacistQuickAlerts => 'Quick Alerts';

  @override
  String get pharmacistNoCriticalAlerts => 'No critical alerts right now.';

  @override
  String pharmacistDispensed(int qty, String name) {
    return 'Dispensed $qty × $name';
  }

  @override
  String get pharmacistQuantity => 'Quantity';

  @override
  String get pharmacistApproveProcess => 'Approve & Process Payment';

  @override
  String get pharmacistSaveSettings => 'Save Settings';

  @override
  String get pharmacistPharmacyLocation => 'Pharmacy Location';

  @override
  String get pharmacistNameEmailRequired => 'Name and email are required';

  @override
  String get pharmacistProfileUpdated => 'Profile updated';

  @override
  String get pharmacistUpdateProfile => 'Update Profile';

  @override
  String get pharmacistAddNewDrug => 'Add New Drug';

  @override
  String get pharmacistDrugName => 'Drug Name';

  @override
  String get pharmacistCategory => 'Category';

  @override
  String get pharmacistStockQty => 'Stock Qty';

  @override
  String get pharmacistPrice => 'Price';

  @override
  String get pharmacistManufacturer => 'Manufacturer';

  @override
  String get pharmacistExpiryDate => 'Expiry Date';

  @override
  String get pharmacistRequiresPrescription => 'Requires Prescription';

  @override
  String get pharmacistRxRequiredHint =>
      'If enabled, this medication will require an active physician prescription before purchase.';

  @override
  String get pharmacistAddToInventory => 'Add to Inventory';

  @override
  String get pharmacistDrugAdded => 'Drug added successfully.';

  @override
  String pharmacistEditStock(String name) {
    return 'Edit Stock — $name';
  }

  @override
  String get pharmacistStockQuantity => 'Stock quantity';

  @override
  String get pharmacistQty => 'Qty';

  @override
  String get pharmacistSaveChanges => 'Save Changes';

  @override
  String get pharmacistStockUpdated => 'Stock updated.';

  @override
  String get pharmacistRemoveInventoryTitle => 'Remove from inventory?';

  @override
  String pharmacistRemoveInventoryBody(String name) {
    return 'Delete $name from this pharmacy stock?';
  }

  @override
  String get pharmacistDelete => 'Delete';

  @override
  String get pharmacistRemovedFromInventory => 'Removed from inventory.';

  @override
  String get pharmacistInventorySubtitle =>
      'Live catalog — search, update, and manage stock';

  @override
  String get pharmacistSearchDrugs => 'Search drugs';

  @override
  String get pharmacistSearchHint => 'Type a letter — filters instantly…';

  @override
  String get pharmacistAddNewDrugBtn => '+ Add New Drug';

  @override
  String pharmacistShowingAll(int count) {
    return 'Showing all $count medications';
  }

  @override
  String pharmacistShowingMatches(int shown, int total) {
    return 'Showing $shown of $total matches';
  }

  @override
  String get pharmacistRefreshCatalog => 'Refresh catalog';

  @override
  String get pharmacistNoInventory => 'No inventory loaded.';

  @override
  String pharmacistNoDrugsMatch(String query) {
    return 'No drugs match \"$query\".';
  }

  @override
  String get pharmacistColDrugName => 'Drug Name';

  @override
  String get pharmacistColCategory => 'Category';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authSelectYourRole => 'Select Your Role';

  @override
  String get authChooseHowToUse => 'Choose how you will use Rafeeq';

  @override
  String authFacility(String name) {
    return 'Facility: $name';
  }

  @override
  String get authRolePatient => 'Patient';

  @override
  String get authRoleDoctor => 'Doctor';

  @override
  String get authRolePharmacist => 'Pharmacist';

  @override
  String get authRoleNurse => 'Nurse';

  @override
  String get authRoleLabTech => 'Laboratory Technician';

  @override
  String get authRoleRadiology => 'Radiology Technologist';

  @override
  String get authSelectFacilityFirst =>
      'Please select your facility before submitting.';

  @override
  String get authDoctorDetails => 'Doctor details';

  @override
  String get authDoctorRegistration => 'Doctor registration';

  @override
  String get authLabTechRegistration => 'Laboratory technician registration';

  @override
  String get authRadiologyRegistration => 'Radiology technologist registration';

  @override
  String get authSignupPendingApproval =>
      'Complete all sections — pending admin approval';

  @override
  String get authDiscoverFacilities => 'Discover Facilities';

  @override
  String get authChooseFacility => 'Choose a hospital / clinic to continue';

  @override
  String get authSearchFacilityHint => 'Search by name, specialty, or location';

  @override
  String get authNoFacilitiesFound => 'No facilities found';

  @override
  String get authFacilityNameRequired => 'Enter the clinic / hospital name.';

  @override
  String get authConfirmLocation =>
      'Confirm your facility location on the map.';

  @override
  String get authCompleteAdminFields => 'Complete all primary admin fields.';

  @override
  String get authInvalidMapLink => 'Invalid map link.';

  @override
  String get authCouldNotOpenMap => 'Could not open map link.';

  @override
  String get authPortalPatient => 'Patient';

  @override
  String get authPortalPatientSubtitle =>
      'Portal, appointments, and health records';

  @override
  String get authPortalDoctor => 'Doctor';

  @override
  String get authPortalDoctorSubtitle => 'Sign in or request physician access';

  @override
  String get authPortalPharmacist => 'Pharmacist';

  @override
  String get authPortalPharmacistSubtitle =>
      'Pharmacy module is enabled for this facility';

  @override
  String get authPortalLabTech => 'Lab technician';

  @override
  String get authPortalLabTechSubtitle => 'Laboratory under Lab & Radiology';

  @override
  String get authPortalRadiologist => 'Radiologist';

  @override
  String get authPortalRadiologistSubtitle => 'Imaging under Lab & Radiology';

  @override
  String get authPortalEmergency => 'Emergency staff';

  @override
  String get authPortalEmergencySubtitle => 'Operations / emergency coverage';

  @override
  String get authNurseDashboard => 'Nurse Dashboard';

  @override
  String get authNurseDashboardSubtitle =>
      'Vitals & patient monitoring (placeholder).';

  @override
  String get authPharmacistDashboard => 'Pharmacist Dashboard';

  @override
  String get authPharmacistDashboardSubtitle =>
      'Fulfill electronic prescriptions (placeholder).';

  @override
  String get authInternDashboard => 'Intern/Trainee Dashboard';

  @override
  String get authInternDashboardSubtitle =>
      'View-only access to cases (placeholder).';

  @override
  String get authStaffDashboard => 'Staff/Operations Dashboard';

  @override
  String get authStaffDashboardSubtitle =>
      'Tasks & facility operations (placeholder).';

  @override
  String authUserId(String id) {
    return 'User ID: $id';
  }

  @override
  String get authReceptionistPortal => 'Receptionist Portal';

  @override
  String get authFrontDesk => 'Front Desk';

  @override
  String get authDailySchedule => 'Daily Schedule';

  @override
  String get authPatientRegistration => 'Patient Registration';

  @override
  String get authBilling => 'Billing';

  @override
  String get authPharmacyPortal => 'Pharmacy Portal';

  @override
  String get authPrescriptionsQueue => 'Prescriptions Queue';

  @override
  String get authInventoryManagement => 'Inventory Management';

  @override
  String get authMedicationHistory => 'Medication History';

  @override
  String get authLearningPortal => 'Learning Portal';

  @override
  String get authObservationMode => 'Observation Mode';

  @override
  String get authMedicalLibrary => 'Medical Library';

  @override
  String get authTrainingSchedule => 'Training Schedule';

  @override
  String get authPatientDetails => 'Patient Details';

  @override
  String get doctorPatientFallback => 'Patient';

  @override
  String get doctorMedicationFallback => 'Medication';

  @override
  String get doctorAdrUrgent => 'URGENT — review immediately';

  @override
  String get doctorAdrReviewed => 'REVIEWED';

  @override
  String doctorAdrPatientRef(String ref) {
    return 'Patient ref: $ref';
  }

  @override
  String get doctorAdrTapDetail => 'Tap for CDSS detail';

  @override
  String get doctorProposeSuspension => 'Propose suspension';

  @override
  String get doctorPatientMissingExam =>
      'Patient record is missing — cannot open examination panel.';

  @override
  String get doctorNoCancelledAppointments => 'No cancelled appointments';

  @override
  String get doctorNoActiveAppointments => 'No active appointments';

  @override
  String get doctorTabActive => 'Active';

  @override
  String get doctorTabCancelled => 'Cancelled';

  @override
  String get doctorPostpone => 'Postpone';

  @override
  String get doctorCancelAppointment => 'Cancel Appointment';

  @override
  String get doctorOpenExamination => 'Open Examination';

  @override
  String get doctorTerminate => 'Terminate';

  @override
  String get doctorViewMedicalRecord => 'View Medical Record';

  @override
  String get doctorSelectReason => 'Select Reason';

  @override
  String get doctorReason => 'Reason';

  @override
  String get doctorNotesOptional => 'Notes (optional)';

  @override
  String get doctorBack => 'Back';

  @override
  String get doctorConfirmCancel => 'Confirm cancel';

  @override
  String get doctorAppointmentCancelled =>
      'Appointment cancelled — patient notified';

  @override
  String get doctorCancelled => 'Cancelled';

  @override
  String get doctorPatientIdMissingExam =>
      'Patient ID missing on this appointment — cannot open examination.';

  @override
  String get doctorPatientIdMissingStart =>
      'Patient ID missing on this appointment — cannot start examination.';

  @override
  String get doctorPatientIdMissingRecord =>
      'Patient ID missing — cannot open medical record.';

  @override
  String get doctorSearchPatients => 'Search patients';

  @override
  String get doctorWarning => 'WARNING';

  @override
  String get doctorProceedAnyway => 'Proceed anyway';

  @override
  String get doctorLabTestNameRequired => 'Please enter a lab test name.';

  @override
  String get doctorLabOrderSubmitted =>
      'Order submitted to laboratory successfully!';

  @override
  String get doctorStudyNameRequired => 'Please enter a study name.';

  @override
  String get doctorImagingOrderSubmitted =>
      'Order submitted to radiology successfully!';

  @override
  String get doctorEnterConditionPlan =>
      'Please enter at least the Condition and Treatment Plan.';

  @override
  String get doctorSessionUpdatedDiagnosisRx =>
      'Active session updated — diagnosis and prescription saved.';

  @override
  String get doctorSessionUpdatedDiagnosis =>
      'Active session updated — diagnosis saved.';

  @override
  String get doctorRecordSavedDiagnosisRx =>
      'Medical record saved — diagnosis and prescription submitted.';

  @override
  String get doctorRecordSavedDiagnosis =>
      'Medical record saved — diagnosis submitted.';
}
