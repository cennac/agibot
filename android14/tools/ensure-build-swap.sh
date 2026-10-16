#!/usr/bin/env bash
set -euo pipefail

# Temporary build swap on the large /data volume. Run as root.
build_swap=/data/agibot-android14-build/swapfile-32g
bad_swap='/home/cennac/\'

if ! swapon --show --noheadings | awk '{print $1}' | grep -Fxq "$build_swap"; then
    if [[ ! -f "$build_swap" ]]; then
        fallocate -l 32G "$build_swap"
        chmod 600 "$build_swap"
        mkswap "$build_swap"
    fi
    swapon "$build_swap"
fi

# A first interactive provisioning command was mangled by local shell expansion
# and created this exact file. Keep it as the only cleanup target; never remove
# anything else in the home directory.
if swapon --show --noheadings | awk '{print $1}' | grep -Fxq "$bad_swap"; then
    swapoff "$bad_swap"
fi
if [[ -f "$bad_swap" ]]; then
    rm -f -- "$bad_swap"
fi

swapon --show
