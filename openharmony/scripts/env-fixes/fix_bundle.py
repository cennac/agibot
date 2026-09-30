import re
p = "/data/oh/base/powermgr/power_manager/bundle.json"
s = open(p, encoding="utf-8").read()
s2 = re.sub(r",(\s*\])", r"\1", s)
open(p, "w", encoding="utf-8").write(s2)
import json
json.load(open(p))
print("bundle.json repaired & valid")
