// ============================================================================
// Earth Sweet Earth — "translate" Supabase Edge Function
// ----------------------------------------------------------------------------
// Translates short UI strings WITH CONTEXT using the Claude (Anthropic) API,
// then caches every result in the `translations` table so the same translation
// comes back every time and each string is only ever paid for once.
//
// WHY CLAUDE: the old version translated each label on its own with a free
// Google endpoint, so short words ("To", "Home", "Start") came out literal or
// odd. Claude translates a whole batch together, knowing these are labels for a
// youth environmental nonprofit, which reads far more naturally.
//
// ONE-TIME SETUP (a grown-up / Kevin):
//   1. Make a Claude API key at https://console.anthropic.com
//   2. supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   3. supabase functions deploy translate --use-api
//   (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
// If ANTHROPIC_API_KEY is NOT set, it safely falls back to the free Google
// endpoint (same as before), so nothing breaks in the meantime.
// ============================================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const MODEL = "claude-haiku-4-5-20251001"; // fast + inexpensive; swap to "claude-sonnet-5" for even higher quality

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

// --- Claude: translate a batch of strings together, with website context ---
async function claudeBatch(texts: string[], target: string, targetName: string): Promise<string[]> {
  const sys =
    `You are a professional translator for the website of Earth Sweet Earth, a youth-led environmental nonprofit. ` +
    `Translate each English string into ${targetName} (BCP-47 code: ${target}). ` +
    `These are short website UI strings: buttons, labels, headings, and short messages. Rules:\n` +
    `- Translate the MEANING in website context, not word-by-word (e.g. "Home" = the home page; "To" as in "Welcome to").\n` +
    `- Keep it natural, warm, and concise, the way a friendly nonprofit would write.\n` +
    `- Preserve HTML tags, {placeholders}, emoji, URLs, numbers, and leading/trailing punctuation and spacing exactly.\n` +
    `- Render "Earth Sweet Earth" as a natural equivalent phrase in the target language when it reads well.\n` +
    `- Return ONLY a JSON array of strings: the translations in the SAME order and SAME count as the input. No commentary, no code fences.`;
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_KEY as string,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 4096,
      system: sys,
      messages: [{ role: "user", content: JSON.stringify(texts) }],
    }),
  });
  if (!r.ok) throw new Error("anthropic " + r.status);
  const j = await r.json();
  let txt = String(j?.content?.[0]?.text || "").trim();
  txt = txt.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
  const arr = JSON.parse(txt);
  if (!Array.isArray(arr) || arr.length !== texts.length) throw new Error("bad shape");
  return arr.map((x) => (x == null ? "" : String(x)));
}

// --- Google free endpoint: per-string fallback if Claude is unavailable ---
async function gtx(text: string, source: string, target: string): Promise<string> {
  const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${source}&tl=${target}&dt=t&q=${encodeURIComponent(text)}`;
  const r = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } });
  if (!r.ok) throw new Error("gtx " + r.status);
  const j = await r.json();
  return (j[0] || []).map((seg: any[]) => seg[0]).join("");
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { q, target, source = "en", targetName } = await req.json();
    if (!Array.isArray(q) || !target) return json({ error: "q[] and target required" }, 400);
    if (target === source) return json({ translations: q });

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const texts = [...new Set(q.filter((x) => typeof x === "string" && x.trim()))] as string[];
    const map: Record<string, string> = {};

    // 1) cache lookup (chunked to stay within URL/statement limits)
    for (let i = 0; i < texts.length; i += 100) {
      const chunk = texts.slice(i, i + 100);
      const { data } = await admin.from("translations").select("source_text,translated").eq("target", target).in("source_text", chunk);
      (data || []).forEach((r: any) => { map[r.source_text] = r.translated; });
    }

    // 2) translate the misses with Claude, in batches (keeps the JSON reliable)
    const miss = texts.filter((t) => map[t] == null);
    if (miss.length && ANTHROPIC_KEY) {
      for (let i = 0; i < miss.length; i += 40) {
        const chunk = miss.slice(i, i + 40);
        try {
          const tr = await claudeBatch(chunk, target, targetName || target);
          chunk.forEach((t, k) => { if (tr[k] && tr[k].trim()) map[t] = tr[k]; });
        } catch (_e) { /* fall through to the Google fallback below */ }
      }
    }

    // 3) anything still missing (no key set, or Claude hiccupped) -> Google, per string
    for (const t of texts) {
      if (map[t] != null) continue;
      try { map[t] = (await gtx(t, source, target)) || t; } catch (_e) { map[t] = t; }
    }

    // remember the new translations so we never pay for them again
    const toStore = miss.filter((t) => map[t] != null && map[t] !== t)
      .map((t) => ({ target, source_text: t, translated: map[t] }));
    if (toStore.length) { try { await admin.from("translations").upsert(toStore, { onConflict: "target,source_text" }); } catch (_e) {} }

    return json({ translations: q.map((x) => (typeof x === "string" && map[x] != null ? map[x] : x)) });
  } catch (e) {
    return json({ error: String(e) }, 400);
  }
});
