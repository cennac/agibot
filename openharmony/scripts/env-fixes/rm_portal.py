import json
p = "/data/oh/foundation/communication/wifi/wifi/bundle.json"
d = json.load(open(p, encoding="utf-8"))
rm = []
def clean(o):
    if isinstance(o, list):
        o[:] = [i for i in o if not (isinstance(i, str) and "portal_login_hap" in i or (clean(i) or False) and False)] if False else None
# simpler explicit walk
def walk(o):
    if isinstance(o, list):
        keep = []
        for i in o:
            if isinstance(i, str) and "portal_login_hap" in i:
                rm.append(i); continue
            walk(i); keep.append(i)
        o[:] = keep
    elif isinstance(o, dict):
        for v in o.values(): walk(v)
walk(d)
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("removed:", rm)
