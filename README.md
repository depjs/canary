# canary

Continuously verifies that [dep](https://github.com/depjs/dep) installs
representative real-world packages — react, next, express, vite, jest — and
compares it side by side with npm, pnpm, and yarn.

## Latest results

<!-- results:start -->

Install time per scenario — {cold, warm} cache × {without, with} lockfile (single run each — indicative, not a benchmark). dep keeps no cache by design, so its warm and cold times measure the same work.

| fixture | cache | lockfile | npm 11.18.0 | pnpm 11.10.0 | yarn 4.17.0 | dep 1.5.2 |
| --- | --- | --- | --- | --- | --- | --- |
| express | cold | no | 3.3s | 3.1s | 1.9s | 0.9s |
|  | cold | yes | 1.1s | 2.9s | 1.3s | 0.4s |
|  | warm | no | 2.6s | 0.8s | 1.2s | 0.7s |
|  | warm | yes | 0.7s | 0.8s | 0.6s | 0.5s |
| jest | cold | no | 16.1s | 4.2s | 5.8s | 2.6s |
|  | cold | yes | 3.6s | 2.3s | 4.9s | 2.8s |
|  | warm | no | 20.4s | 3.1s | 5.1s | 2.5s |
|  | warm | yes | 2.4s | 1.7s | 1.9s | 2.8s |
| next | cold | no | 16.8s | 6.0s | 10.2s | — |
|  | cold | yes | 8.6s | 4.1s | 7.5s | — |
|  | warm | no | 13.2s | 2.3s | 6.3s | — |
|  | warm | yes | 7.3s | 1.4s | 4.0s | — |
| react | cold | no | 1.5s | 1.3s | 1.4s | 0.8s |
|  | cold | yes | 0.5s | 1.0s | 0.7s | 0.3s |
|  | warm | no | 1.1s | 0.7s | 1.1s | 0.7s |
|  | warm | yes | 0.4s | 0.6s | 0.4s | 0.3s |
| vite | cold | no | 5.7s | 2.0s | 4.9s | 7.6s |
|  | cold | yes | 1.0s | 1.4s | 1.7s | 30.0s |
|  | warm | no | 5.2s | 1.1s | 3.2s | 7.0s |
|  | warm | yes | 0.7s | 0.8s | 0.7s | 33.6s |

Last run: [2026-07-06 14:49:51 UTC](https://github.com/depjs/canary/actions/runs/28798491996)

<!-- results:end -->

## How it works

Every 2 hours, the `check` job polls the npm registry for the latest versions
of `npm`, `pnpm`, `@yarnpkg/cli-dist` (yarn berry), and `dep`, and compares
them with the committed [`versions.json`](versions.json). When any of the four
has a new release, the full matrix runs: {npm, pnpm, yarn, dep} × {react,
next, express, vite, jest}.

Each cell measures four installs of the same fixture — every combination of
{cold, warm} cache × {without, with} lockfile:

1. **cold cache, no lockfile** — a from-scratch install that also generates
   the lockfile and warms the cache for the following runs (fixtures pin
   nothing: all dependencies are `"*"`, so the newest publish of each library
   is exercised too)
2. **warm cache, lockfile** — the CI-like fast path
3. **cold cache, lockfile** — resolution skipped, downloads still needed
4. **warm cache, no lockfile** — resolution needed, downloads cached

followed by a smoke test that actually loads the installed package and, where
it has one, runs its bin.

After every matrix run, the `publish` job rewrites the
[Latest results](#latest-results) table above with a bot commit — the front
page always shows the most recent run, including failures. When the run was
fully green, the same commit advances `versions.json` so the next poll is
quiet; a failing release is retried (and keeps failing loudly) on every poll
until it is fixed.

dep itself is installed with [`depjs/setup-depjs`](https://github.com/depjs/setup-depjs).

## Triggers

- **`schedule`** — polls every 2 hours; the matrix only runs when one of the
  four package managers released.
- **`repository_dispatch` (`package-release`)** — for instant runs. dep's own
  release workflow can ping this repo right after `npm publish`:

  ```yaml
  - name: Trigger canary
    env:
      GH_TOKEN: ${{ secrets.CANARY_DISPATCH_TOKEN }} # PAT with repo scope on depjs/canary
    run: gh api repos/depjs/canary/dispatches -f event_type=package-release
  ```

- **`workflow_dispatch`** — manual run of the full matrix from the Actions tab.
- **`push` to `main`** — validates changes to the canary itself.

## Running a cell locally

```console
$ RESULT_FILE=/tmp/result.json bash scripts/canary.sh dep react
$ node scripts/report.mjs /tmp
```

Add `--readme` to also rewrite the [Latest results](#latest-results) section,
as CI does.

## Notes

- Yarn runs with `nodeLinker: node-modules` so all four produce the same
  layout and the same smoke test applies.
- Timings are a single run per scenario — indicative, not a benchmark. See
  dep's [benchmark](https://github.com/depjs/dep#benchmark) for proper
  numbers.
- dep keeps no cache by design, so its warm and cold numbers measure the same
  work. Its lockfile runs use the npm-compatible `package-lock.json` written
  by `dep lock` (install alone never writes one).

## License

[MIT](LICENSE)
