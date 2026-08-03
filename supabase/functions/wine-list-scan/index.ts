// supabase/functions/wine-list-scan/index.ts
//
// Reads a whole restaurant wine list rather than a single label.
//
// Separate from claude-vision because almost everything differs: the prompt extracts
// many items instead of one, the payload is a dense page of small text rather than a
// bottle front, and a list page costs several times what a label costs. Sharing one
// function would have meant one set of limits sized for the wrong case.
//
// The quota is shared with label scanning on purpose. A list scan is worth several
// label scans, so it consumes several units rather than one.
//
// Deploy: supabase functions deploy wine-list-scan

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const ANTHROPIC_ENDPOINT = "https://api.anthropic.com/v1/messages";
// Sonnet rather than Haiku: dense small type at an angle in bad light is a harder
// read than a bottle front, and a misread line becomes a wrong wine at the table.
const MODEL = "claude-sonnet-4-5-20250929";

/// A list page is a bigger image than a label. Higher ceiling, still bounded.
const MAX_IMAGE_BASE64_CHARS = 3_000_000;
/// Beyond this the model starts inventing entries to fill the pattern.
const MAX_ITEMS = 80;

/// A list scan costs materially more than a label scan, so it draws more quota.
const QUOTA_UNITS_PER_LIST_SCAN = 5;
const SCAN_LIMIT = 30;
const SCAN_WINDOW = "1 hour";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT = `You extract wine entries from a photograph of a restaurant wine list.

Respond with ONLY valid JSON, no markdown, no code fences:
{"is_wine_list": true, "items": [{"name": "...", "producer": "...", "vintage": 2019, \
"region": "...", "price": "...", "by_glass": false}]}

If the image is not a wine list, respond {"is_wine_list": false, "items": []}.

Rules:
- One object per wine on the list. Preserve the order they appear.
- producer, vintage, region and price are null when not printed.
- vintage is a 4-digit integer or null. "NV" means null.
- price: copy the printed characters exactly, including currency. Do not convert.
- by_glass: true only where the list marks it as available by the glass.
- Transcribe what is printed. Do not correct spelling, expand abbreviations, or add \
a producer you believe is correct but cannot read.
- If a line is too blurred to read, omit it rather than guessing. A missing entry is \
recoverable; an invented one is not.`;

function json(body: unknown, status: number, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS, ...extra },
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
    return json({ error: "List scanning not configured" }, 503);
  }

  // ── Authenticated caller ──
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

  // ── Payload ──
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

  const commaIdx = imageBase64.indexOf(",");
  if (imageBase64.startsWith("data:") && commaIdx !== -1) {
    imageBase64 = imageBase64.slice(commaIdx + 1);
  }
  if (imageBase64.length > MAX_IMAGE_BASE64_CHARS) {
    return json({ error: "Image too large" }, 413);
  }

  // ── Quota. A list scan draws several units. ──
  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let quota: { allowed?: boolean; resets_at?: string } | undefined;
  for (let i = 0; i < QUOTA_UNITS_PER_LIST_SCAN; i++) {
    const { data, error } = await adminClient.rpc("consume_label_scan_quota", {
      p_user_id: user.id,
      p_limit: SCAN_LIMIT,
      p_window: SCAN_WINDOW,
    });
    if (error) {
      // Fail closed: a broken quota check must not become an open spending endpoint.
      console.error("consume_label_scan_quota failed", error);
      return json({ error: "Scan temporarily unavailable" }, 503);
    }
    quota = Array.isArray(data) ? data[0] : data;
    if (!quota?.allowed) {
      return json(
        { error: "Scan limit reached. Try again later.", resets_at: quota?.resets_at ?? null },
        429,
      );
    }
  }

  // ── Anthropic ──
  let claudeRes: Response;
  try {
    claudeRes = await fetch(ANTHROPIC_ENDPOINT, {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 4096,
        system: SYSTEM_PROMPT,
        messages: [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
            { type: "text", text: "Extract every wine on this list." },
          ],
        }],
      }),
    });
  } catch {
    return json({ error: "Network error reaching Claude" }, 502);
  }

  if (!claudeRes.ok) {
    const errText = await claudeRes.text();
    console.error("Anthropic error", claudeRes.status, errText);
    return json({ error: "List reading failed" }, claudeRes.status === 429 ? 429 : 502);
  }

  const claudeJson = await claudeRes.json();
  let cleaned: string = (claudeJson?.content?.[0]?.text ?? "").trim();
  if (cleaned.startsWith("```")) {
    const nl = cleaned.indexOf("\n");
    if (nl !== -1) cleaned = cleaned.slice(nl + 1);
  }
  if (cleaned.endsWith("```")) cleaned = cleaned.slice(0, -3);
  cleaned = cleaned.trim();

  let parsed: { is_wine_list?: boolean; items?: unknown[] };
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    console.error("Non-JSON from Claude", cleaned.slice(0, 500));
    return json({ error: "Could not read that list" }, 502);
  }

  // Truncate rather than trust an over-long list: past the cap the model is padding.
  const items = Array.isArray(parsed.items) ? parsed.items.slice(0, MAX_ITEMS) : [];

  return json({ is_wine_list: parsed.is_wine_list === true, items }, 200);
});
