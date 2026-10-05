import { createClient } from "npm:@supabase/supabase-js@2";

const PROVIDER = "payments";
const TOLERANCE_SECONDS = 300;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const toHex = (buf: ArrayBuffer) =>
  [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

async function sign(secret: string, payload: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return toHex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)));
}

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const secret = Deno.env.get("WEBHOOK_SECRET");
  if (!secret) return json({ error: "not_configured" }, 500);

  const timestamp = req.headers.get("X-Webhook-Timestamp") ?? "";
  const signature = req.headers.get("X-Webhook-Signature") ?? "";
  const raw = await req.text();

  const age = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (!Number.isFinite(age) || age > TOLERANCE_SECONDS) {
    return json({ error: "stale_request" }, 401);
  }

  const expected = await sign(secret, `${timestamp}.${raw}`);
  if (!safeEqual(expected, signature)) return json({ error: "invalid_signature" }, 401);

  let event: { id?: unknown; type?: unknown; data?: { order_id?: unknown } };
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const orderId = event.data?.order_id;
  if (
    typeof event.id !== "string" || typeof event.type !== "string" ||
    typeof orderId !== "string"
  ) {
    return json({ error: "invalid_payload" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: processed, error } = await supabase.rpc("process_payment_webhook", {
    p_provider: PROVIDER,
    p_event_id: event.id,
    p_order_id: orderId,
    p_event_type: event.type,
  });

  if (error) {
    if (error.code === "P0002") return json({ error: "order_not_found" }, 404);
    console.error("webhook failed", error.code);
    return json({ error: "internal_error" }, 500);
  }

  return json({ received: true, duplicate: !processed });
});
