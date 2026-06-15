/**
 * Proxies Google Directions API so the API key stays server-side and web clients avoid CORS.
 */
exports.getDrivingDirections = async (req, res) => {
  const originLat = req.query.originLat ?? req.query.origin_lat;
  const originLng = req.query.originLng ?? req.query.origin_lng;
  const destLat = req.query.destLat ?? req.query.dest_lat;
  const destLng = req.query.destLng ?? req.query.dest_lng;

  if ([originLat, originLng, destLat, destLng].some((v) => v == null || v === "")) {
    return res.status(400).json({ message: "originLat, originLng, destLat, and destLng are required." });
  }

  const apiKey = String(process.env.GOOGLE_MAPS_API_KEY || "").trim();
  if (!apiKey) {
    return res.status(503).json({
      status: "SERVICE_UNAVAILABLE",
      message: "Directions service is not configured.",
    });
  }

  const params = new URLSearchParams({
    origin: `${originLat},${originLng}`,
    destination: `${destLat},${destLng}`,
    mode: "driving",
    key: apiKey,
  });

  const url = `https://maps.googleapis.com/maps/api/directions/json?${params.toString()}`;

  try {
    const response = await fetch(url, { method: "GET" });
    const data = await response.json();
    const status = data?.status || "UNKNOWN_ERROR";

    if (status !== "OK") {
      console.error("[Directions API]", status, data?.error_message || "");
      const httpStatus = status === "OVER_QUERY_LIMIT" ? 429 : 502;
      return res.status(httpStatus).json({
        status,
        message: data?.error_message || status,
      });
    }

    const encodedPolyline = data?.routes?.[0]?.overview_polyline?.points;
    if (!encodedPolyline) {
      return res.status(502).json({ status: "ZERO_RESULTS", message: "No driving route found." });
    }

    res.json({
      status: "OK",
      encodedPolyline,
    });
  } catch (error) {
    console.error("[Directions API] request failed:", error?.message || error);
    res.status(500).json({
      status: "REQUEST_FAILED",
      message: "Directions request failed.",
    });
  }
};
