#!/usr/bin/env node
// Compares versions.json against the npm registry's latest dist-tags and
// rewrites versions.json with what it found. Emits `changed` / `changes`
// outputs when running inside GitHub Actions.

import { readFileSync, writeFileSync, appendFileSync } from 'node:fs'

const PACKAGES = {
  npm: 'npm',
  pnpm: 'pnpm',
  yarn: '@yarnpkg/cli-dist', // yarn berry; the "yarn" package on npm is frozen at 1.x
  dep: 'dep'
}

const file = new URL('../versions.json', import.meta.url)
const known = JSON.parse(readFileSync(file, 'utf8'))

const latest = {}
const changes = []
for (const [name, pkg] of Object.entries(PACKAGES)) {
  const res = await fetch(`https://registry.npmjs.org/${pkg.replace('/', '%2f')}/latest`)
  if (!res.ok) throw new Error(`${pkg}: registry returned ${res.status}`)
  const { version } = await res.json()
  latest[name] = version
  if (known[name] !== version) changes.push(`${name} ${known[name] ?? 'none'} -> ${version}`)
}

writeFileSync(file, JSON.stringify(latest, null, 2) + '\n')

const changed = changes.length > 0
const summary = changes.join(', ')
if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, `changed=${changed}\nchanges=${summary}\n`)
}
console.log(changed ? `new releases: ${summary}` : 'no new releases')
