import assert from 'node:assert'

const vite = await import('vite')
assert.equal(typeof vite.build, 'function')
console.log('vite', vite.version, 'ok')
