/**
 * Load .env before any other app modules read process.env.
 * Must be required first from server.js.
 */
const path = require("path");
const fs = require("fs");
const dotenv = require("dotenv");

const envPath = path.join(__dirname, "..", ".env");
const envExamplePath = path.join(__dirname, "..", ".env.example");

if (fs.existsSync(envPath)) {
  const result = dotenv.config({ path: envPath });
  if (result.error) {
    console.warn("[Rafeeq] Failed to parse .env:", result.error.message);
  }
} else {
  dotenv.config();
  console.warn(
    `[Rafeeq] No .env file at ${envPath}. Copy .env.example to .env and set OPENROUTER_API_KEY.`
  );
}

function getOpenRouterApiKey() {
  return String(process.env.OPENROUTER_API_KEY || "").trim();
}

function getGeminiApiKey() {
  return String(process.env.GEMINI_API_KEY || "").trim();
}

function maskKey(key) {
  const k = String(key || "").trim();
  if (!k) return "(empty)";
  if (k.length <= 8) return `(${k.length} chars, masked)`;
  return `${k.slice(0, 4)}…${k.slice(-4)} (${k.length} chars)`;
}

function logLlmEnvStatus() {
  const openRouterKey = getOpenRouterApiKey();
  const geminiKey = getGeminiApiKey();
  console.log("[Rafeeq ENV] OpenRouter API Key:", openRouterKey ? "LOADED" : "MISSING", maskKey(openRouterKey));
  console.log("[Rafeeq ENV] OpenRouter Model (hardcoded): deepseek/deepseek-v4-flash:free");
  console.log("[Rafeeq ENV] Gemini API Key (GEMINI_API_KEY):", geminiKey ? "LOADED" : "MISSING", maskKey(geminiKey));
  console.log("[Rafeeq ENV] .env path:", envPath, "| exists:", fs.existsSync(envPath));

  if (!openRouterKey && fs.existsSync(envExamplePath)) {
    console.warn("[Rafeeq] Add OPENROUTER_API_KEY to .env (see .env.example).");
  }
  if (!geminiKey && fs.existsSync(envExamplePath)) {
    console.warn("[Rafeeq] Add GEMINI_API_KEY to .env for Rafeeq AI Medical Assistant (POST /api/ai/chat).");
  }
}

logLlmEnvStatus();

module.exports = {
  envPath,
  getOpenRouterApiKey,
  getGeminiApiKey,
  logLlmEnvStatus,
  logGeminiEnvStatus: logLlmEnvStatus,
};
