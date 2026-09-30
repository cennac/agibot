import json
p = "/data/oh/arkcompiler/runtime_core/static_core/plugins/ets/tools/declgen_ts2sts/package.json"
d = json.load(open(p))
dd = d.setdefault("devDependencies", {})
print("before rimraf:", dd.get("rimraf"), "| tsc:", dd.get("typescript"))
dd["rimraf"] = "3.0.2"
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
print("pinned rimraf=3.0.2")
