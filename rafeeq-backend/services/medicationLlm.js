/**
 * LLM fallback — OpenRouter chat completions (verified free model hardcoded).
 */

const { getOpenRouterApiKey } = require("../config/loadEnv");

/**
 * Verified free models on OpenRouter (llama-3-8b-instruct:free returns 404 as of 2026).
 * Primary is hardcoded; fallbacks tried in order if rate-limited.
 */
const OPENROUTER_FREE_MODEL = "deepseek/deepseek-v4-flash:free";
const OPENROUTER_FREE_MODEL_FALLBACKS = [
  "deepseek/deepseek-v4-flash:free",
  "google/gemma-4-26b-a4b-it:free",
  "openrouter/free",
];
const OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions";
const OPENROUTER_REFERER = "http://localhost:3000";
const OPENROUTER_APP_TITLE = "Rafeeq Medical App";

function buildPharmaceuticalPrompt(medicationName) {
  const med = String(medicationName || "").trim();
  return [
    "You are a dynamic pharmaceutical assistant for Project Rafeeq.",
    `Provide uses, side effects, food interactions, and warnings tailored strictly and exclusively to the specific chemical properties of ${med}.`,
    "Do NOT output general placeholder text.",
    "You must NEVER suggest dosage changes.",
    "You must NEVER recommend modifying an active prescription.",
    "You must NEVER replace clinical physician advice.",
    "If the user asks for diagnosis, switching drugs, or unrelated medical advice, respond only with:",
    `'I am only able to discuss information regarding ${med}. For diagnostics or other medical questions, please consult your doctor.'`,
    "Use plain English with clear section headings.",
  ].join(" ");
}

function buildPharmacistSystemPrompt(medicationName, { contextLocked = false, followUp = false } = {}) {
  const base = buildPharmaceuticalPrompt(medicationName);
  const med = String(medicationName || "").trim();

  if (contextLocked || followUp) {
    return [
      base,
      `The patient selected ${med} and asked a follow-up question.`,
      `Answer ONLY about ${med}. Include only sections relevant to the question.`,
    ].join(" ");
  }

  return [
    base,
    "Structure the response with: Uses & Indications, Common Side Effects, Food/Drug Interactions, Standard Dosage Warning.",
  ].join(" ");
}

function buildMedicationUserPrompt(medicationName, question) {
  const med = String(medicationName || "").trim();
  const q = String(question || "").trim();

  if (q) {
    return [
      `Medication (from patient selection): ${med}`,
      `Question: ${q}`,
      `Respond with facts specific to ${med} only.`,
    ].join("\n");
  }

  return `Provide a complete educational profile for the medication: ${med}. Every detail must be specific to ${med}.`;
}

/**
 * Parse OpenRouter success body: choices[0].message.content
 * @param {object|null} data
 * @returns {string|null}
 */
function extractChatCompletionText(data) {
  if (!data?.choices || !Array.isArray(data.choices) || data.choices.length === 0) {
    return null;
  }
  const first = data.choices[0];
  if (!first?.message?.content) {
    return null;
  }
  const text = String(first.message.content).trim();
  return text || null;
}

function logOpenRouterError(data, httpStatus) {
  if (data?.error) {
    console.error("[OpenRouter] error object:", data.error);
  } else if (httpStatus) {
    console.error("[OpenRouter] HTTP", httpStatus, data);
  }
}

function openRouterErrorDetail(data, httpStatus) {
  logOpenRouterError(data, httpStatus);
  if (data?.error?.message) return String(data.error.message);
  if (typeof data?.error === "string") return data.error;
  if (httpStatus === 404) {
    return "Model or endpoint not found on OpenRouter.";
  }
  return httpStatus ? `HTTP ${httpStatus}` : "Unknown OpenRouter error";
}

async function callOpenRouterOnce(apiKey, model, system, prompt) {
  const response = await fetch(OPENROUTER_CHAT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": OPENROUTER_REFERER,
      "X-Title": OPENROUTER_APP_TITLE,
    },
    body: JSON.stringify({
      model,
      temperature: 0.25,
      messages: [
        { role: "system", content: system },
        { role: "user", content: prompt },
      ],
    }),
  });

  const data = await response.json();

  if (!response.ok || data?.error) {
    const detail = openRouterErrorDetail(data, response.status);
    return { ok: false, text: null, error: detail, model, status: response.status };
  }

  const text = extractChatCompletionText(data);
  if (!text) {
    console.error(
      `[OpenRouter] Model ${model} — empty choices:`,
      JSON.stringify(data).slice(0, 400)
    );
    return { ok: false, text: null, error: "Empty message content", model, status: response.status };
  }

  return { ok: true, text, error: null, model, status: response.status };
}

async function callOpenRouter(systemPrompt, userContent) {
  const apiKey = getOpenRouterApiKey();
  if (!apiKey) {
    return {
      text: null,
      error: "OPENROUTER_API_KEY is not configured. Add it to rafeeq-backend/.env and restart the server.",
    };
  }

  const prompt = String(userContent || "").trim();
  const system =
    String(systemPrompt || "").trim() ||
    "You are a pharmaceutical assistant for Project Rafeeq.";

  const modelsToTry = [
    OPENROUTER_FREE_MODEL,
    ...OPENROUTER_FREE_MODEL_FALLBACKS.filter((m) => m !== OPENROUTER_FREE_MODEL),
  ];

  let lastError = "No OpenRouter model succeeded.";

  try {
    for (const model of modelsToTry) {
      const result = await callOpenRouterOnce(apiKey, model, system, prompt);
      if (result.ok && result.text) {
        return { text: result.text, error: null, model: result.model };
      }
      lastError = result.error || lastError;
      console.warn(`[OpenRouter] Model ${model} failed:`, lastError);
      if (result.status === 404) continue;
      if (result.status === 429) continue;
    }

    return { text: null, error: lastError };
  } catch (err) {
    console.error("[OpenRouter] Network failure:", err?.message || err);
    return {
      text: null,
      error: `OpenRouter request failed: ${err?.message || "network error"}`,
    };
  }
}

function buildLlmFailureAnswer(medicationName) {
  const med = String(medicationName || "").trim() || "this medication";
  return {
    answer: `We could not retrieve AI information for **${med}** right now. Please try again shortly or consult your pharmacist.`,
    matchedRuleId: "llm_error",
    confidence: "llm_failed",
    source: "error",
    medicationName: med,
    currentMedication: med,
    error: true,
  };
}

/**
 * OpenRouter LLM for medication education (FDA fallback path).
 */
async function generateMedicationLlmAnswer(opts = {}) {
  const { medicationName, question, contextLocked, currentMedication, followUp } = opts;
  const med = String(currentMedication || medicationName || "").trim();
  if (!med) {
    return buildLlmFailureAnswer("");
  }

  const systemPrompt = buildPharmacistSystemPrompt(med, {
    contextLocked: Boolean(contextLocked),
    followUp: Boolean(followUp || question),
  });
  const userContent = buildMedicationUserPrompt(med, question);

  const openRouter = await callOpenRouter(systemPrompt, userContent);
  if (openRouter.text) {
    return {
      answer: openRouter.text,
      matchedRuleId: "openrouter",
      confidence: contextLocked ? "openrouter_context_locked" : "openrouter",
      source: "openrouter",
      model: openRouter.model,
      medicationName: med,
      currentMedication: med,
      contextLocked: Boolean(contextLocked),
      error: false,
    };
  }

  if (openRouter.error?.includes("OPENROUTER_API_KEY")) {
    return {
      ...buildLlmFailureAnswer(med),
      answer: `AI assistant is not configured on the server. Please contact support. (${med})`,
    };
  }

  console.error("[OpenRouter] Medication lookup failed for", med, ":", openRouter.error);
  return buildLlmFailureAnswer(med);
}

module.exports = {
  buildPharmaceuticalPrompt,
  buildGeminiPharmaceuticalPrompt: buildPharmaceuticalPrompt,
  buildPharmacistSystemPrompt,
  generateMedicationLlmAnswer,
  buildMedicationUserPrompt,
  buildLlmFailureAnswer,
  callOpenRouter,
  extractChatCompletionText,
  OPENROUTER_FREE_MODEL,
  OPENROUTER_CHAT_URL,
};
