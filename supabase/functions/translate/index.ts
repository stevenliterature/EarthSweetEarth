// Supabase Edge Function: translates short strings and caches every result.
//
// The site never stores per-language copies of itself. It sends the visible
// English strings here; this function returns the translation for each, using a
// free Google Translate endpoint (no API key), and remembers each one in the
// `translations` table so the SAME translation comes back every time and each
// string is only ever fetched once.
//
// DEPLOY:  supabase functions deploy translate
// (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

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
    const { q, target, source = "en" } = await req.json();
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
    // 2) translate misses, then remember them
    const miss = texts.filter((t) => map[t] == null);
    const toStore: Array<{ target: string; source_text: string; translated: string }> = [];
    for (const t of miss) {
      try {
        const tr = await gtx(t, source, target);
        map[t] = tr || t;
        if (tr && tr !== t) toStore.push({ target, source_text: t, translated: tr });
      } catch (_e) { map[t] = t; }
    }
    if (toStore.length) { try { await admin.from("translations").upsert(toStore, { onConflict: "target,source_text" }); } catch (_e) {} }

    return json({ translations: q.map((x) => (typeof x === "string" && map[x] != null ? map[x] : x)) });
  } catch (e) {
    return json({ error: String(e) }, 400);
  }
});