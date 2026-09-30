import json
p = "/data/oh/vendor/opc/opi5plus/config.json"
d = json.load(open(p))
subs = d["subsystems"]
if not any(s["subsystem"] == "powermgr" for s in subs):
    subs.append({"subsystem": "powermgr", "components": [
        {"component": "power_manager",
         "features": ["power_manager_feature_power_dialog = false"]}]})
    json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
    print("powermgr override appended")
else:
    print("powermgr already present")
