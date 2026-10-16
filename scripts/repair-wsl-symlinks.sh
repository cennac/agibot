#!/usr/bin/env bash
set -euo pipefail

build_tree="${1:?usage: repair-wsl-symlinks.sh <armbian-build-tree>}"
cd "$build_tree"

repaired=0
while IFS= read -r entry; do
	path="${entry#*$'\t'}"
	target="$(git show "HEAD:$path")"

	if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then
		continue
	fi

	if [ -e "$path" ] && [ "$(cat "$path")" != "$target" ]; then
		echo "refusing to replace modified symlink placeholder: $path" >&2
		exit 1
	fi

	if [ -L "$path" ] || [ -f "$path" ]; then
		unlink "$path"
	else
		echo "refusing to replace non-file symlink placeholder: $path" >&2
		exit 1
	fi
	ln -s "$target" "$path"
	repaired=$((repaired + 1))
done < <(git ls-files -s | grep '^120000 ')

echo "repaired symlinks: $repaired"
