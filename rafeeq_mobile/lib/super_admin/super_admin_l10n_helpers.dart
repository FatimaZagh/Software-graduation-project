import '../l10n/app_localizations.dart';

String superAdminTranslateStatus(AppLocalizations l10n, String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return l10n.superAdminFilterActive;
    case 'pending':
      return l10n.superAdminFilterPending;
    case 'suspended':
      return l10n.superAdminFilterSuspended;
    default:
      return status;
  }
}

String superAdminTranslateSubscription(AppLocalizations l10n, String subscription) {
  switch (subscription.toLowerCase()) {
    case 'free':
      return l10n.superAdminSubscriptionFree;
    case 'premium':
      return l10n.superAdminSubscriptionPremium;
    case 'enterprise':
      return l10n.superAdminSubscriptionEnterprise;
    default:
      return subscription;
  }
}

String superAdminTranslateInventoryStatus(AppLocalizations l10n, String status) {
  final key = status.toLowerCase().replaceAll(' ', '_');
  switch (key) {
    case 'out_of_stock':
      return l10n.superAdminInventoryOutOfStock;
    case 'low_stock':
      return l10n.superAdminInventoryLowStock;
    case 'available':
      return l10n.superAdminInventoryAvailable;
    default:
      return status;
  }
}
