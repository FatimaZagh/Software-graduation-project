function isArabicLocale(locale) {
  const code = String(locale || "en").toLowerCase();
  return code === "ar" || code.startsWith("ar-");
}

function splitOrderNotificationBody({ medicationName, fulfilledQty, backorderQty, locale }) {
  const name = medicationName || "medication";
  if (isArabicLocale(locale)) {
    return (
      `متوفر فقط ${fulfilledQty} علب من دواء ${name} في صيدلية العيادة. ` +
      `تم تحويل الـ ${backorderQty} المتبقية كطلب مسبق (Backorder). ` +
      `يمكنك البحث في الصيدليات المجاورة لشراء باقي الكمية.`
    );
  }
  return (
    `Only ${fulfilledQty} units of ${name} are available at the clinic pharmacy. ` +
    `The remaining ${backorderQty} units have been placed on Backorder. ` +
    `You can browse nearby pharmacies to purchase the rest.`
  );
}

function splitOrderNotificationTitle(locale) {
  return isArabicLocale(locale) ? "تنفيذ جزئي للطلب" : "Partial order fulfillment";
}

function paymentSuccessTitle(locale) {
  return isArabicLocale(locale) ? "تم الدفع بنجاح" : "Payment successful — order confirmed";
}

function paymentSuccessBody({ medicationName, amount, pharmacyName, locale }) {
  if (isArabicLocale(locale)) {
    return (
      `تمت معالجة دفعتك البالغة ${amount} شيكل لـ ${medicationName} بنجاح. ` +
      `تم حجز المخزون في ${pharmacyName || "الصيدلية"}.`
    );
  }
  return (
    `Your payment of ${amount} ILS for ${medicationName} was processed successfully. ` +
    `Stock has been reserved at ${pharmacyName || "the pharmacy"}.`
  );
}

module.exports = {
  isArabicLocale,
  splitOrderNotificationBody,
  splitOrderNotificationTitle,
  paymentSuccessTitle,
  paymentSuccessBody,
};
