#!/usr/bin/env node
'use strict'
const net = require('net')
const path = require('path')
const config = require(path.join(__dirname, '../../scripts/config'))

let client = net.connect(config.liquidsoap.port_telnet, config.liquidsoap.host)
client.pipe(process.stdout)

client.on('connect', function () {
  console.log('Connected!')
  process.stdin.on('data', function (data) {
    client.write(data.toString() + '\r\n')
  })
})
client.on('end', function () {
  process.exit(0)
})
