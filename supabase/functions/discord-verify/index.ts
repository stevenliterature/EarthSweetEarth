// Supabase Edge Function: verifies a member's linked Discord account and applies
// the owner's Discord-role -> website-role mapping.
//
// WHY THIS RUNS ON THE SERVER: it uses the service role to set profiles.role.
// If the browser could do that, anyone could just make themselves Owner.
//
// DEPLOY
//   supabase functions deploy discord-verify
//   supabase secrets set DISCORD_BOT_TOKEN=...   # a bot in your ESE server
//   supabase secrets set DISCORD_GUILD_ID=...    # your server's ID
// (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
//
// Without the bot token it still LINKS the account (and saves the username);
// it just can't read Discord roles, so no role is applied.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BOT_TOKEN = Deno.env.get("DISCORD_BOT_TOKEN");
const GUILD_ID = Deno.env.get("DISCORD_GUILD_ID");

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const jwt = (req.headers.get("Authorization") || "").replace("Bearer ", "");
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Who is actually calling? (Never trust an id sent from the browser.)
    const { data: userData, error: uErr } = await admin.auth.getUser(jwt);
    if (uErr || !userData?.user) return json({ ok: false, message: "You're not signed in." }, 401);
    const user = userData.user;

    const identities = (user.identities || []) as Array<Record<string, any>>;
    const disc = identities.find((i) => i.provider === "discord");
    if (!disc) return json({ ok: false, message: "No Discord account is linked yet." });

    const d = disc.identity_data || {};
    const discordId: string = d.provider_id || d.sub || disc.id;
    const discordUsername: string = d.user_name || d.name || d.full_name || d.preferred_username || "";

    // Remember the link regardless of whether we can read roles.
    await admin.from("profiles")
      .update({ discord_id: discordId, discord_username: discordUsername })
      .eq("id", user.id);

    if (!BOT_TOKEN || !GUILD_ID) {
      return json({
        ok: true, discordUsername, roles: [], appliedRole: null,
        message: "Linked. Role sync needs DISCORD_BOT_TOKEN and DISCORD_GUILD_ID.",
      });
    }

    const headers = { Authorization: `Bot ${BOT_TOKEN}` };
    const [mRes, rRes] = await Promise.all([
      fetch(`https://discord.com/api/v10/guilds/${GUILD_ID}/members/${discordId}`, { headers }),
      fetch(`https://discord.com/api/v10/guilds/${GUILD_ID}/roles`, { headers }),
    ]);

    if (mRes.status === 404) {
      return json({ ok: false, discordUsername, message: "You're not in the Earth Sweet Earth Discord server yet — join it, then try again." });
    }
    if (!mRes.ok || !rRes.ok) {
      return json({ ok: false, discordUsername, message: "Discord refused the request — check the bot token and server ID." });
    }

    const member = await mRes.json();
    const guildRoles = (await rRes.json()) as Array<{ id: string; name: string }>;
    const nameById: Record<string, string> = {};
    for (const r of guildRoles) nameById[r.id] = r.name;
    const roleNames: string[] = (member.roles || []).map((id: string) => nameById[id]).filter(Boolean);

    // The owner's mapping (site_content.data.discordMap). First match wins,
    // so the owner should list the highest role first.
    const { data: sc } = await admin.from("site_content").select("data").eq("id", 1).single();
    const mapping = ((sc?.data as any)?.discordMap || []) as Array<{ role: string; discord: string }>;

    let appliedRole: string | null = null;
    for (const m of mapping) {
      if (m.discord && roleNames.includes(m.discord)) { appliedRole = m.role; break; }
    }
    if (appliedRole) {
      await admin.from("profiles").update({ role: appliedRole }).eq("id", user.id);
    }

    return json({ ok: true, discordUsername, roles: roleNames, appliedRole });
  } catch (e) {
    return json({ ok: false, message: String(e) }, 400);
  }
});