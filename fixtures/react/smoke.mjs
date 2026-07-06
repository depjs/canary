import assert from 'node:assert'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const React = require('react')
const { renderToStaticMarkup } = require('react-dom/server')

const html = renderToStaticMarkup(React.createElement('p', null, 'hi'))
assert.equal(html, '<p>hi</p>')
console.log('react', React.version, 'ok')
