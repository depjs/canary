import assert from 'node:assert'
import { execFileSync } from 'node:child_process'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
require.resolve('jest')

// `jest --version` exercises the bin link and jest's large module graph.
const out = execFileSync('./node_modules/.bin/jest', ['--version'], { encoding: 'utf8' })
assert.match(out, /\d+\.\d+\.\d+/)
console.log('jest', out.trim(), 'ok')
