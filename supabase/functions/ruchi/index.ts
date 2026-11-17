// רוחי — בוט עזרה טכנית לכלי כנפי רוח. מקבל שאלה, עונה לפי מדריך השימוש, ומכין טיוטת משוב כשצריך.
const URL_ = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const KEY = Deno.env.get("ANTHROPIC_API_KEY") || "";
const MODEL = Deno.env.get("RUCHI_MODEL") || "claude-haiku-5-5";
const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
const db = (path: string, init: RequestInit = {}) => fetch(URL_ + path, { ...init, headers: { apikey: SRK, Authorization: "Bearer " + SRK, "Content-Type": "application/json", ...(init.headers || {}) } });

let GCACHE = { at: 0, origin: "", text: "" };
async function siteGuide(origin: string): Promise<string> {
  if (!/^https:\/\/[a-z0-9.-]+$/i.test(origin)) return "";
  if (GCACHE.origin === origin && Date.now() - GCACHE.at < 10 * 60e3) return GCACHE.text;
  try { const r = await fetch(origin + "/help/guide.md"); const t = r.ok ? await r.text() : "";
    if (t.includes("## כללי")) { GCACHE = { at: Date.now(), origin, text: t.slice(0, 60000) }; return GCACHE.text; } } catch {}
  return "";
}

const TOOL = {
  name: "reply",
  description: "התשובה של רוחי למשתמש",
  input_schema: {
    type: "object",
    properties: {
      answer: { type: "string", description: "תשובה קצרה וברורה בעברית, צעד אחר צעד כשצריך" },
      feedback: {
        type: "object",
        description: "טיוטת משוב לאריאל, רק אם אין תשובה במדריך, אם יש תקלה, או אם המשתמש מבקש שינוי/פיצ'ר",
        properties: {
          kind: { type: "string", enum: ["bug", "idea", "question"] },
          body: { type: "string", description: "תיאור מסודר לאריאל: מה ניסה לעשות, מה קרה, באיזה מסך" },
        },
        required: ["kind", "body"],
      },
    },
    required: ["answer"],
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  let b: any;
  try { b = await req.json(); } catch { return json({ error: "bad_request" }, 400); }
  const ur = await db("/rest/v1/rpc/_ruchi_user", { method: "POST", body: JSON.stringify({ p_phone: String(b.phone || "") }) });
  const u = ur.ok ? await ur.json() : null;
  if (!u) return json({ error: "forbidden" }, 403);
  if (b.ping) return json({ ok: true, ready: !!KEY });
  const q = String(b.q || "").trim().slice(0, 1500);
  if (!q) return json({ error: "empty" }, 400);

  const since = new Date(Date.now() - 3600e3).toISOString();
  const cr = await db(`/rest/v1/ruchi_log?select=id&phone=eq.${encodeURIComponent(u.phone)}&created_at=gte.${since}`, { headers: { Prefer: "count=exact", Range: "0-0" } });
  const used = Number((cr.headers.get("content-range") || "*/0").split("/")[1] || 0);
  if (used >= 40) return json({ error: "rate" }, 429);

  if (!KEY) return json({ error: "no_key" }, 503);

  // המדריך: גרסה בטבלה (אם הוזנה) גוברת; אחרת help/guide.md מהאתר עצמו, כך שהוא מתעדכן עם כל העלאה
  const dr = await db("/rest/v1/ruchi_docs?select=content&id=eq.guide");
  let guide = dr.ok ? ((await dr.json())[0]?.content || "") : "";
  if (!guide) guide = await siteGuide(req.headers.get("origin") || "");

  const system = [
    { type: "text", text:
`אתה "רוחי", העוזר הטכני של הכלים של בית הספר "כנפי רוח" (חמ"ד תורני בנים). הכלים נבנו על ידי אריאל כהן.
אתה עונה ל${u.greet}. כתוב בעברית, בגוף שני, בנימוס ובקצרה (עד 6 שורות), צעד אחר צעד כשצריך.
ענה רק לפי מדריך השימוש שלמטה. אל תמציא כפתורים, מסכים או יכולות שלא מופיעים בו.
אם אין במדריך תשובה, אם המשתמש מתאר תקלה (משהו לא עובד, נתונים חסרים או שגויים), או אם הוא מבקש שינוי או יכולת חדשה:
אמור בקצרה שזה "כבר לא לרוחי" ושהכנת משוב לאריאל, ומלא את feedback עם תיאור מסודר: מה ניסה לעשות, מה קרה, באיזה כלי ומסך.
אל תבקש ולא תציג מידע אישי על תלמידים. תמיד השתמש בכלי reply.` },
    { type: "text", text: "מדריך השימוש:\n\n" + guide, cache_control: { type: "ephemeral" } },
  ];
  const hist = Array.isArray(b.history) ? b.history.slice(-8).filter((m: any) => m && (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
    .map((m: any) => ({ role: m.role, content: m.content.slice(0, 1500) })) : [];
  const messages = [...hist, { role: "user", content: `[כלי: ${String(b.tool || "").slice(0, 40)} · עמוד: ${String(b.page || "").slice(0, 120)}]\n${q}` }];

  let out: any = null, err = "";
  try {
    const ar = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": KEY, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({ model: MODEL, max_tokens: 700, system, messages, tools: [TOOL], tool_choice: { type: "tool", name: "reply" } }),
    });
    const aj = await ar.json();
    if (!ar.ok) err = aj?.error?.type || ("http_" + ar.status);
    else out = (aj.content || []).find((c: any) => c.type === "tool_use")?.input || null;
  } catch (e) { err = "network"; }
  if (!out) return json({ error: "ai", detail: err }, 502);

  const answer = String(out.answer || "").slice(0, 3000);
  const fb = out.feedback && out.feedback.body ? { kind: ["bug", "idea", "question"].includes(out.feedback.kind) ? out.feedback.kind : "question", body: String(out.feedback.body).slice(0, 1800) } : null;
  await db("/rest/v1/ruchi_log", { method: "POST", headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ phone: u.phone, tool: String(b.tool || "").slice(0, 40), page: String(b.page || "").slice(0, 200), q, a: answer, feedback: !!fb }) });
  return json({ answer, feedback: fb });
});
