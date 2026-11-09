#!/usr/bin/env node
'use strict'

// Last.fm scrobbling (API 2.0), called from liq/radio.liq:
//   node scripts/lastfm nowplaying '<metadata json>'
//   node scripts/lastfm scrobble   '<metadata json>' <unix start timestamp>
//
// Needs in conf/radio.toml:
//   [lastfm]      enable = true, username, password
//   [lastfm.api]  key, secret   (create one at https://www.last.fm/api/account/create)
//
// The session key from auth.getMobileSession is cached in a file so we don't
// log in for every track; it's refreshed automatically if Last.fm rejects it.

const crypto = require('crypto')
const fs = require('fs')
const os = require('os')
const path = require('path')
const config = require('../../scripts/config')

const API_URL = process.env.LASTFM_API_URL || 'https://ws.audioscrobbler.com/2.0/'
const SESSION_FILE = process.env.LASTFM_SESSION_FILE ||
  path.join(os.tmpdir(), 'parasprite-lastfm-session.json')
const TIMEOUT = 15 * 1000

// Last.fm error codes meaning "get a new session key"
const ERR_INVALID_SESSION = 9
const ERR_UNAUTHORIZED_TOKEN = 14

const lastfm = config.lastfm || {}
const api = lastfm.api || {}

function fail (msg) {
  console.error('Last.fm: ' + msg)
  process.exit(1)
}

// https://www.last.fm/api/authspec#_8-signing-calls
function sign (params) {
  const str = Object.keys(params)
    .filter((k) => k !== 'format' && k !== 'callback')
    .sort()
    .map((k) => k + params[k])
    .join('')
  return crypto.createHash('md5').update(str + api.secret, 'utf8').digest('hex')
}

async function call (method, params) {
  const body = Object.assign({ method, api_key: api.key }, params)
  for (const k of Object.keys(body)) {
    if (body[k] === undefined || body[k] === null || body[k] === '') delete body[k]
  }
  body.api_sig = sign(body)
  body.format = 'json'

  const res = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': (config.general && config.general.userAgent) || 'ParaspriteRadio'
    },
    body: new URLSearchParams(body).toString(),
    signal: AbortSignal.timeout(TIMEOUT)
  })
  const text = await res.text()
  let data
  try {
    data = JSON.parse(text)
  } catch (e) {
    throw Object.assign(new Error('HTTP ' + res.status + ': ' + text.slice(0, 200)), { code: null })
  }
  if (data.error) {
    throw Object.assign(new Error(data.message + ' (error ' + data.error + ')'), { code: data.error })
  }
  return data
}

function readSession () {
  try {
    const s = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'))
    // only reuse it for the same account/API key
    if (s.username === lastfm.username && s.apiKey === api.key && s.key) return s.key
  } catch (e) {}
  return null
}

async function getSession (fresh) {
  if (!fresh) {
    const cached = readSession()
    if (cached) return cached
  }
  const data = await call('auth.getMobileSession', {
    username: lastfm.username,
    password: lastfm.password
  })
  const key = data.session && data.session.key
  if (!key) throw new Error('no session key in response')
  try {
    fs.writeFileSync(SESSION_FILE, JSON.stringify({ username: lastfm.username, apiKey: api.key, key }), { mode: 0o600 })
  } catch (e) {
    console.error('Last.fm: could not cache session key: ' + e.message)
  }
  return key
}

// call with a session key, logging in again once if the cached one is stale
async function authedCall (method, params) {
  let sk = await getSession(false)
  try {
    return await call(method, Object.assign({ sk }, params))
  } catch (e) {
    if (e.code !== ERR_INVALID_SESSION && e.code !== ERR_UNAUTHORIZED_TOKEN) throw e
    sk = await getSession(true)
    return call(method, Object.assign({ sk }, params))
  }
}

function trackParams (m) {
  const duration = Math.round(parseFloat(m.duration))
  return {
    artist: m.artist,
    track: m.title,
    album: m.album,
    albumArtist: m.albumartist || m.album_artist,
    trackNumber: m.tracknumber && parseInt(m.tracknumber, 10) > 0 ? parseInt(m.tracknumber, 10) : undefined,
    duration: duration > 0 ? duration : undefined
  }
}

async function main () {
  const [action, json, timestamp] = process.argv.slice(2)

  if (!lastfm.enable) return
  if (!api.key || !api.secret) fail('lastfm.api.key and lastfm.api.secret must be set in conf/radio.toml')
  if (!lastfm.username || !lastfm.password) fail('lastfm.username and lastfm.password must be set in conf/radio.toml')

  let m
  try {
    m = JSON.parse(json || '{}')
  } catch (e) {
    fail('invalid metadata JSON: ' + e.message)
  }
  const track = trackParams(m)
  if (!track.artist || !track.track) {
    console.error('Last.fm: skipping track without artist/title')
    return
  }

  if (action === 'nowplaying') {
    await authedCall('track.updateNowPlaying', track)
    console.log('Last.fm: now playing ' + track.artist + ' - ' + track.track)
  } else if (action === 'scrobble') {
    const ts = parseInt(timestamp, 10)
    if (!(ts > 0)) fail('scrobble needs a unix timestamp')
    const res = await authedCall('track.scrobble', Object.assign({ timestamp: ts, chosenByUser: 0 }, track))
    const s = res.scrobbles && res.scrobbles['@attr']
    if (s && +s.ignored > 0) {
      const sc = [].concat(res.scrobbles.scrobble)[0] || {}
      const why = sc.ignoredMessage && (sc.ignoredMessage['#text'] || sc.ignoredMessage.code)
      console.error('Last.fm: scrobble ignored: ' + why)
    } else {
      console.log('Last.fm: scrobbled ' + track.artist + ' - ' + track.track)
    }
  } else {
    fail('usage: lastfm <nowplaying|scrobble> <metadata json> [timestamp]')
  }
}

main().catch((e) => fail(e.message))
