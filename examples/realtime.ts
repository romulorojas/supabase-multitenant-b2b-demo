import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL ?? "http://127.0.0.1:54321";
const anonKey = process.env.SUPABASE_ANON_KEY;
if (!anonKey) throw new Error("SUPABASE_ANON_KEY is required");

const supabase = createClient(url, anonKey);

const { error } = await supabase.auth.signInWithPassword({
  email: process.env.USER_EMAIL ?? "pedro@alpha.test",
  password: process.env.USER_PASSWORD ?? "password123",
});
if (error) throw error;

supabase
  .channel("orders")
  .on("postgres_changes", { event: "*", schema: "public", table: "orders" }, (payload) => {
    console.log(payload.eventType, payload.new);
  })
  .on("postgres_changes", { event: "INSERT", schema: "public", table: "order_events" }, (payload) => {
    console.log("event", payload.new);
  })
  .subscribe((status) => console.log("realtime:", status));
