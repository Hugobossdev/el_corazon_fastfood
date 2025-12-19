import express from "express";
import cors from "cors";
import fetch from "node-fetch";
import agoraAccessToken from "agora-access-token";
import dotenv from "dotenv";

// Charger les variables d'environnement depuis .env
dotenv.config();

const { RtcTokenBuilder, RtcRole } = agoraAccessToken;

const app = express();

// CORS permissif en dev (à restreindre en prod)
app.use(
  cors({
    origin: true,
  })
);

// Pour proxy POST/PUT/PATCH
app.use(express.text({ type: "*/*" }));

app.get("/health", (_req, res) => res.json({ ok: true }));

// Token Agora RTC (audio/video)
// Nécessite: AGORA_APP_ID + AGORA_APP_CERT (backend)
app.get("/api/agora/rtc-token", async (req, res) => {
  try {
    const appId = process.env.AGORA_APP_ID;
    const appCert = process.env.AGORA_APP_CERT;
    if (!appId || !appCert) {
      console.error(
        "[agora-token] Missing environment variables:",
        {
          hasAppId: !!appId,
          hasAppCert: !!appCert,
        }
      );
      return res.status(500).json({
        error: "Missing AGORA_APP_ID / AGORA_APP_CERT on backend",
        message:
          "Please configure AGORA_APP_ID and AGORA_APP_CERT in your .env file or environment variables. " +
          "Get these values from https://console.agora.io/",
        hint: "Create a .env file in the backend directory with: AGORA_APP_ID=... and AGORA_APP_CERT=...",
      });
    }

    const channel = String(req.query.channel || "");
    const uid = Number(req.query.uid || 0);
    const expireSeconds = Number(req.query.expire || 3600);

    if (!channel) {
      return res.status(400).json({ error: "Missing channel" });
    }

    const now = Math.floor(Date.now() / 1000);
    const privilegeExpireTs = now + expireSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCert,
      channel,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpireTs
    );

    return res.json({ token, channel, uid, expireSeconds });
  } catch (e) {
    return res.status(500).json({ error: String(e) });
  }
});

// Proxy Google Places Autocomplete
app.get("/api/google/places/autocomplete", async (req, res) => {
  try {
    const url = new URL("https://maps.googleapis.com/maps/api/place/autocomplete/json");
    for (const [k, v] of Object.entries(req.query)) {
      if (typeof v === "string") url.searchParams.set(k, v);
    }

    const r = await fetch(url.toString());
    const text = await r.text();
    res.status(r.status).type("application/json").send(text);
  } catch (e) {
    res.status(500).json({ status: "ERROR", error: String(e) });
  }
});

// Proxy Google Places Details
app.get("/api/google/places/details", async (req, res) => {
  try {
    const url = new URL("https://maps.googleapis.com/maps/api/place/details/json");
    for (const [k, v] of Object.entries(req.query)) {
      if (typeof v === "string") url.searchParams.set(k, v);
    }

    const r = await fetch(url.toString());
    const text = await r.text();
    res.status(r.status).type("application/json").send(text);
  } catch (e) {
    res.status(500).json({ status: "ERROR", error: String(e) });
  }
});

// Proxy Google Geocoding (geocode)
app.get("/api/google/geocode", async (req, res) => {
  try {
    const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
    for (const [k, v] of Object.entries(req.query)) {
      if (typeof v === "string") url.searchParams.set(k, v);
    }
    const r = await fetch(url.toString());
    const text = await r.text();
    res.status(r.status).type("application/json").send(text);
  } catch (e) {
    res.status(500).json({ status: "ERROR", error: String(e) });
  }
});

// Proxy Google Directions
app.get("/api/google/directions", async (req, res) => {
  try {
    const url = new URL("https://maps.googleapis.com/maps/api/directions/json");
    for (const [k, v] of Object.entries(req.query)) {
      if (typeof v === "string") url.searchParams.set(k, v);
    }
    const r = await fetch(url.toString());
    const text = await r.text();
    res.status(r.status).type("application/json").send(text);
  } catch (e) {
    res.status(500).json({ status: "ERROR", error: String(e) });
  }
});

// Proxy Google Distance Matrix
app.get("/api/google/distance-matrix", async (req, res) => {
  try {
    const url = new URL(
      "https://maps.googleapis.com/maps/api/distancematrix/json"
    );
    for (const [k, v] of Object.entries(req.query)) {
      if (typeof v === "string") url.searchParams.set(k, v);
    }
    const r = await fetch(url.toString());
    const text = await r.text();
    res.status(r.status).type("application/json").send(text);
  } catch (e) {
    res.status(500).json({ status: "ERROR", error: String(e) });
  }
});

// Proxy PayDunya (optionnel pour Flutter Web si CORS bloque)
app.all("/api/paydunya/*", async (req, res) => {
  try {
    // On forward vers PayDunya (sandbox/prod) selon query param `sandbox=true/false`
    const sandbox = String(req.query.sandbox || "true") === "true";
    // NOTE: le domaine `app-sandbox.paydunya.com` ne résout pas (ENOTFOUND) dans plusieurs environnements.
    // PayDunya accepte généralement les clés sandbox sur le même host `app.paydunya.com`.
    const base = "https://app.paydunya.com";
    const path = req.path.replace("/api/paydunya", "");
    const url = new URL(base + path);

    // Copier query params (sans sandbox)
    for (const [k, v] of Object.entries(req.query)) {
      if (k === "sandbox") continue;
      if (typeof v === "string") url.searchParams.set(k, v);
    }

    const forwardUrl = url.toString();
    const forwardHeaders = {
      // forward headers PayDunya nécessaires
      "PAYDUNYA-MASTER-KEY": req.header("PAYDUNYA-MASTER-KEY") || "",
      "PAYDUNYA-PRIVATE-KEY": req.header("PAYDUNYA-PRIVATE-KEY") || "",
      "PAYDUNYA-TOKEN": req.header("PAYDUNYA-TOKEN") || "",
      "Content-Type": req.header("Content-Type") || "application/json",
      Accept: "application/json",
    };

    let r;
    try {
      r = await fetch(forwardUrl, {
        method: req.method,
        headers: forwardHeaders,
        body: req.method === "GET" || req.method === "HEAD" ? undefined : req.body,
      });
    } catch (e) {
      // Erreur réseau / TLS / DNS, etc.
      console.error("[paydunya-proxy] fetch failed", {
        method: req.method,
        forwardUrl,
        error: String(e),
      });
      return res.status(502).json({
        status: "ERROR",
        error: "PayDunya proxy network error",
        details: String(e),
        forwardUrl,
      });
    }

    const text = await r.text();
    if (r.status >= 400) {
      console.warn("[paydunya-proxy] upstream error", {
        method: req.method,
        forwardUrl,
        status: r.status,
        bodyPreview: text?.slice?.(0, 500),
      });
    }
    res.status(r.status).type("application/json").send(text);
  } catch (e) {
    console.error("[paydunya-proxy] internal error", {
      method: req.method,
      path: req.path,
      query: req.query,
      error: String(e),
    });
    res.status(500).json({ status: "ERROR", error: String(e) });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Backend proxy listening on http://localhost:${port}`);
});


