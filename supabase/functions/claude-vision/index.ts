// supabase/functions/claude-vision/index.ts
//
// Proxy for Claude Vision API. Keeps the Anthropic API key server-side.
// Called by ClaudeVisionService.swift via supabase.functions.invoke("claude-vision").
//
// This endpoint spends money on every call, so it is gated three ways before it will
// talk to Anthropic: the caller must present a valid user JWT, the payload must be
// within a size bound, and the user must have quota left in the current window.
// The anon key ships inside the app binary, so "holds the anon key" is not authorisation.
//
// Deploy: supabase functions deploy claude-vision
// Secret: supabase secrets set CLAUDE_API_KEY=sk-ant-...

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const ANTHROPIC_ENDPOINT = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-haiku-4-5-20251001";

/// Base64 characters, not bytes. ~1.5M chars is a little over 1 MB of JPEG, which is
/// far more than the client sends after downscaling and well under Anthropic's own cap.
const MAX_IMAGE_BASE64_CHARS = 1_500_000;

/// Scans per user per window. Generous for a person, ruinous for a script.
const SCAN_LIMIT = 30;
const SCAN_WINDOW = "1 hour";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT = `You are a wine label analyzer. Given an image, determine if it shows a wine bottle label. \
Respond with ONLY valid JSON, no markdown, no code fences.

If the image does NOT show a wine label, respond:
{"is_wine": false}

If the image shows a wine label, extract:
{"is_wine": true, "name": "wine name without vintage", "producer": "winery or château", \
"vintage": 2020, "variety": "grape variety if visible", "region": "appellation or region if visible", \
"category": "Red"}

Rules:
- vintage: 4-digit integer or null
- category: exactly Red, White, Sparkling, Rose, or null
- Use null for any field you cannot determine from the label
- Do not guess — only extract what is visible`;

function json(body: unknown, status: number, extraHeaders: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS, ...extraHeaders },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("CLAUDE_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!apiKey || !supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "Claude API not configured" }, 503);
  }

  // ── Gate 1: authenticated user ──
  // Done in-function rather than relying on the deploy-time verify_jwt flag, so the
  // guarantee travels with the code.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userErr || !user) {
    return json({ error: "Authentication required" }, 401);
  }

  // ── Gate 2: payload shape and size ──
  let imageBase64: string;
  try {
    const body = await req.json();
    imageBase64 = body.image_base64;
    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      throw new Error("Missing image_base64");
    }
  } catch {
    return json({ error: "Invalid request body" }, 400);
  }

  // Tolerate a data: URL prefix rather than forwarding it to Anthropic as image bytes.
  const commaIdx = imageBase64.indexOf(",");
  if (imageBase64.startsWith("data:") && commaIdx !== -1) {
    imageBase64 = imageBase64.slice(commaIdx + 1);
  }

  if (imageBase64.length > MAX_IMAGE_BASE64_CHARS) {
    return json({ error: "Image too large" }, 413);
  }

  // ── Gate 3: per-user quota ──
  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: quotaRows, error: quotaErr } = await adminClient.rpc(
    "consume_label_scan_quota",
    { p_user_id: user.id, p_limit: SCAN_LIMIT, p_window: SCAN_WINDOW },
  );

  if (quotaErr) {
    // Fail closed: a broken quota check must not become an open spending endpoint.
    console.error("consume_label_scan_quota failed", quotaErr);
    return json({ error: "Scan temporarily unavailable" }, 503);
  }

  const quota = Array.isArray(quotaRows) ? quotaRows[0] : quotaRows;
  if (!quota?.allowed) {
    return json(
      { error: "Scan limit reached. Try again later.", resets_at: quota?.resets_at ?? null },
      429,
    );
  }

  // ── Call Anthropic ──
  const claudeBody = {
    model: MODEL,
    max_tokens: 512,
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: "image/jpeg",
              data: imageBase64,
            },
          },
          {
            type: "text",
            text: "Analyze this image. Is it a wine label? If yes, extract the wine details.",
          },
        ],
      },
    ],
  };

  let claudeRes: Response;
  try {
    claudeRes = await fetch(ANTHROPIC_ENDPOINT, {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify(claudeBody),
    });
  } catch {
    return json({ error: "Network error reaching Claude" }, 502);
  }

  if (!claudeRes.ok) {
    // Upstream text can carry account details; log it, return something generic.
    const errText = await claudeRes.text();
    console.error("Anthropic error", claudeRes.status, errText);
    const status = claudeRes.status === 429 ? 429 : 502;
    return json({ error: "Label analysis failed" }, status);
  }

  const claudeJson = await claudeRes.json();
  const text: string = claudeJson?.content?.[0]?.text ?? "";

  // Strip markdown code fences if present
  let cleaned = text.trim();
  if (cleaned.startsWith("```")) {
    const newlineIdx = cleaned.indexOf("\n");
    if (newlineIdx !== -1) cleaned = cleaned.slice(newlineIdx + 1);
  }
  if (cleaned.endsWith("```")) cleaned = cleaned.slice(0, -3);
  cleaned = cleaned.trim();

  try {
    JSON.parse(cleaned);
  } catch {
    console.error("Non-JSON from Claude", cleaned.slice(0, 500));
    return json({ error: "Invalid response from label analyzer" }, 502);
  }

  return new Response(cleaned, {
    status: 200,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
});
