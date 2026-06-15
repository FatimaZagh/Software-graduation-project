/**
 * Structured logging for Rafeeq AI Medical Assistant (POST /api/ai/chat).
 */

function timestamp() {
  return new Date().toISOString();
}

function prefix(tag) {
  return `[Rafeeq AI ${timestamp()}] [${tag}]`;
}

function logApiKeyStatus({ geminiKey, source }) {
  const present = Boolean(geminiKey && geminiKey.length > 0);
  const masked = present
    ? `${geminiKey.slice(0, 4)}…${geminiKey.slice(-4)} (len=${geminiKey.length})`
    : "(empty)";
  console.log(prefix("API_KEY"), {
    source: source || "process.env.GEMINI_API_KEY",
    loaded: present,
    maskedPreview: masked,
  });
  if (!present) {
    console.warn(prefix("API_KEY"), "GEMINI_API_KEY is not set — Gemini calls will fail.");
  }
}

function logRequest({ message, patientContext, ip }) {
  console.log(prefix("REQUEST"), {
    messagePreview: String(message || "").slice(0, 120),
    messageLength: String(message || "").length,
    hasPatientContext: Boolean(patientContext && Object.keys(patientContext).length),
    ip: ip || "unknown",
  });
}

function logValidationFailure({ reason, query }) {
  console.warn(prefix("VALIDATION"), {
    outcome: "blocked",
    reason,
    queryPreview: String(query || "").slice(0, 80),
  });
}

function logValidationPass({ scenario, query }) {
  console.log(prefix("VALIDATION"), {
    outcome: "passed",
    scenario,
    queryPreview: String(query || "").slice(0, 80),
  });
}

function logGeminiRequest({ model, messagePreview, promptLength, systemPromptLength }) {
  console.log(prefix("GEMINI_REQUEST"), {
    model,
    promptLength: promptLength ?? 0,
    systemPromptLength: systemPromptLength ?? 0,
    messagePreview: String(messagePreview || "").slice(0, 120),
  });
}

function logGeminiResponse({ model, replyPreview, replyLength }) {
  console.log(prefix("GEMINI_RESPONSE"), {
    model,
    replyLength: replyLength ?? 0,
    replyPreview: String(replyPreview || "").slice(0, 160),
  });
}

function logNetworkError(err, context = {}) {
  console.error(prefix("NETWORK_ERROR"), context);
  console.error(prefix("NETWORK_ERROR"), err);
  if (err?.stack) {
    console.error(prefix("NETWORK_ERROR_STACK"), err.stack);
  }
}

function logException(err, context = {}) {
  console.error(prefix("EXCEPTION"), context);
  console.error(prefix("EXCEPTION"), err);
  if (err?.stack) {
    console.error(prefix("EXCEPTION_STACK"), err.stack);
  }
}

function logResponseSent({ statusCode, success, replyPreview, model }) {
  console.log(prefix("RESPONSE"), {
    statusCode,
    success,
    model: model || "n/a",
    replyPreview: String(replyPreview || "").slice(0, 120),
  });
}

module.exports = {
  logApiKeyStatus,
  logRequest,
  logValidationFailure,
  logValidationPass,
  logGeminiRequest,
  logGeminiResponse,
  logNetworkError,
  logException,
  logResponseSent,
};
