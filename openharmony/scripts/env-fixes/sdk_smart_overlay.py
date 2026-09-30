import os, shutil, subprocess

SDK = "/data/oh/prebuilts/ohos-sdk/linux/20/ets"
TREE = "/data/oh/interface/sdk-js"
ZIPDIR = "/data/openharmony/sdk_x/ets_x2/ets"

# 1. restore pristine api/kits from extracted public SDK
for d in ("api", "kits"):
    dst = os.path.join(SDK, d)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(os.path.join(ZIPDIR, d), dst)

def stems(dirpath):
    s = {}
    for root, _, files in os.walk(dirpath):
        for f in files:
            if f.endswith((".d.ts", ".d.ets")):
                s.setdefault(f.rsplit(".d.", 1)[0], []).append(os.path.join(root, f))
    return s

for comp in ("api", "kits"):
    sdk_dir, tree_dir = os.path.join(SDK, comp), os.path.join(TREE, comp)
    have = stems(sdk_dir)
    added = skipped = 0
    for root, _, files in os.walk(tree_dir):
        rel = os.path.relpath(root, tree_dir)
        for f in files:
            if not f.endswith((".d.ts", ".d.ets")):
                continue
            stem = f.rsplit(".d.", 1)[0]
            if stem in have:
                skipped += 1
                continue
            dstroot = os.path.join(sdk_dir, rel)
            os.makedirs(dstroot, exist_ok=True)
            shutil.copy2(os.path.join(root, f), os.path.join(dstroot, f))
            added += 1
    print(f"{comp}: added {added}, skipped(existing-stem) {skipped}")
