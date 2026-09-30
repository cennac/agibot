import json
p = "/data/oh/vendor/opc/opi5plus/config.json"
d = json.load(open(p, encoding="utf-8"))
done = False
for s in d["subsystems"]:
    for comp in s.get("components", []):
        if comp.get("component") == "wifi":
            feats = comp.setdefault("features", [])
            if not any("portal_login" in f for f in feats):
                feats.append("wifi_feature_with_portal_login = false")
            print("wifi features now:", feats)
            done = True
if not done:
    print("wifi component entry NOT found")
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
