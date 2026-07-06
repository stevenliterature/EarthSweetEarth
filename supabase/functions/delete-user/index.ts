// ============================================================================
// Earth Sweet Earth — "delete-user" Supabase Edge Function
// ----------------------------------------------------------------------------
// WHY THIS EXISTS
//   The website uses your PUBLIC (anon) key. That key is not allowed to delete
//   accounts or send email — on purpose. This little server-side function runs
//   with the SECRET service-role key, checks that the person asking is an
//   Owner/Admin, deletes the account, and emails the person the reason.
//
// WHAT YOU NEED
//   • The Supabase CLI:            https://supabase.com/docs/guides/cli
//   • A free Resend account for email (https://resend.com) — or swap in any
//     email service in step 3 below.
//
// ONE-TIME DEPLOY (run these in a terminal, in your project folder)
//   1. supabase login
//   2. supabase link --project-ref najuadikmuiojsmnylya
//   3. Put this file at:  supabase/functions/delete-user/index.ts
//   4. Set the secrets the function needs:
//        supabase secrets set RESEND_API_KEY=your_resend_key
//        supabase secrets set FROM_EMAIL="Earth Sweet Earth <noreply@yourdomain>"
//      (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
//   5. Deploy:
//        supabase functions deploy delete-user
//
// After that, the "Delete account" button in Owner Settings will work.
// If you skip the Resend step, deletion still works — it just won't email.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { userId, email, reason } = await req.json();
    if (!userId) return json({ error: "Missing userId" }, 400);

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // 1) Make sure the CALLER is signed in and is an Owner/Admin ----------------
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: "Not signed in" }, 401);

    const { data: prof } = await admin
      .from("profiles").select("role").eq("id", userData.user.id).single();
    if (!prof || !["owner", "admin"].includes(prof.role)) {
      return json({ error: "Only the Owner or an Admin can delete accounts." }, 403);
    }

    // 2) Delete the account (their profile row is removed automatically) --------
    const { error: delErr } = await admin.auth.admin.deleteUser(userId);
    if (delErr) return json({ error: delErr.message }, 400);

    // 3) Email the person the reason (optional; needs RESEND_API_KEY) -----------
    const RESEND = Deno.env.get("RESEND_API_KEY");
    const FROM = Deno.env.get("FROM_EMAIL") ?? "Earth Sweet Earth <noreply@earthsweetearth.org>";
    if (RESEND && email) {
      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: FROM,
          to: email,
          subject: "Your Earth Sweet Earth account was removed",
          text:
            `Hi,\n\nYour Earth Sweet Earth account (${email}) has been removed.\n\n` +
            `Reason: ${reason || "(no reason given)"}\n\n` +
            `You're welcome to sign up again any time.\n\n— Earth Sweet Earth`,
        }),
      }).catch(() => {/* don't fail the delete if the email service hiccups */});
    }

    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}