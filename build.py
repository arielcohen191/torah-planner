"""Builds index.html for Netlify from src/app.html (the Claude-hosted page) + src/shim.js (Supabase)."""
import json, pathlib
root = pathlib.Path(__file__).parent
s = (root / 'src/app.html').read_text()
cfg = json.loads((root / 'src/config.json').read_text())
i = s.index('<div class="app">')
head, body = s[:i], s[i:]
head = head.replace('<meta name="claude:viewport-fit-sides" content="cover">\n', '')
body = body.replace("אין לך הרשאה לשמור כאן. בקשו מבעל העמוד לשתף אתכם כ־Contributor (משתתף).",
                    "לא ניתן לשמור: השם הזה רשום עם קוד אישי אחר. צאו והיכנסו מחדש עם הקוד הנכון.")
body = body.replace("השמירה זמינה למורים שנכנסו עם חשבון ויש להם הרשאת עריכה לעמוד. בינתיים אפשר להוריד את התוכנית ל־Word.",
                    "אין חיבור לשרת כרגע. אפשר להוריד את התוכנית ל־Word ולנסות לשמור שוב בעוד רגע.")
for x,y in [("עריכה (רכז)","עריכה"),("<b>עריכה כרכז · </b>","<b>עריכת תוכנית של מורה אחר · </b>"),("לוח הבקרה המלא פתוח לרכז.","")]:
    body = body.replace(x, y)
gate_css = """<style>
:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}[hidden]{display:none!important}
#gate{position:fixed;inset:0;z-index:50;background:radial-gradient(circle at 80% 10%,rgba(255,255,255,.14) 0 180px,transparent 181px),radial-gradient(circle at 10% 90%,rgba(255,255,255,.1) 0 140px,transparent 141px),var(--grad,#2f6fd6);display:grid;place-items:center;padding:20px;overflow:auto}
.gate-card{background:var(--card);border-radius:22px;padding:30px 26px;width:min(400px,100%);box-shadow:0 20px 60px rgba(20,30,80,.35);text-align:center}
.gate-card .mark{margin:0 auto 12px}.gate-card h1{margin:0;font-size:20px}.gate-card p{color:var(--muted);margin:4px 0 18px;font-size:13.5px}
.gate-card form{display:flex;flex-direction:column;gap:12px;text-align:right}.gate-card .btn{justify-content:center}
.topbar{flex-wrap:wrap}
.userchip{font:inherit;display:inline-flex;align-items:center;gap:8px;border:none;background:var(--card);box-shadow:var(--shadow);border-radius:99px;padding:4px 6px 4px 12px;cursor:pointer;color:var(--ink);max-width:100%}
.userchip .uav{width:26px;height:26px;border-radius:50%;background:var(--grad,#2f6fd6);color:#fff;display:grid;place-items:center;font-weight:700;font-size:13px;flex:none}
.userchip .unm{font-weight:600;font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:140px}
.userchip .usw{font-size:12px;color:var(--primary);font-weight:600;white-space:nowrap}
.userchip[data-armed] .usw{color:var(--bad)}
</style>"""
shim = '<script>window.PLANNER_CFG=' + json.dumps(cfg) + ';</script>\n<script>\n' + (root / 'src/shim.js').read_text() + '</script>\n'
body = body.replace('<script>\nconst DATA', shim + '<script>\nconst DATA', 1)
fav = '<link rel="icon" href="/favicon.ico" sizes="any">\n<link rel="icon" type="image/png" sizes="32x32" href="/icons/favicon-32.png">\n<link rel="apple-touch-icon" href="/icons/apple-touch-icon.png">'
out = ('<!doctype html>\n<html lang="he" dir="rtl">\n<head>\n<meta charset="utf-8">\n'
       '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
       + fav + '\n' + head + gate_css + '\n</head>\n<body>\n' + body + '\n</body>\n</html>\n')
(root / 'index.html').write_text(out)
print('index.html', len(out))
