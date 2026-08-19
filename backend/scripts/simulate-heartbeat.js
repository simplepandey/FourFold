#!/usr/bin/env node
/**
 * Simulates a device's heartbeat reply — for testing GET /module-status/:productCode
 * without real ESP hardware.
 *
 * Flow: open the device in the app (or curl GET /module-status/:productCode) — the
 * server logs "Heartbeat requested for '<productCode>' — cmd_id: <id>". Copy that
 * id and run this script; module_status flips to isOnline: true on the next poll.
 *
 * Usage:
 *   node scripts/simulate-heartbeat.js <productCode> <cmd_id> [voltage] [current] [overcurrent] [undercurrent]
 *
 * Defaults: voltage=231.5 current=3.8 overcurrent=8 undercurrent=0.5
 */
const fs = require('fs');
const path = require('path');
const mqtt = require('mqtt');

const [, , productCode, cmdId, v = '231.5', i = '3.8', oc = '8', uc = '0.5'] = process.argv;

if (!productCode || !cmdId) {
  console.error(
    'Usage: node scripts/simulate-heartbeat.js <productCode> <cmd_id> [voltage] [current] [overcurrent] [undercurrent]',
  );
  console.error(
    "Get <cmd_id> from the server log line: \"Heartbeat requested for '<productCode>' — cmd_id: ...\"",
  );
  process.exit(1);
}

const envPath = path.join(__dirname, '..', '.env');
const env = fs.readFileSync(envPath, 'utf8');
const get = (key) => env.match(new RegExp(`^${key}=(.*)$`, 'm'))?.[1];

const client = mqtt.connect({
  host: get('MQTT_HOST'),
  port: Number(get('MQTT_PORT')),
  username: get('MQTT_USERNAME'),
  password: get('MQTT_PASSWORD'),
  protocol: 'mqtt',
});

client.on('connect', () => {
  const topic = `motors/${productCode}/heartbeat`;
  const payload = JSON.stringify({ id: cmdId, v: Number(v), i: Number(i), oc: Number(oc), uc: Number(uc) });

  client.publish(topic, payload, (err) => {
    if (err) {
      console.error('Failed to publish:', err.message);
      process.exitCode = 1;
    } else {
      console.log(`Published to ${topic}:`);
      console.log(payload);
    }
    client.end();
  });
});

client.on('error', (err) => {
  console.error('MQTT connection error:', err.message);
  process.exit(1);
});
