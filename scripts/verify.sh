#!/usr/bin/env bash
set -euo pipefail

# End-to-end verification harness.
# Boots a real team4tune-node-server, then runs the Flutter integration test on the
# Linux desktop target driving the real app against it.
#
# Usage:
#   scripts/verify.sh                      # connection + clock-sync e2e only
#   TEAM4TUNE_IT_SOURCE=<url> scripts/verify.sh   # also enqueue + verify audio advances
#
# Requires: go, flutter, xvfb-run. A real source URL exercises yt-dlp (network).

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
server_dir="$here/../team4tune-node-server"
flutter_bin="${FLUTTER:-/usr/bin/flutter}"
addr=":8090"
ws_url="ws://127.0.0.1:8090/ws"
source_url="${TEAM4TUNE_IT_SOURCE:-}"
cache_dir="$(mktemp -d)"
server_bin="$cache_dir/server"

cleanup() {
  [[ -n "${server_pid:-}" ]] && kill "$server_pid" 2>/dev/null || true
  rm -rf "$cache_dir"
}
trap cleanup EXIT

if curl -fsS "http://127.0.0.1:8090/healthz" >/dev/null 2>&1; then
  echo "error: something is already listening on $addr; stop it first" >&2
  exit 1
fi

echo "==> building server"
( cd "$server_dir" && go build -o "$server_bin" ./cmd/server )

echo "==> starting server on $addr (cache $cache_dir)"
TEAM4TUNE_ADDR="$addr" TEAM4TUNE_CACHE_DIR="$cache_dir" "$server_bin" &
server_pid=$!

echo "==> waiting for /healthz"
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:8090/healthz" >/dev/null 2>&1; then
    echo "    server up"
    break
  fi
  sleep 0.5
done

defines=(--dart-define=TEAM4TUNE_IT_URL="$ws_url")
if [[ -n "$source_url" ]]; then
  defines+=(--dart-define=TEAM4TUNE_IT_SOURCE="$source_url")
  echo "==> running playback e2e with source $source_url"
else
  echo "==> running connection/clock e2e (set TEAM4TUNE_IT_SOURCE=<url> for audio)"
fi

cd "$here"
status=0
for f in integration_test/*_test.dart; do
  echo "==> $f"
  if ! xvfb-run -a "$flutter_bin" test "$f" -d linux "${defines[@]}"; then
    status=1
  fi
done
exit $status
