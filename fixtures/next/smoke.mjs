import assert from 'node:assert'
import { execFileSync } from 'node:child_process'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
require.resolve('next')

// `next --version` exercises the bin link and next's own module graph.
const out = execFileSync('./node_modules/.bin/next', ['--version'], { encoding: 'utf8' })
assert.match(out, /v\d+\.\d+\.\d+/)
console.log('next', out.trim(), 'ok')
