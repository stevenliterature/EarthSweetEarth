// Supabase Edge Function: emails a summary of each application to the ESE alias.
// Deploy:  supabase functions deploy notify-application
// Set a Resend key:  supabase secrets set RESEND_API_KEY=your_key   (https://resend.com)
// The website calls this after a chapter/leadership application is submitted.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const TO_EMAIL = "hello@earthsweetearth.org";
const FROM_EMAIL = "Earth Sweet Earth <onboarding@resend.dev>"; // swap for a verified domain sender when ready

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { type, data } = await req.json();
    const esc = (s: string) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    const rows = Object.entries(data || {})
      .filter(([k]) => !/signature/i.test(k))
      .map(([k, v]) => `<tr><td style="padding:5px 12px;font-weight:600;vertical-align:top">${esc(k)}</td><td style="padding:5px 12px">${esc(Array.isArray(v) ? v.join(", ") : String(v))}</td></tr>`)
      .join("");
    const html = `<h2>New ${esc(type)} application</h2><table style="border-collapse:collapse;font-family:sans-serif;font-size:14px">${rows}</table>`;

    if (RESEND_API_KEY) {
      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from: FROM_EMAIL, to: TO_EMAIL, subject: `New ${type} application received`, html }),
      });
      if (!r.ok) return new Response(JSON.stringify({ error: await r.text() }), { status: 502, headers: { ...cors, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ ok: true }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
});