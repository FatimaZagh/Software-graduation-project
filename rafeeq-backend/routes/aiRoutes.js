const express = require("express");
const { handleChat } = require("../controllers/aiMedicalChatController");
const { logRequest, logNetworkError } = require("../utils/aiChatLogger");

const router = express.Router();

router.use((req, res, next) => {
  if (req.method === "POST" && req.path === "/chat") {
    console.log("[Rafeeq AI ROUTE] POST /api/ai/chat bound → handleChat");
  }
  next();
});

router.post("/chat", async (req, res, next) => {
  try {
    await handleChat(req, res);
  } catch (error) {
    logNetworkError(error, { route: "POST /api/ai/chat", note: "unhandled_route_wrapper" });
    next(error);
  }
});

module.exports = router;
