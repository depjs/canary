# canary

Continuously verifies that [dep](https://github.com/depjs/dep) installs
representative real-world packages — react, next, express, vite, jest — and
compares it side by side with npm, pnpm, and yarn.

## Latest results

<!-- results:start -->

Install time per scenario — {cold, warm} cache × {without, with} lockfile (median of 5 runs each, fastest per row in ${\color{green}\textsf{green}}$). dep keeps no cache by design, so its warm and cold times measure the same work.

| fixture | cache | lockfile | npm 12.0.1 | pnpm 11.15.1 | yarn 4.17.1 | dep 1.5.7 |
| --- | --- | --- | --- | --- | --- | --- |
| express | cold | no | 1.5s | 1.0s | 1.3s | ${\color{green}\textsf{0.6s}}$ |
|  | cold | yes | 0.7s | 1.0s | 1.0s | ${\color{green}\textsf{0.4s}}$ |
|  | warm | no | ${\color{green}\textsf{0.5s}}$ | 0.7s | 0.8s | ${\color{green}\textsf{0.5s}}$ |
|  | warm | yes | ${\color{green}\textsf{0.4s}}$ | 0.7s | ${\color{green}\textsf{0.4s}}$ | ${\color{green}\textsf{0.4s}}$ |
| jest | cold | no | 9.8s | 2.8s | 4.3s | ${\color{green}\textsf{2.0s}}$ |
|  | cold | yes | 2.9s | 1.7s | 2.9s | ${\color{green}\textsf{1.1s}}$ |
|  | warm | no | 3.6s | 2.2s | 2.1s | ${\color{green}\textsf{2.0s}}$ |
|  | warm | yes | 2.0s | ${\color{green}\textsf{1.1s}}$ | 1.5s | ${\color{green}\textsf{1.1s}}$ |
| next | cold | no | 10.3s | 3.3s | 7.6s | ${\color{green}\textsf{2.7s}}$ |
|  | cold | yes | 7.3s | 2.5s | 5.8s | ${\color{green}\textsf{1.7s}}$ |
|  | warm | no | 7.5s | ${\color{green}\textsf{1.8s}}$ | 3.7s | 2.7s |
|  | warm | yes | 6.4s | ${\color{green}\textsf{1.0s}}$ | 3.2s | 1.7s |
| react | cold | no | 1.2s | 0.9s | 1.1s | ${\color{green}\textsf{0.5s}}$ |
|  | cold | yes | 0.5s | 0.8s | 0.6s | ${\color{green}\textsf{0.2s}}$ |
|  | warm | no | 0.6s | 0.8s | 0.5s | ${\color{green}\textsf{0.4s}}$ |
|  | warm | yes | 0.4s | 0.6s | 0.3s | ${\color{green}\textsf{0.2s}}$ |
| vite | cold | no | 3.7s | 1.4s | 3.0s | ${\color{green}\textsf{0.9s}}$ |
|  | cold | yes | 0.9s | 1.2s | 1.2s | ${\color{green}\textsf{0.4s}}$ |
|  | warm | no | 1.4s | 0.8s | ${\color{green}\textsf{0.7s}}$ | 0.8s |
|  | warm | yes | 0.7s | 0.7s | 0.5s | ${\color{green}\textsf{0.4s}}$ |

Last run: [2026-07-22 03:52:13 UTC](https://github.com/depjs/canary/actions/runs/29889404155)

<!-- results:end -->

## How it works

Every 2 hours, the `check` job polls the npm registry for the latest versions
of `npm`, `pnpm`, `@yarnpkg/cli-dist` (yarn berry), and `dep`, and compares
them with the committed [`versions.json`](versions.json). When any of the four
has a new release, the full matrix runs: {npm, pnpm, yarn, dep} × {react,
next, express, vite, jest}.

Each cell measures four scenarios of the same fixture — every combination of
{cold, warm} cache × {without, with} lockfile. Each scenario is installed 5
times (override with `REPS`) and the median is reported, so one slow network
round-trip or a noisy runner neighbour cannot skew a published number:

1. **cold cache, no lockfile** — a from-scratch install that also generates
   the lockfile and warms the cache for the following scenarios (fixtures pin
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
- Timings are the median of 5 runs per scenario on shared CI runners —
  stable against outliers, but absolute numbers still vary with the runner
  and the network. Compare the tools within a row rather than numbers across
  runs.
- dep keeps no cache by design, so its warm and cold numbers measure the same
  work. Its lockfile runs use the npm-compatible `package-lock.json` written
  by `dep lock` (install alone never writes one).

## License

[MIT](LICENSE)
