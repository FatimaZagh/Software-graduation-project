# Rafeeq Medication Chatbot (Rule-Based)

## Overview

The assistant lives in `services/medicationChatbot.js` and is exposed at:

`POST /api/patient-portal/:patientUserId/chatbot/medications`  
Body: `{ "question": "your text" }`  
Response: `{ "answer": "...", "matchedRuleId": "paracetamol|null", "confidence": "rule_keyword|fallback|none" }`

**No OpenAI or external AI** — only deterministic JavaScript.

## How it works

1. **Normalization** — Lowercase, trim, strip combining diacritics (helps Arabic/Latin input), replace punctuation with spaces.
2. **Keyword rules** — `RULES` is an ordered array. Each rule has `id`, `keywords[]`, and `response` (static string).
3. **Matching** — For each rule, if any keyword appears as a **substring** of the normalized question, that rule wins immediately (first match).
4. **Fallback** — If nothing matches, return a safe message telling the user to contact a pharmacist/doctor with their full medication list.

## How to extend

Add a new object to `RULES`:

```js
{
  id: "metformin",
  keywords: ["metformin", "ميتفورمين"],
  response: "Metformin is used for diabetes. Common GI upset early; rarely lactic acidosis in kidney failure. Follow your prescribed dose.",
},
```

Restart Node after edits.

## Limitations (production)

- Not individualized dosing; never replaces licensed advice.
- No drug–drug interaction database — add a curated interaction table later.
- For Arabic NLP beyond substring match, consider adding more keyword variants or a small synonym map per rule.

## Test with curl

```bash
curl -s -X POST http://127.0.0.1:3000/api/patient-portal/<USER_ID>/chatbot/medications ^
  -H "Content-Type: application/json" ^
  -d "{\"question\":\"What is paracetamol?\"}"
```

Replace `<USER_ID>` with a **Patient** role `users._id` from MongoDB Compass.
