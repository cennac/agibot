#!/usr/bin/env bash
set -u

failures=0
required_tools=(git python3 curl)
recommended_tools=(repo jq xmllint dtc)

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf 'distro=%s\n' "${ID:-unknown}"
    printf 'version=%s\n' "${VERSION_ID:-unknown}"
    printf 'codename=%s\n' "${VERSION_CODENAME:-unknown}"
else
    printf 'distro=unknown\n'
    printf 'version=unknown\n'
    printf 'codename=unknown\n'
fi
printf 'arch=%s\n' "$(uname -m)"
printf 'kernel=%s\n' "$(uname -r)"
printf 'wsl_interop=%s\n' "${WSL_INTEROP:-unset}"
printf 'path=%s\n' "${PATH}"

printf '%s\n' '[filesystems]'
df -h / /mnt/e 2>/dev/null || true

printf '%s\n' '[required-tools]'
for tool in "${required_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '%s=%s\n' "$tool" "$(command -v "$tool")"
    else
        printf '%s=missing\n' "$tool"
        failures=$((failures + 1))
    fi
done

printf '%s\n' '[recommended-tools]'
for tool in "${recommended_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '%s=%s\n' "$tool" "$(command -v "$tool")"
    else
        printf '%s=missing\n' "$tool"
    fi
done

printf '%s\n' '[network]'
for url in \
    https://github.com/radxa/manifests.git \
    https://raw.githubusercontent.com/radxa/manifests/Android14-rkr6-rock5c/rockchip-u1-release.xml; do
    if timeout 20 git ls-remote "$url" HEAD >/dev/null 2>&1; then
        printf 'reachable-git=%s\n' "$url"
    elif curl -fsSI --max-time 15 "$url" >/dev/null 2>&1; then
        printf 'reachable-http=%s\n' "$url"
    else
        printf 'unreachable=%s\n' "$url"
    fi
done

printf 'proxy_http=%s\n' "${http_proxy:-unset}"
printf 'proxy_https=%s\n' "${https_proxy:-unset}"
printf 'failures=%d\n' "$failures"
exit "$failures"
