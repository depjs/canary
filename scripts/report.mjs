#!/usr/bin/env node
// Collects result.json files produced by canary.sh (one per artifact
// directory) and renders a fixtures × package-managers comparison table.
// With --readme, also rewrites the section between the results markers in
// README.md so the repository front page always shows the latest run.

import { readdirSync, readFileSync, writeFileSync, statSync, appendFileSync } from 'node:fs'
import { join } from 'node:path'

const args = process.argv.slice(2)
const updateReadme = args.includes('--readme')
const root = args.find(a => !a.startsWith('--')) ?? 'results'

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

const stamp = new Date().toISOString().replace('T', ' ').replace(/\.\d+Z/, ' UTC')
const runUrl = process.env.GITHUB_RUN_ID
  ? `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
  : null
const stampLine = runUrl ? `Last run: [${stamp}](${runUrl})` : `Last run: ${stamp}`
const body = `Cold-cache install time (single run — indicative, not a benchmark).\n\n${table}\n\n${stampLine}`

const md = `## Canary results\n\n${body}\n`
console.log(md)
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, md)

if (updateReadme) {
  const readmePath = new URL('../README.md', import.meta.url)
  const readme = readFileSync(readmePath, 'utf8')
  const START = '<!-- results:start -->'
  const END = '<!-- results:end -->'
  if (!readme.includes(START) || !readme.includes(END)) {
    console.error('README.md is missing the results markers')
    process.exit(1)
  }
  const updated = readme.slice(0, readme.indexOf(START) + START.length) +
    `\n\n${body}\n\n` +
    readme.slice(readme.indexOf(END))
  writeFileSync(readmePath, updated)
  console.log('README.md updated')
}

const failed = results.filter(r => !r.ok)
if (failed.length > 0) {
  console.error(`failed: ${failed.map(r => `${r.pm}/${r.fixture}`).join(', ')}`)
}
