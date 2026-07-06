#!/usr/bin/env bash
# Usage: canary.sh <npm|pnpm|yarn|dep> <fixture>
# Measures four installs of the fixture — {cold, warm} cache × {without, with}
# lockfile — runs its smoke test, and writes a result JSON to $RESULT_FILE.
set -Eeuo pipefail

pm="$1"
fixture="$2"

RUNNER_TEMP="${RUNNER_TEMP:-$(mktemp -d)}"
RESULT_FILE="${RESULT_FILE:-$RUNNER_TEMP/result.json}"

cd "$(dirname "$0")/../fixtures/$fixture"

# Caches/stores live under $RUNNER_TEMP so cold runs can wipe them without
# touching the runner's real caches. dep keeps no cache by design, so its
# warm runs measure the same work as its cold ones.
export npm_config_cache="$RUNNER_TEMP/npm-cache"
export YARN_NODE_LINKER=node-modules
export YARN_ENABLE_IMMUTABLE_INSTALLS=false
export YARN_GLOBAL_FOLDER="$RUNNER_TEMP/yarn-global"
export YARN_ENABLE_TELEMETRY=0

version="$("$pm" --version)"

declare -A ms=()

clear_cache() {
  rm -rf "$RUNNER_TEMP/npm-cache" "$RUNNER_TEMP/pnpm-store" "$RUNNER_TEMP/yarn-global" .yarn
}

clean() { # clean [--lockfile] — always removes node_modules
  rm -rf node_modules .pnp.*
  if [ "${1:-}" = "--lockfile" ]; then
    rm -f package-lock.json pnpm-lock.yaml yarn.lock
  fi
}

install_once() {
  case "$pm" in
    npm)  npm install --no-audit --no-fund ;;
    pnpm) pnpm install --store-dir "$RUNNER_TEMP/pnpm-store" ;;
    yarn) yarn install ;;
    dep)  dep install ;;
    *) echo "unknown package manager: $pm" >&2; exit 1 ;;
  esac
}

measure() { # measure <scenario>
  local start end
  start=$(date +%s%N)
  install_once
  end=$(date +%s%N)
  ms[$1]=$(( (end - start) / 1000000 ))
  echo "$pm $version installed $fixture [$1] in ${ms[$1]}ms"
}

write_result() {
  printf '{"pm":"%s","fixture":"%s","version":"%s","ok":%s,"ms":{"cold_nolock":%s,"cold_lock":%s,"warm_nolock":%s,"warm_lock":%s}}\n' \
    "$pm" "$fixture" "$version" "$1" \
    "${ms[cold_nolock]:-null}" "${ms[cold_lock]:-null}" \
    "${ms[warm_nolock]:-null}" "${ms[warm_lock]:-null}" > "$RESULT_FILE"
}

trap 'write_result false' ERR

# 1. cold cache, no lockfile — also generates the lockfile and warms the cache
clear_cache
clean --lockfile
measure cold_nolock

# dep does not write a lockfile as part of install; it has a dedicated command.
if [ "$pm" = dep ]; then dep lock; fi

has_lockfile=false
for f in package-lock.json pnpm-lock.yaml yarn.lock; do
  [ -f "$f" ] && has_lockfile=true
done

if $has_lockfile; then
  # 2. warm cache, lockfile — cache and lockfile left over from run 1
  clean
  measure warm_lock

  # 3. cold cache, lockfile
  clear_cache
  clean
  measure cold_lock
fi

# 4. warm cache, no lockfile — the cache is warm again after run 3 (or run 1)
clean --lockfile
measure warm_nolock

node smoke.mjs

trap - ERR
write_result true
echo "$pm $version: all $fixture installs finished and the smoke test passed"
