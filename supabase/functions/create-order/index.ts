import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json({ error: "unauthorized" }, 401);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } } },
  );

  const { data: auth, error: authError } = await supabase.auth.getUser(
    authorization.replace(/^Bearer\s+/i, ""),
  );
  if (authError || !auth.user) return json({ error: "unauthorized" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const { organizationId, customerName, amount, externalReference } = body;
  if (
    typeof organizationId !== "string" || !UUID.test(organizationId) ||
    typeof customerName !== "string" || customerName.trim() === "" ||
    customerName.length > 200 ||
    typeof amount !== "number" || !Number.isFinite(amount) || amount < 0 ||
    (externalReference !== undefined && typeof externalReference !== "string")
  ) {
    return json({ error: "invalid_payload" }, 400);
  }

  const { data, error } = await supabase
    .from("orders")
    .insert({
      organization_id: organizationId,
      customer_name: customerName.trim(),
      amount,
      external_reference: externalReference ?? null,
      created_by: auth.user.id,
    })
    .select()
    .single();

  if (error) {
    if (error.code === "42501") return json({ error: "forbidden" }, 403);
    console.error("create-order failed", error.code);
    return json({ error: "internal_error" }, 500);
  }

  return json(data, 201);
});
