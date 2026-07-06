#!/usr/bin/env node
// Collects result.json files produced by canary.sh (one per artifact
// directory) and renders a fixtures × package-managers comparison table.

import { readdirSync, readFileSync, statSync, appendFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.argv[2] ?? 'results'

function * walk (dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) yield * walk(p)
    else if (name === 'result.json') yield p
  }
}

const results = [...walk(root)].map(p => JSON.parse(readFileSync(p, 'utf8')))
if (results.length === 0) {
  console.error(`no result.json files found under ${root}`)
  process.exit(1)
}

const PMS = ['npm', 'pnpm', 'yarn', 'dep']
const fixtures = [...new Set(results.map(r => r.fixture))].sort()
const byKey = new Map(results.map(r => [`${r.pm}/${r.fixture}`, r]))
const versionOf = pm => results.find(r => r.pm === pm)?.version

const header = ['fixture', ...PMS.map(pm => versionOf(pm) ? `${pm} ${versionOf(pm)}` : pm)]
const rows = fixtures.map(f => [f, ...PMS.map(pm => {
  const r = byKey.get(`${pm}/${f}`)
  if (!r) return '—'
  return r.ok ? `${(r.ms / 1000).toFixed(1)}s` : '❌ failed'
})])

const table = [
  `| ${header.join(' | ')} |`,
  `| ${header.map(() => '---').join(' | ')} |`,
  ...rows.map(r => `| ${r.join(' | ')} |`)
].join('\n')

const md = `## Canary results\n\nCold-cache install time (single run — indicative, not a benchmark).\n\n${table}\n`
console.log(md)
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, md)

const failed = results.filter(r => !r.ok)
if (failed.length > 0) {
  console.error(`failed: ${failed.map(r => `${r.pm}/${r.fixture}`).join(', ')}`)
}
