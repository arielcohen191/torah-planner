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
gate_css = """<style>
:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}[hidden]{display:none!important}
#gate{position:fixed;inset:0;z-index:50;background:radial-gradient(circle at 80% 10%,rgba(255,255,255,.14) 0 180px,transparent 181px),radial-gradient(circle at 10% 90%,rgba(255,255,255,.1) 0 140px,transparent 141px),var(--grad,#2f6fd6);display:grid;place-items:center;padding:20px;overflow:auto}
.gate-card{background:var(--card);border-radius:22px;padding:30px 26px;width:min(400px,100%);box-shadow:0 20px 60px rgba(20,30,80,.35);text-align:center}
.gate-card .mark{margin:0 auto 12px}.gate-card h1{margin:0;font-size:20px}.gate-card p{color:var(--muted);margin:4px 0 18px;font-size:13.5px}
.gate-card form{display:flex;flex-direction:column;gap:12px;text-align:right}.gate-card .btn{justify-content:center}
</style>"""
shim = '<script>window.PLANNER_CFG=' + json.dumps(cfg) + ';</script>\n<script>\n' + (root / 'src/shim.js').read_text() + '</script>\n'
body = body.replace('<script>\nconst DATA', shim + '<script>\nconst DATA', 1)
fav = '<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 32 32%27%3E%3Crect width=%2732%27 height=%2732%27 rx=%277%27 fill=%27%232f6fd6%27/%3E%3Cpath d=%27M9 10h14M9 16h14M9 22h9%27 stroke=%27white%27 stroke-width=%273%27 stroke-linecap=%27round%27/%3E%3C/svg%3E">'
out = ('<!doctype html>\n<html lang="he" dir="rtl">\n<head>\n<meta charset="utf-8">\n'
       '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
       + fav + '\n' + head + gate_css + '\n</head>\n<body>\n' + body + '\n</body>\n</html>\n')
(root / 'index.html').write_text(out)
print('index.html', len(out))
