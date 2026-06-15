const mongoose = require("mongoose");
const { decryptMessage } = require("./chatCrypto");

/**
 * Resolve tenant org for chat writes from query, body, or auth middleware.
 */
function resolveChatOrgId(req) {
  const fromQuery = String(req.query?.orgId || req.body?.orgId || "").trim();
  if (fromQuery && mongoose.Types.ObjectId.isValid(fromQuery)) return fromQuery;

  if (req.doctorOrgId && mongoose.Types.ObjectId.isValid(String(req.doctorOrgId))) {
    return String(req.doctorOrgId);
  }
  if (req.patientOrgId && mongoose.Types.ObjectId.isValid(String(req.patientOrgId))) {
    return String(req.patientOrgId);
  }
  return "";
}

function toObjectId(id) {
  const s = String(id || "").trim();
  if (!mongoose.Types.ObjectId.isValid(s)) return null;
  return new mongoose.Types.ObjectId(s);
}

/**
 * Bidirectional thread filter for READS — both directions, no org scoping.
 * Historical rows must always appear for the participant pair.
 */
function buildBidirectionalChatQuery(userIdA, userIdB) {
  const a = toObjectId(userIdA);
  const b = toObjectId(userIdB);
  if (!a || !b) {
    throw new Error("Invalid chat participant ids");
  }
  return {
    $or: [
      { senderId: a, receiverId: b },
      { senderId: b, receiverId: a },
    ],
  };
}

/**
 * Optional org-scoped variant (legacy); prefer buildBidirectionalChatQuery for GET.
 */
function buildChatThreadQuery(userIdA, userIdB, orgIdOptional) {
  const participantClause = buildBidirectionalChatQuery(userIdA, userIdB);

  if (orgIdOptional && mongoose.Types.ObjectId.isValid(orgIdOptional)) {
    const oid = new mongoose.Types.ObjectId(orgIdOptional);
    return {
      $and: [
        participantClause,
        {
          $or: [{ orgId: oid }, { orgId: null }, { orgId: { $exists: false } }],
        },
      ],
    };
  }

  return participantClause;
}

function normalizeId(value) {
  if (value == null) return "";
  if (typeof value === "object" && value._id != null) return String(value._id);
  return String(value);
}

function mapChatMessageRow(m) {
  const senderId = normalizeId(m.senderId);
  const receiverId = normalizeId(m.receiverId);

  let body = "";
  if (m.bodyEnc?.cipherTextB64) {
    body = decryptMessage(m.bodyEnc, senderId, receiverId);
  }
  if (!body || !String(body).trim()) {
    body = String(m.body || m.text || m.message || m.content || "").trim();
  }

  return {
    _id: m._id,
    senderId,
    receiverId,
    senderRole: m.senderRole,
    receiverRole: m.receiverRole,
    body,
    text: body,
    message: body,
    content: body,
    createdAt: m.createdAt,
    timestamp: m.createdAt,
  };
}

module.exports = {
  resolveChatOrgId,
  buildBidirectionalChatQuery,
  buildChatThreadQuery,
  mapChatMessageRow,
};
