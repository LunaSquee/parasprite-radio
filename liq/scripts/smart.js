#!/usr/bin/env node
'use strict'

const utils = require('./utils')

let arg = (process.argv[2] || '').trim()

// Same shape the handlers got from the old url.parse(arg, true). Anything that
// isn't a URL (e.g. a plain file path) gets no hostname and is passed through.
function parseArg (s) {
  try {
    const u = new URL(s)
    return {
      href: u.href,
      protocol: u.protocol,
      hostname: u.hostname,
      pathname: u.pathname,
      query: Object.fromEntries(u.searchParams)
    }
  } catch (e) {
    return { href: s, protocol: null, hostname: null, pathname: s, query: {} }
  }
}

let parsedUrl = parseArg(arg)

let handler = null

switch (parsedUrl.protocol) {
  default:
    switch (parsedUrl.hostname) {
      case 'm.soundcloud.com':
      case 'soundcloud.com':
        handler = require('./protocols/soundcloud')
        break

      case 'www.youtube.com':
      case 'youtube.com':
      case 'youtu.be':
      case 'm.youtube.com':
        handler = require('./protocols/youtube-dl')
        break

      case 'eqbeats.org':
        handler = require('./protocols/eqbeats')
        break

      case 'pony.fm':
        handler = require('./protocols/ponyfm')
        break

      case 'bronytunes.com':
        handler = require('./protocols/bronytunes')
        break
    }

    if (!handler) {
      if (/^.*bandcamp\.com$/.test(parsedUrl.hostname)) {
        handler = require('./protocols/bandcamp')
        break
      }
    }

    break
}

if (!handler) {
  console.error('No handler found, passing through...')
  // plain paths (e.g. from MPD/the web UI) are relative to general.media_dir;
  // the media: protocol in liq/protocols.liq resolves them (absolute ones too)
  console.log(parsedUrl.protocol ? arg : 'media:' + arg)
} else {
  console.error('Using handler ' + handler.title)
  handler(arg, parsedUrl, handlerCallback)
}

function handlerCallback (o) {
  utils.formatter(o)
}
