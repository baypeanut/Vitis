// supabase/functions/claude-vision/index.ts
//
// Proxy for Claude Vision API. Keeps the Anthropic API key server-side.
// Called by ClaudeVisionService.swift via supabase.functions.invoke("claude-vision").
//
// Deploy: supabase functions deploy claude-vision
// Secret: supabase secrets set CLAUDE_API_KEY=sk-ant-...

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const ANTHROPIC_ENDPOINT = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-haiku-4-5-20251001";

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

serve(async (req) => {
  // Only allow POST
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const apiKey = Deno.env.get("CLAUDE_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "Claude API not configured" }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  let imageBase64: string;
  try {
    const body = await req.json();
    imageBase64 = body.image_base64;
    if (!imageBase64) throw new Error("Missing image_base64");
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

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
  } catch (err) {
    return new Response(JSON.stringify({ error: "Network error reaching Claude" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!claudeRes.ok) {
    const errText = await claudeRes.text();
    return new Response(errText, {
      status: claudeRes.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const claudeJson = await claudeRes.json();

  // Extract content[0].text and return it directly as JSON
  const text: string = claudeJson?.content?.[0]?.text ?? "";

  // Strip markdown code fences if present
  let cleaned = text.trim();
  if (cleaned.startsWith("```")) {
    const newlineIdx = cleaned.indexOf("\n");
    if (newlineIdx !== -1) cleaned = cleaned.slice(newlineIdx + 1);
  }
  if (cleaned.endsWith("```")) cleaned = cleaned.slice(0, -3);
  cleaned = cleaned.trim();

  // Validate it's JSON before returning
  try {
    JSON.parse(cleaned);
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON from Claude", raw: cleaned }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(cleaned, {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
