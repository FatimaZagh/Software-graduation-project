const express = require("express");
const fs = require("fs");
const path = require("path");
const {
  verifySignedFileRequest,
  resolveUploadAbsolute,
} = require("../utils/doctorDocumentStorage");

const router = express.Router();

/** GET /api/files/doctor-registrations/:key/:filename */
router.get("/doctor-registrations/:key/:filename", (req, res) => {
  try {
    const relativePath = `doctor-registrations/${req.params.key}/${req.params.filename}`;
    const exp = req.query.exp;
    const sig = req.query.sig;
    if (!verifySignedFileRequest(relativePath, exp, sig)) {
      return res.status(403).json({ message: "Invalid or expired file link" });
    }
    const abs = resolveUploadAbsolute(relativePath);
    if (!abs || !fs.existsSync(abs)) {
      return res.status(404).json({ message: "File not found" });
    }
    const ext = path.extname(abs).toLowerCase();
    const type =
      ext === ".pdf"
        ? "application/pdf"
        : ext === ".png"
          ? "image/png"
          : ext === ".webp"
            ? "image/webp"
            : "image/jpeg";
    res.setHeader("Content-Type", type);
    res.setHeader("Cache-Control", "private, max-age=3600");
    fs.createReadStream(abs).pipe(res);
  } catch (e) {
    console.error("[files]", e);
    res.status(500).json({ message: "Error serving file" });
  }
});

module.exports = router;
