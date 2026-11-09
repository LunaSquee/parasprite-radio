'use strict'

const path = require('path')
const config = require(path.join(__dirname, 'config'))

const MAX_REDIRECTS = 5
const TIMEOUT = 15 * 1000

function fetcher (url, opt, callback, redirects = 0) {
  let sentCallback = false
  if (typeof opt === 'function') {
    callback = opt
    opt = {}
  }
  opt = opt || {}
  let parsed
  try {
    parsed = new URL(url)
  } catch (e) {
    callback('Invalid URL: ' + url)
    return
  }
  let opts = {
    hostname: parsed.hostname,
    port: parsed.port || undefined,
    path: parsed.pathname + parsed.search,
    timeout: TIMEOUT,
    headers: {
      'user-agent': config.general.userAgent || 'node'
    }
  }

  for (let k in opt) {
    if (k !== 'stream') opts[k] = opt[k]
  }

  let httpModule = parsed.protocol === 'https:' ? require('https') : require('http')
  httpModule.get(opts, function (res) {
    if ([301, 302, 303, 307, 308].indexOf(res.statusCode) !== -1 && res.headers.location) {
      res.resume()
      sentCallback = true
      if (redirects >= MAX_REDIRECTS) {
        callback('Too many redirects')
        return
      }
      // Location may be relative
      fetcher(new URL(res.headers.location, parsed).href, opt, callback, redirects + 1)
      return
    }
    let data = []
    if (opt.stream) {
      if (!sentCallback) {
        callback(null, res)
        sentCallback = true
      }
    } else {
      res.on('data', function (chunk) {
        data.push(chunk)
      })

      res.on('end', function () {
        if (!sentCallback) {
          callback(null, Buffer.concat(data))
          sentCallback = true
        }
      })
    }
  }).on('timeout', function () {
    this.destroy(new Error('Request timed out: ' + url))
  }).on('error', function (e) {
    if (!sentCallback) {
      callback(e.message)
      sentCallback = true
    }
  })
}

function fetchJSON (url, opt, callback) {
  fetcher(url, opt, function (err, data) {
    if (err) {
      callback(err, data)
      return
    }
    let obj
    try {
      obj = JSON.parse(data)
    } catch (err) {
      callback(err, data + '')
      return
    }
    callback(null, obj)
  })
}

function fetchXML (url, opt, callback) {
  fetcher(url, opt, function (err, data) {
    if (err) {
      callback(err, data)
      return
    }
    const parser = require('xml2js')
    parser.parseString(data, callback)
  })
}

module.exports = {
  fetcher: fetcher,
  fetchJSON: fetchJSON,
  fetchXML: fetchXML
}
