#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/root_module"
output_dir="${1:-$repo_root/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

if [[ ! -f "$repo_root/core/Clash.Meta/go.mod" ]]; then
  echo 'Initialize the Clash.Meta submodule first.' >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cp -R "$source_dir/." "$tmp_dir/"
mkdir -p "$tmp_dir/bin"

(
  cd "$repo_root/core"
  CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -tags with_gvisor -trimpath \
    -ldflags='-s -w -buildid=' -o "$tmp_dir/bin/flclash-core" .
)

for script in "$tmp_dir/customize.sh" "$tmp_dir/service.sh" "$tmp_dir/bin/flclash-root"; do
  bash -n "$script"
done
chmod 755 "$tmp_dir/service.sh" "$tmp_dir/bin/flclash-root" "$tmp_dir/bin/flclash-core"
(cd "$tmp_dir" && zip -q -r "$output_dir/FlClash-root-module-arm64.zip" .)
echo "$output_dir/FlClash-root-module-arm64.zip"
