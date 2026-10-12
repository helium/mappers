// Pulls real San Francisco coverage from mappers.helium.com into
// priv/repo/real/sf.json (gitignored), for `mix load_real_sample`.
//
//   NODE_PATH=assets/node_modules node priv/repo/fetch_real_sample.js
//
// For another area, set BBOX (minLat,minLng,maxLat,maxLng) and NAME:
//
//   BBOX=37.30,-122.10,37.45,-121.80 NAME=san-jose NODE_PATH=assets/node_modules node priv/repo/fetch_real_sample.js
//
// Hotspot locations are rounded to the center of their res8 hex before
// anything is written, so exact hotspot (often home) addresses never touch
// disk. The map already draws hotspots at res8, so nothing visible changes.
//
// The hex API returns only the best uplink per hotspot per hex, not full
// history, and allows 60 requests a minute. Progress is saved as it goes, so
// rerunning resumes where it stopped.

const fs = require('fs')
const path = require('path')
const Pbf = require('pbf')
const { VectorTile } = require('@mapbox/vector-tile')
const { geoToH3, h3ToGeo } = require('h3-js')

const TILESERVER = 'https://mappers-tileserver.helium.wtf/public.h3_res9'
const API = 'https://mappers.helium.com/api/v1/uplinks/hex'
const OUT = path.join(__dirname, 'real', `${process.env.NAME || 'sf'}.json`)
const ZOOM = 12
const parseBbox = value => {
  const [minLat, minLng, maxLat, maxLng] = value.split(',').map(Number)
  if ([minLat, minLng, maxLat, maxLng].some(Number.isNaN) || minLat >= maxLat || minLng >= maxLng) {
    throw new Error(`BBOX must be minLat,minLng,maxLat,maxLng, got ${value}`)
  }
  return { minLat, maxLat, minLng, maxLng }
}
// San Francisco by default
const BBOX = process.env.BBOX
  ? parseBbox(process.env.BBOX)
  : { minLat: 37.70, maxLat: 37.83, minLng: -122.52, maxLng: -122.35 }
const DELAY_MS = 1100
const SAVE_EVERY = 25

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
const lngToX = lng => Math.floor((lng + 180) / 360 * 2 ** ZOOM)
const latToY = lat => {
  const rad = lat * Math.PI / 180
  return Math.floor((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2 * 2 ** ZOOM)
}

const inBbox = hexId => {
  const [lat, lng] = h3ToGeo(hexId)
  return lat >= BBOX.minLat && lat <= BBOX.maxLat && lng >= BBOX.minLng && lng <= BBOX.maxLng
}

const roundToRes8 = (lat, lng) => {
  const [rLat, rLng] = h3ToGeo(geoToH3(lat, lng, 8))
  return { lat: Number(rLat.toFixed(6)), lng: Number(rLng.toFixed(6)) }
}

const fetchTileHexes = async (x, y) => {
  const res = await fetch(`${TILESERVER}/${ZOOM}/${x}/${y}.pbf`)
  if (res.status === 204) return []
  if (!res.ok) throw new Error(`tile ${ZOOM}/${x}/${y} returned ${res.status}`)
  const layer = new VectorTile(new Pbf(Buffer.from(await res.arrayBuffer()))).layers['public.h3_res9']
  if (!layer) return []
  return Array.from({ length: layer.length }, (_, i) => layer.feature(i).properties.id)
}

const fetchHexUplinks = async (hexId, attempt = 1) => {
  const res = await fetch(`${API}/${hexId}`)
  if (res.status === 429 && attempt <= 3) {
    console.log('rate limited, waiting a minute')
    await sleep(60_000)
    return fetchHexUplinks(hexId, attempt + 1)
  }
  if (!res.ok) throw new Error(`hex ${hexId} returned ${res.status}`)
  const { uplinks } = await res.json()
  return uplinks.map(u => ({
    hotspot_name: u.hotspot_name,
    rssi: u.rssi,
    snr: u.snr,
    timestamp: u.timestamp,
    ...roundToRes8(u.lat, u.lng)
  }))
}

const load = () => {
  try {
    return JSON.parse(fs.readFileSync(OUT, 'utf8'))
  } catch (err) {
    if (err.code !== 'ENOENT') throw err
    return { source: 'mappers.helium.com', bbox: BBOX, hexes: {} }
  }
}

const save = sample => {
  fs.mkdirSync(path.dirname(OUT), { recursive: true })
  sample.fetched_at = new Date().toISOString()
  fs.writeFileSync(OUT, JSON.stringify(sample))
}

const main = async () => {
  const sample = load()
  const tiles = []
  for (let x = lngToX(BBOX.minLng); x <= lngToX(BBOX.maxLng); x++) {
    for (let y = latToY(BBOX.maxLat); y <= latToY(BBOX.minLat); y++) tiles.push([x, y])
  }

  const tileHexes = await Promise.all(tiles.map(([x, y]) => fetchTileHexes(x, y)))
  const hexIds = [...new Set(tileHexes.flat())].filter(inBbox)
  const todo = hexIds.filter(id => !(id in sample.hexes))
  console.log(`${hexIds.length} hexes in the area, ${todo.length} to fetch (~${Math.ceil(todo.length * DELAY_MS / 60_000)} min)`)

  for (const [i, id] of todo.entries()) {
    try {
      sample.hexes[id] = await fetchHexUplinks(id)
    } catch (err) {
      console.error(err.message)
    }
    if ((i + 1) % SAVE_EVERY === 0) {
      save(sample)
      console.log(`${i + 1}/${todo.length}`)
    }
    await sleep(DELAY_MS)
  }

  save(sample)
  console.log(`saved ${Object.keys(sample.hexes).length} hexes to ${OUT}`)
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
