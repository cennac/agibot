#!/usr/bin/env bash
set -euo pipefail

PROGRAM_NAME=${0##*/}
SOURCE_DIR=${HOME}/src/agibot-android14
MANIFEST_URL=https://github.com/radxa/manifests.git
MANIFEST_BRANCH=Android14-rkr6-rock5c
MANIFEST_FILE=rockchip-u1-release.xml
EXPECTED_MANIFEST_REVISION=ac6785b31865b06223ae262c8ed42b14b11f5aaa
REPO_LAUNCHER_URL=${REPO_LAUNCHER_URL:-https://storage.googleapis.com/git-repo-downloads/repo}
REPO_URL=${REPO_URL:-https://gerrit.googlesource.com/git-repo}
REPO_REV=${REPO_REV:-v2.66.1}
REPO_JOBS=8
DO_SYNC=0
INSTALL_REPO=0

usage() {
    cat <<EOF
Usage: $PROGRAM_NAME [--source-dir DIR] [--repo-jobs N] [--sync] [--install-repo]

Initializes the locked Radxa Android 14 RKR6 manifest without building.
Downloading the full source tree requires the explicit --sync option.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source-dir)
            [[ $# -ge 2 ]] || { echo "$1 requires a directory" >&2; exit 2; }
            SOURCE_DIR=$2
            shift 2
            ;;
        --repo-jobs)
            [[ $# -ge 2 ]] || { echo "$1 requires a number" >&2; exit 2; }
            REPO_JOBS=$2
            shift 2
            ;;
        --sync)
            DO_SYNC=1
            shift
            ;;
        --install-repo)
            INSTALL_REPO=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ "$REPO_JOBS" =~ ^[1-9][0-9]*$ ]] || {
    echo "--repo-jobs must be a positive integer" >&2
    exit 2
}

export PATH=${HOME}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
umask 022

for tool in git python3 curl; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Missing required tool: $tool" >&2
        exit 1
    }
done

if ! command -v repo >/dev/null 2>&1; then
    if [[ "$INSTALL_REPO" -eq 1 ]]; then
        mkdir -p "$HOME/.local/bin"
        curl -fsSL --max-time 60 "$REPO_LAUNCHER_URL" -o "$HOME/.local/bin/repo"
        chmod 0755 "$HOME/.local/bin/repo"
    else
        echo "The repo launcher is missing. Re-run with --install-repo." >&2
        exit 1
    fi
fi

GIT_USER_NAME=$(git config --get user.name || true)
GIT_USER_EMAIL=$(git config --get user.email || true)
if [[ -z "$GIT_USER_NAME" || -z "$GIT_USER_EMAIL" ]]; then
    echo "Git user.name and user.email are required by repo init." >&2
    exit 1
fi

GIT_COLOR_UI=$(git config --get color.ui || true)
if [[ -z "$GIT_COLOR_UI" ]]; then
    echo "Git color.ui must be set (prefer never) for noninteractive repo init." >&2
    exit 1
fi

case "$SOURCE_DIR" in
    /mnt/*)
        echo "Refusing to place a full Android checkout on a Windows mount: $SOURCE_DIR" >&2
        echo "Use an ext4 path such as ~/src/agibot-android14." >&2
        exit 1
        ;;
esac

if [[ -e "$SOURCE_DIR" && ! -d "$SOURCE_DIR" ]]; then
    echo "Source path exists and is not a directory: $SOURCE_DIR" >&2
    exit 1
fi

mkdir -p "$SOURCE_DIR"
cd "$SOURCE_DIR"

repo init --repo-url "$REPO_URL" --repo-rev "$REPO_REV" \
    -u "$MANIFEST_URL" \
    -b "$MANIFEST_BRANCH" \
    -m "$MANIFEST_FILE"

MANIFEST_REVISION=$(git -C .repo/manifests rev-parse HEAD)
if [[ "$MANIFEST_REVISION" != "$EXPECTED_MANIFEST_REVISION" ]]; then
    echo "Manifest revision drifted." >&2
    echo "expected: $EXPECTED_MANIFEST_REVISION" >&2
    echo "actual:   $MANIFEST_REVISION" >&2
    exit 1
fi

if [[ "$DO_SYNC" -eq 1 ]]; then
    repo sync -c -j"$REPO_JOBS"
else
    echo "Manifest initialized and locked. Re-run with --sync to download source."
fi

printf '%s\n' \
    'No build command was invoked.' \
    "source_dir=$SOURCE_DIR" \
    "manifest=$MANIFEST_URL" \
    "branch=$MANIFEST_BRANCH" \
    "manifest_file=$MANIFEST_FILE" \
    "manifest_revision=$MANIFEST_REVISION"
