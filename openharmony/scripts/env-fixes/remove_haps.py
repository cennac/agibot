import json, os

REVERT = [
    ("/data/oh/prebuilts/ohos-sdk/linux/20/ets/component",
     "/data/openharmony/sdk_x/ets_x2/ets/component"),
]
for dst, src in REVERT:
    if os.path.exists(dst):
        import shutil; shutil.rmtree(dst)
    import shutil; shutil.copytree(src, dst)
print("component dir restored")

TARGETS = [
    ("/data/oh/applications/standard/dlp_manager/bundle.json", "dlp_manager"),
    ("/data/oh/applications/standard/permission_manager/bundle.json", "permission_manager:permission_manager"),
    ("/data/oh/applications/standard/user_certificate_manager/bundle.json", "user_certificate_manager"),
    ("/data/oh/foundation/ability/ability_runtime/bundle.json", "ams_system_dialog"),
    ("/data/oh/foundation/communication/wifi/bundle.json", "portal_login"),
]

def clean(obj, needle, removed):
    if isinstance(obj, list):
        keep = []
        for it in obj:
            if isinstance(it, str) and needle in it:
                removed.append(it); continue
            clean(it, needle, removed)
            keep.append(it)
        obj[:] = keep
    elif isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, str) and needle in v:
                continue
            clean(v, needle, removed)

for path, needle in TARGETS:
    if not os.path.exists(path):
        print("MISS", path); continue
    d = json.load(open(path, encoding="utf-8"))
    rm = []
    clean(d, needle, rm)
    json.dump(d, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print(path.split("/data/oh/")[1], "removed:", len(rm), rm[:2])
