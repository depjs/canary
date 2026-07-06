#!/usr/bin/env bash
# Usage: canary.sh <npm|pnpm|yarn|dep> <fixture>
# Measures the fixture across four scenarios — {cold, warm} cache × {without,
# with} lockfile — timing each scenario $REPS times and keeping the median,
# then runs its smoke test and writes a result JSON to $RESULT_FILE.
set -Eeuo pipefail

pm="$1"
fixture="$2"

RUNNER_TEMP="${RUNNER_TEMP:-$(mktemp -d)}"
RESULT_FILE="${RESULT_FILE:-$RUNNER_TEMP/result.json}"
REPS="${REPS:-5}"

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

# Preconditions restored before every repetition of a scenario.
prep_cold_nolock() { clear_cache; clean --lockfile; }
prep_cold_lock()   { clear_cache; clean; }
prep_warm_nolock() { clean --lockfile; }
prep_warm_lock()   { clean; }

install_once() {
  case "$pm" in
    npm)  npm install --no-audit --no-fund ;;
    # --dangerously-allow-all-builds: npm, yarn and dep run build scripts by
    # default; without it pnpm >= 11 hard-fails on unapproved ones (sharp).
    pnpm) pnpm install --store-dir "$RUNNER_TEMP/pnpm-store" --dangerously-allow-all-builds ;;
    yarn) yarn install ;;
    dep)  dep install ;;
    *) echo "unknown package manager: $pm" >&2; exit 1 ;;
  esac
}

median() { # median <ms>... — middle value; mean of the middle two when even
  printf '%s\n' "$@" | sort -n |
    awk '{ v[NR] = $1 } END { m = int((NR + 1) / 2); print NR % 2 ? v[m] : int((v[m] + v[m + 1]) / 2) }'
}

measure() { # measure <scenario> <prep-fn> — $REPS timed installs, median kept
  local scenario="$1" prep="$2" start end rep took times=()
  for ((rep = 1; rep <= REPS; rep++)); do
    "$prep"
    start=$(date +%s%N)
    install_once
    end=$(date +%s%N)
    took=$(( (end - start) / 1000000 ))
    times+=("$took")
    echo "$pm $version installed $fixture [$scenario $rep/$REPS] in ${took}ms"
  done
  ms[$scenario]=$(median "${times[@]}")
  echo "$pm $version $fixture [$scenario] median of $REPS: ${ms[$scenario]}ms"
}

write_result() {
  printf '{"pm":"%s","fixture":"%s","version":"%s","ok":%s,"reps":%s,"ms":{"cold_nolock":%s,"cold_lock":%s,"warm_nolock":%s,"warm_lock":%s}}\n' \
    "$pm" "$fixture" "$version" "$1" "$REPS" \
    "${ms[cold_nolock]:-null}" "${ms[cold_lock]:-null}" \
    "${ms[warm_nolock]:-null}" "${ms[warm_lock]:-null}" > "$RESULT_FILE"
}

trap 'write_result false' ERR

# 1. cold cache, no lockfile — the last repetition also generates the lockfile
#    and warms the cache for the following scenarios
measure cold_nolock prep_cold_nolock

# dep does not write a lockfile as part of install; it has a dedicated command.
if [ "$pm" = dep ]; then dep lock; fi

has_lockfile=false
for f in package-lock.json pnpm-lock.yaml yarn.lock; do
  [ -f "$f" ] && has_lockfile=true
done

if $has_lockfile; then
  # 2. warm cache, lockfile — cache and lockfile left over from scenario 1
  measure warm_lock prep_warm_lock

  # 3. cold cache, lockfile
  measure cold_lock prep_cold_lock
fi

# 4. warm cache, no lockfile — the cache is warm again after scenario 3 (or 1)
measure warm_nolock prep_warm_nolock

node smoke.mjs

trap - ERR
write_result true
echo "$pm $version: all $fixture installs finished and the smoke test passed"
