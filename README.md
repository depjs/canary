# canary

Continuously verifies that [dep](https://github.com/depjs/dep) installs
representative real-world packages — react, next, express, vite, jest — and
compares it side by side with npm, pnpm, and yarn.

## Latest results

<!-- results:start -->

_No results yet — the first workflow run will fill this in._

<!-- results:end -->

## How it works

Every 2 hours, the `check` job polls the npm registry for the latest versions
of `npm`, `pnpm`, `@yarnpkg/cli-dist` (yarn berry), and `dep`, and compares
them with the committed [`versions.json`](versions.json). When any of the four
has a new release, the full matrix runs: {npm, pnpm, yarn, dep} × {react,
next, express, vite, jest}.

Each cell is a fresh, cold-cache, lockfile-free install (fixtures pin nothing:
all dependencies are `"*"`, so the newest publish of each library is exercised
too), followed by a smoke test that actually loads the installed package and,
where it has one, runs its bin.

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
- Timings are a single cold run each — indicative, not a benchmark. See dep's
  [benchmark](https://github.com/depjs/dep#benchmark) for proper numbers.

## License

[MIT](LICENSE)
