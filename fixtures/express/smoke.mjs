import assert from 'node:assert'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const express = require('express')

const app = express()
assert.equal(typeof app.listen, 'function')
console.log('express', require('express/package.json').version, 'ok')
