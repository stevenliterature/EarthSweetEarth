// Supabase Edge Function: "forgot password" — emails a 6-digit code, then lets the
// person set a new password once they type the code back. Used only when a visitor is
// SIGNED OUT and can't get in (signed-in users change their password in Settings).
//
// Deploy:  supabase functions deploy password-reset --use-api --project-ref najuadikmuiojsmnylya
// Secrets it uses (already set): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY, FROM_EMAIL
//
// It talks to the `password_resets` table (service-role only — no client can read the codes).
// Three actions, all POSTed as JSON:
//   { action:"send",   email }                       -> emails a fresh code (always says ok, even if no such account)
//   { action:"verify", email, code }                 -> checks the code without changing anything
//   { action:"reset",  email, code, password }       -> checks the code and sets the new password
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CODE_TTL_MIN = 15;   // a code is good for 15 minutes
const MAX_ATTEMPTS = 6;    // wrong guesses allowed before the code is thrown away

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

  try {
    const { action, email, code, password } = await req.json();
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

    // Note: logical outcomes return HTTP 200 with { ok:false, error:"..." } so the browser's
    // supabase.functions.invoke() can read the body (it only parses JSON on 2xx). Non-2xx is
    // reserved for genuine crashes (the client then shows a generic "something went wrong").
    const em = String(email || "").trim().toLowerCase();
    if (!em || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(em))
      return json({ ok: false, error: "invalid_email" });

    // Find the auth user whose email matches (case-insensitive). Paginates the user list.
    async function findUser(target: string) {
      for (let page = 1; page <= 25; page++) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
        if (error || !data) return null;
        const u = data.users.find((x) => (x.email || "").toLowerCase() === target);
        if (u) return u;
        if (data.users.length < 200) break; // last page
      }
      return null;
    }

    // ---- send: make a code, save it, email it -------------------------------------
    if (action === "send") {
      const user = await findUser(em);
      if (user) {
        const newCode = String(Math.floor(100000 + Math.random() * 900000)); // 100000..999999
        const expires = new Date(Date.now() + CODE_TTL_MIN * 60 * 1000).toISOString();
        await admin.from("password_resets").upsert({
          email: em, code: newCode, expires_at: expires, attempts: 0, created_at: new Date().toISOString(),
        });

        const RESEND = Deno.env.get("RESEND_API_KEY");
        const FROM = Deno.env.get("FROM_EMAIL") ?? "Earth Sweet Earth <noreply@earthsweetearth.org>";
        if (RESEND) {
          const html =
            `<div style="font-family:Inter,Segoe UI,sans-serif;max-width:440px;margin:0 auto;color:#20302a">` +
            `<h2 style="color:#007600;font-family:Fraunces,Georgia,serif;margin:0 0 8px">Reset your password</h2>` +
            `<p style="margin:0 0 16px;font-size:15px;line-height:1.5">Here is your Earth Sweet Earth password reset code. ` +
            `Type it into the website to set a new password.</p>` +
            `<div style="font-size:34px;font-weight:700;letter-spacing:8px;color:#007600;background:#D5E3DA;` +
            `border-radius:12px;padding:16px;text-align:center;margin:0 0 16px">${newCode}</div>` +
            `<p style="margin:0;font-size:13px;color:#5f7168;line-height:1.5">This code expires in ${CODE_TTL_MIN} minutes. ` +
            `If you didn't ask to reset your password, you can safely ignore this email.</p></div>`;
          const text =
            `Your Earth Sweet Earth password reset code is ${newCode}.\n\n` +
            `It expires in ${CODE_TTL_MIN} minutes. If you didn't ask to reset your password, ignore this email.`;
          await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: { "Authorization": `Bearer ${RESEND}`, "Content-Type": "application/json" },
            body: JSON.stringify({ from: FROM, to: em, subject: "Your Earth Sweet Earth password reset code", html, text }),
          }).catch(() => {});
        }
      }
      // Always the same answer, whether or not the account exists — don't leak who has an account.
      return json({ ok: true });
    }

    // ---- verify / reset: both need a valid, unexpired, matching code --------------
    if (action === "verify" || action === "reset") {
      const { data: row } = await admin.from("password_resets").select("*").eq("email", em).maybeSingle();
      if (!row) return json({ ok: false, error: "no_code" });
      if (new Date(row.expires_at).getTime() < Date.now()) {
        await admin.from("password_resets").delete().eq("email", em);
        return json({ ok: false, error: "expired" });
      }
      if (row.attempts >= MAX_ATTEMPTS) {
        await admin.from("password_resets").delete().eq("email", em);
        return json({ ok: false, error: "too_many" });
      }
      const guess = String(code || "").trim();
      if (guess !== row.code) {
        const attempts = row.attempts + 1;
        await admin.from("password_resets").update({ attempts }).eq("email", em);
        if (attempts >= MAX_ATTEMPTS) {
          await admin.from("password_resets").delete().eq("email", em);
          return json({ ok: false, error: "too_many" });
        }
        return json({ ok: false, error: "bad_code", left: MAX_ATTEMPTS - attempts });
      }

      // Code is correct.
      if (action === "verify") return json({ ok: true });

      // reset: set the new password.
      const pw = String(password || "");
      if (pw.length < 6) return json({ ok: false, error: "weak" });
      const user = await findUser(em);
      if (!user) return json({ ok: false, error: "no_account" });
      const { error: upErr } = await admin.auth.admin.updateUserById(user.id, { password: pw });
      if (upErr) return json({ ok: false, error: "server" });
      await admin.from("password_resets").delete().eq("email", em); // one-time use
      return json({ ok: true });
    }

    return json({ ok: false, error: "unknown" });
  } catch (e) {
    // Genuine crash — non-2xx so it stands out; the client shows a generic message.
    return json({ ok: false, error: "server", detail: String(e) }, 500);
  }
});
