require("../config/loadEnv");

const { GoogleGenerativeAI } = require("@google/generative-ai");
const aiLog = require("../utils/aiChatLogger");

const OUT_OF_SCOPE_REPLY =
  "I'm designed to assist only with healthcare, medications, prescriptions, pharmacies, appointments, and medical-related questions.";

const SERVICE_ERROR_REPLY =
  "Temporary AI service error. Please try again or consult your healthcare provider.";

const GEMINI_MODELS = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"];

const MEDICAL_KEYWORDS = [
  "medication", "medicine", "medicinal", "medical", "drug", "prescription", "rx", "dose", "dosage",
  "tablet", "capsule", "pill", "injection", "antibiotic", "side effect", "side effects", "adverse",
  "interaction", "interactions", "contraindication", "allergy", "allergies", "allergic", "symptom",
  "symptoms", "disease", "illness", "condition", "diagnosis", "doctor", "physician", "nurse",
  "pharmacist", "appointment", "clinic", "hospital", "pharmacy", "dispense", "refill", "treatment",
  "therapy", "surgery", "infection", "fever", "pain", "headache", "nausea", "rash", "vitals",
  "blood pressure", "diabetes", "asthma", "hypertension", "vaccine", "pregnancy", "overdose",
  "health", "healthcare", "ehr", "prescribed", "amoxicillin", "ibuprofen", "paracetamol",
  "acetaminophen", "metformin", "omeprazole", "aspirin",
  "دواء", "أدوية", "علاج", "روشتة", "وصفة", "جرعة", "عرض جانبي", "أعراض", "مرض", "طبيب",
  "موعد", "عيادة", "مستشفى", "صيدلية", "حساسية", "تفاعل", "وصفة طبية", "صحة",
];

const NON_MEDICAL_SIGNALS = [
  "python", "javascript", "typescript", "java", "c++", "html", "css", "react", "node.js",
  "programming", "coding", "write a function", "sort an array", "algorithm", "debug my code",
  "solve this equation", "algebra", "calculus", "trigonometry", "physics homework",
  "chemistry homework", "politics", "election", "president", "football", "soccer", "nba",
  "movie", "netflix", "game", "gaming", "religion", "world war", "ancient history",
  "stock market", "crypto", "bitcoin", "برمجة", "كود", "بايثون", "رياضيات", "فيزياء",
  "سياسة", "كرة", "فيلم", "لعبة", "تاريخ", "دين",
];

const HEALTHCARE_SYSTEM_PROMPT = `You are Rafeeq AI Medical Assistant.

You are a healthcare support assistant integrated inside a clinic and pharmacy platform.

You may answer questions about:
* Medications
* Prescriptions
* Drug interactions
* Side effects
* Symptoms
* Diseases
* Appointments
* Pharmacies
* Healthcare services

You must never answer questions unrelated to healthcare.

If a question is outside healthcare scope, politely respond:
"I'm designed to assist only with healthcare and medical-related questions."

Never provide definitive diagnosis.
Never replace a licensed physician.
Never instruct users to stop prescribed medications.
Always recommend consulting a healthcare professional for treatment decisions.`;

const MEDICATION_SECTIONS_INSTRUCTION = `
Structure your response with these clearly labeled sections:
1. Medication Overview
2. Uses & Indications
3. Common Side Effects
4. Food Interactions
5. Drug Interactions
6. Warnings & Precautions
7. Storage Instructions

Use clean section headings and bullet points. Be patient-friendly and concise.`;

function resolveGeminiApiKey() {
  return String(process.env.GEMINI_API_KEY || "").trim();
}

aiLog.logApiKeyStatus({ geminiKey: resolveGeminiApiKey(), source: "process.env.GEMINI_API_KEY" });

function hasMedicalIntent(message) {
  const lower = message.toLowerCase();
  if (MEDICAL_KEYWORDS.some((kw) => lower.includes(kw))) return true;
  if (/\b[a-z]{4,}(cillin|mycin|olol|pril|statin|zepam|azole|idine)\b/i.test(message)) return true;
  if (/provide patient-friendly information for/i.test(lower)) return true;
  return false;
}

function isClearlyNonMedical(message) {
  const lower = message.toLowerCase();
  return NON_MEDICAL_SIGNALS.some((signal) => lower.includes(signal));
}

function isMedicationModeRequest(message, patientContext) {
  const lower = message.toLowerCase();
  if (/provide patient-friendly information for/i.test(lower)) return true;
  if (patientContext?.medicationMode === true) return true;
  if (patientContext?.focusedMedication) return true;
  return false;
}

function buildSystemPrompt(patientContext, medicationMode) {
  let prompt = HEALTHCARE_SYSTEM_PROMPT;
  if (medicationMode) {
    prompt += MEDICATION_SECTIONS_INSTRUCTION;
  }
  if (patientContext && Object.keys(patientContext).length > 0) {
    prompt += `\n\nCurrent patient platform context (use when relevant for personalization):\n${JSON.stringify(patientContext, null, 2)}`;
  }
  return prompt;
}

async function callGemini(userMessage, systemPrompt) {
  const apiKey = resolveGeminiApiKey();
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not configured on the server.");
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  let lastError = null;

  for (const modelName of GEMINI_MODELS) {
    try {
      aiLog.logGeminiRequest({
        model: modelName,
        messagePreview: userMessage,
        promptLength: userMessage.length,
        systemPromptLength: systemPrompt.length,
      });

      const model = genAI.getGenerativeModel({
        model: modelName,
        systemInstruction: systemPrompt,
        generationConfig: { temperature: 0.2 },
      });

      const result = await model.generateContent(userMessage);
      const reply = result?.response?.text()?.trim();

      if (!reply) {
        throw new Error(`Gemini model ${modelName} returned empty content`);
      }

      aiLog.logGeminiResponse({
        model: modelName,
        replyPreview: reply,
        replyLength: reply.length,
      });

      return { reply, model: modelName };
    } catch (err) {
      lastError = err;
      aiLog.logNetworkError(err, { model: modelName, phase: "generateContent" });
    }
  }

  throw lastError || new Error("All Gemini models failed");
}

exports.handleChat = async (req, res) => {
  const requestId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

  try {
    const { message, patientContext } = req.body;

    aiLog.logRequest({ message, patientContext, ip: req.ip });

    if (!message || message.trim() === "") {
      aiLog.logValidationFailure({ reason: "empty_message", query: message });
      return res.status(400).json({ success: false, error: "Message content cannot be empty." });
    }

    const trimmed = message.trim();
    const query = trimmed.toLowerCase();

    if (isClearlyNonMedical(trimmed) && !hasMedicalIntent(trimmed)) {
      aiLog.logValidationFailure({ reason: "non_medical_topic", query });
      aiLog.logResponseSent({ statusCode: 200, success: true, replyPreview: OUT_OF_SCOPE_REPLY });
      return res.status(200).json({ success: true, reply: OUT_OF_SCOPE_REPLY });
    }

    if (!hasMedicalIntent(trimmed)) {
      aiLog.logValidationFailure({ reason: "no_healthcare_intent", query });
      aiLog.logResponseSent({ statusCode: 200, success: true, replyPreview: OUT_OF_SCOPE_REPLY });
      return res.status(200).json({ success: true, reply: OUT_OF_SCOPE_REPLY });
    }

    aiLog.logValidationPass({
      scenario: isMedicationModeRequest(trimmed, patientContext) ? "medication_mode" : "general_medical",
      query,
    });

    const medicationMode = isMedicationModeRequest(trimmed, patientContext);
    const systemPrompt = buildSystemPrompt(patientContext, medicationMode);
    const { reply, model } = await callGemini(trimmed, systemPrompt);

    aiLog.logResponseSent({ statusCode: 200, success: true, replyPreview: reply, model });

    return res.status(200).json({ success: true, reply });
  } catch (error) {
    console.error(error);
    aiLog.logException(error, { requestId, phase: "handleChat" });
    aiLog.logResponseSent({ statusCode: 200, success: false, replyPreview: SERVICE_ERROR_REPLY });

    return res.status(200).json({ success: false, reply: SERVICE_ERROR_REPLY });
  }
};

exports.handleMedicalChat = exports.handleChat;
exports.hasMedicalIntent = hasMedicalIntent;
exports.isClearlyNonMedical = isClearlyNonMedical;
