#!/usr/bin/env bash
# Usage: canary.sh <npm|pnpm|yarn|dep> <fixture>
# Installs the fixture's dependencies from a cold cache, runs its smoke test,
# and writes a result JSON to $RESULT_FILE.
set -euo pipefail

pm="$1"
fixture="$2"

RUNNER_TEMP="${RUNNER_TEMP:-$(mktemp -d)}"
RESULT_FILE="${RESULT_FILE:-$RUNNER_TEMP/result.json}"

cd "$(dirname "$0")/../fixtures/$fixture"

# Cold caches/stores so every run measures a real download, matching how dep
# (which keeps no cache by design) always operates.
export npm_config_cache="$RUNNER_TEMP/npm-cache"
export YARN_NODE_LINKER=node-modules
export YARN_ENABLE_IMMUTABLE_INSTALLS=false
export YARN_GLOBAL_FOLDER="$RUNNER_TEMP/yarn-global"
export YARN_ENABLE_TELEMETRY=0

rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml .yarn .pnp.*

version="$("$pm" --version)"

write_result() {
  printf '{"pm":"%s","fixture":"%s","version":"%s","ok":%s,"ms":%s}\n' \
    "$pm" "$fixture" "$version" "$1" "$2" > "$RESULT_FILE"
}

trap 'write_result false 0' ERR

start=$(date +%s%N)
case "$pm" in
  npm)  npm install --no-audit --no-fund ;;
  pnpm) pnpm install --store-dir "$RUNNER_TEMP/pnpm-store" ;;
  yarn) yarn install ;;
  dep)  dep install ;;
  *) echo "unknown package manager: $pm" >&2; exit 1 ;;
esac
end=$(date +%s%N)
ms=$(( (end - start) / 1000000 ))

node smoke.mjs

trap - ERR
write_result true "$ms"
echo "$pm $version installed $fixture in ${ms}ms and the smoke test passed"
