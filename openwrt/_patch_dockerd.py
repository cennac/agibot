#!/usr/bin/env python3
# patch-docker-gitcommit: docker + dockerd 两个 Makefile 都有 "Verify PKG_GIT_SHORT_COMMIT"
# 网络校验(git-short-commit.sh 要 git ls-remote github;本机 git+gnutls 过 Clash 代理握手崩)。
# 改成字面量(= Makefile 里硬编码值),校验恒过,不影响编译用的 GITCOMMIT。容错:匹配到才改。
import re
files = [
    "/home/cennac/lede/feeds/packages/utils/dockerd/Makefile",
    "/home/cennac/lede/feeds/packages/utils/docker/Makefile",
]
# 匹配 EXPECTED_PKG_GIT_SHORT_COMMIT=$$$( $(CURDIR)[...]/git-short-commit.sh ... ); 两变体
pat = re.compile(
    r"EXPECTED_PKG_GIT_SHORT_COMMIT=\$\$\$\$\( \$\(CURDIR\)[^\n]*?git-short-commit\.sh .*? \);"
)
new = 'EXPECTED_PKG_GIT_SHORT_COMMIT="$(strip $(PKG_GIT_SHORT_COMMIT))";'
for p in files:
    s = open(p, encoding="utf-8").read()
    s2, n = pat.subn(new, s, count=1)
    if n == 1:
        open(p, "w", encoding="utf-8").write(s2)
        print(f"[OK]  patched ({n}): {p.split('/')[-2]}")
    else:
        print(f"[skip] 未匹配({n},可能已 patch 或无此块): {p.split('/')[-2]}")
print("PATCH_DOCKER_DONE")
