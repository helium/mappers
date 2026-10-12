# Mappers

The Mappers project is a crowd-sourced effort to build a true-signal coverage map of the Helium network across the globe.

The Mappers tool lets you see the areas that have been explored by participants in the project, and the Helium Hotspots that have provided coverage to those areas. By mapping real-world coverage, network users can understand where sensor deployments are proven to work.

## How Does Mappers Work?

Participants use low-cost LoRaWAN devices to survey the real-world network created by Helium. Many contributors bring their mapper with them when they walk, hike, bike, drive, or even boat. They're small and fit well in a pocket or on a car dash.

In order to place a mark on the map, the mapper device sends out a signal with a GPS location encoded. If a Helium Hotspot "hears" that signal, data is passed through the internet and recorded in the Mappers database. The Mappers database uses the GPS information from the mapper to "light up" the hex on the map.

## Why Contribute to Mappers?

**For Hotspot owners:** The collected data helps visualize the coverage provided by all Helium Hotspots — identifying areas where coverage is lacking or where Hotspot placements could participate in Proof of Coverage with other Hotspots. A marked hex on the map indicates that uplink signals from registered Helium LoRaWAN sensors have been proven to be "heard" by the Helium network somewhere within that hex-shaped area.

**For network users:** The map proves the real-world coverage that Hotspots provide. This real-world evidence at the scale and resolution offered by the map gives prospective network users the information they need to make decisions about their deployments.

### How can I use Mappers for my own Hotspot deployments?

- Find new locations for Hotspots
- Get real-world information about how far your Hotspot reaches
- Learn RF data analytics in an interactive way

### How can I use Mappers for my own sensor deployments?

Take a mapping device to the area where you want to deploy sensors and watch to see if it is picked up by a Hotspot. If it's picked up by only one Hotspot, decide if you want to deploy an additional Hotspot in that area for sensor connection redundancy. Look at existing mapped areas for confirmation that your sensors can be deployed in that area and how many Hotspots can pick them up.

## Mappers API

The Mappers API accepts HTTP requests for submitting coverage data. No authentication is currently required.

### Ingest Uplink

Submit geo-tagged uplinks from a mapper device.

```http
POST https://mappers.helium.com/api/v1/ingest/uplink
Content-Type: application/json
```

#### Submitting from ChirpStack

Add an HTTP integration to a ChirpStack v4 application that holds your mapper devices:

- **Event endpoint URL:** `https://mappers.helium.com/api/v1/ingest/uplink`
- **Payload encoding:** JSON (Protobuf is not supported)

ChirpStack posts every event type to the endpoint. Only uplinks (`up` events) are mapped; other events are acknowledged and ignored. Keep mapper devices in their own application, since uplinks without a position are rejected.

The device profile's codec must decode each uplink into an `object` with these fields:

| Field       | Type   | Description         | Unit            | Example       |
|-------------|--------|---------------------|-----------------|---------------|
| `latitude`  | number | Device latitude     | Decimal Degrees | `37.795186`   |
| `longitude` | number | Device longitude    | Decimal Degrees | `-122.393844` |
| `altitude`  | number | Device altitude     | Meters          | `10`          |
| `accuracy`  | number | Device GPS accuracy | Meters          | `2.3`         |

```json
{
  "latitude": 37.795186,
  "longitude": -122.393844,
  "altitude": 10,
  "accuracy": 2.3
}
```

A codec may also set `fixFailed: true` when the device has no GPS fix, so a stale last-known position isn't mapped.

Hotspot locations come from the gateway metadata that Helium Packet Router adds to each `rxInfo` entry, so only uplinks heard by Helium Hotspots with an asserted location are mapped. Hotspots more than 500 km from the device are left out.

#### Helium Console format

Uplinks posted by a Helium Console HTTP integration are still accepted. The same fields go in `decoded.payload`.

#### Responses

- `200` — Uplink stored
- `204` — A ChirpStack event that isn't an uplink; nothing stored
- `415` — The body isn't sent as `application/json`
- `422` — The uplink can't be mapped. The body names the reason, e.g. `{"error": "no_position", "detail": "..."}`. Common reasons:
  - `no_position` — no numeric `latitude`/`longitude`, or either is 0
  - `no_fix` — the device reported `fixFailed: true`
  - `decoder_error` — the payload decoder reported an error
  - `invalid_altitude` / `invalid_accuracy` — missing or out of range
  - `no_hotspot_location` / `no_valid_hotspots` — none of the Hotspots that heard the uplink could be mapped (e.g. no location, or more than 500 km away)
  - `unsupported_payload` — the body is neither a ChirpStack uplink nor a Console uplink
- `500` — The uplink could not be stored

### Uplinks in a hex

```http
GET https://mappers.helium.com/api/v1/uplinks/hex/:h3_index
```

Returns the best uplink per hotspot that heard a device in a resolution 9 H3 hex. Optional query parameters narrow it down:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `start`   | Heard at or after, ISO 8601 date or datetime (UTC) | `2025-01-01` |
| `end`     | Heard before (exclusive) | `2025-04-01` |
| `hotspot` | Exact hotspot name | `happy-amber-moose` |

### Hotspot search

```http
GET https://mappers.helium.com/api/v1/hotspots?q=happy amber
```

Returns up to 20 hotspots whose name starts with `q` (spaces count as dashes), with their location. `q` must be at least 2 characters.

### Filtered coverage tiles

The Martin function source `public.h3_res9_filtered` serves the same tiles as `public.h3_res9`, with `best_rssi` and `snr` recomputed from the uplinks that match the same `start`, `end`, and `hotspot` parameters:

```
/rpc/public.h3_res9_filtered/{z}/{x}/{y}.pbf?start=2025-01-01&hotspot=happy-amber-moose
```

## Development and Contribution

Any and all contributions from the community are encouraged.

- Guidelines for how to contribute to this repository [are here](https://github.com/helium/mappers/blob/master/CONTRIBUTING.md).

## Getting Started

### 1. First, clone the repository to your local machine and navigate into the folder. For example:

```bash
git clone https://github.com/helium/mappers.git
cd mappers
```

### 2. Second, install all the dependencies:

#### System dependencies:
* Xcode Command Line Tools (`xcode-select --install`)
* cmake
* postgres - add user/password postgres/postgres
* postgis

#### Application Dependencies:
* Install dependencies with `mix deps.get`
* Create and migrate your database with `mix ecto.setup`

#### macOS troubleshooting:

If the h3 native dependency fails to compile with `'stdio.h' file not found`, set the SDK root:

```bash
export SDKROOT=$(xcrun --show-sdk-path)
```

If the h3 native dependency fails with `Compatibility with CMake < 3.5 has been removed from CMake` (CMake 4+), set the policy minimum and recompile it:

```bash
export CMAKE_POLICY_VERSION_MINIMUM=3.5
mix deps.compile h3 --force
```

`mix phx.server` sets this for its webpack watcher. If you run webpack yourself and it fails with `ERR_OSSL_EVP_UNSUPPORTED` (Node 17+), set:

```bash
export NODE_OPTIONS=--openssl-legacy-provider
```

### 3. Edit your environment variables:

* Open the .sample.env file located at the root of the project
* Create a Mapbox account and copy your public access token
* Paste it in place of <replace me> for the PUBLIC_MAPBOX_KEY variable. That line should now look like this:

`PUBLIC_MAPBOX_KEY=pk.ey[...the rest of your access token...]`

Rename the file ".env" (delete ".sample" from the file name)

The map uses the production Mapbox style by default, which other tokens can't read. Set `PUBLIC_MAPBOX_STYLE` in `.env` to a style your token can read, such as:

`PUBLIC_MAPBOX_STYLE=mapbox://styles/mapbox/dark-v11`

### 4. Install Node.js dependencies with `cd assets && yarn`

Run this after `mix deps.get`. The `phoenix` and `phoenix_html` packages install from `deps/`, so yarn fails with `refers to a non-existing file` if the Elixir deps aren't fetched yet.

### 5. Start development server:
* Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To Reset Database

  * Run `mix ecto.reset`

### Local tile server

The map's coverage hexes are vector tiles served by [Martin](https://github.com/maplibre/martin) straight from the `h3_res9` table, not by Phoenix. By default the app uses the production tile server, so you see production coverage. To see your local database instead, run Martin from `docker-martin/`:

```bash
docker build --platform linux/amd64 -t mappers-martin docker-martin
docker run -d --name mappers-martin --platform linux/amd64 -p 3500:3500 \
  -e DATABASE_URL=postgres://postgres:postgres@host.docker.internal:5432/mappers_dev \
  -e PORT=3500 -e POOL_SIZE=10 mappers-martin
```

Then set `PUBLIC_TILESERVER_URL=http://localhost:3500` in `.env` and restart `mix phx.server`. Keep `POOL_SIZE` low: the config's default of 150 connections is more than a local Postgres allows, and Martin hangs at startup without saying why.

To Load Real Coverage Data

  * Run `NODE_PATH=assets/node_modules node priv/repo/fetch_real_sample.js` to pull San Francisco coverage from mappers.helium.com into `priv/repo/real/sf.json`. The hex API allows 60 requests a minute, so this takes about 20 minutes, and rerunning resumes where it stopped. Set `BBOX` and `NAME` for another area (see the script header).
  * Run `mix load_real_sample --reset` (or pass a path) to replay it through the ingest pipeline.
  * The API returns only the best uplink per hotspot per hex, so date filters see less history than production has. Hotspot locations are rounded to their res8 hex before they're saved, and `priv/repo/real/` is gitignored: don't commit pulled data.

To Seed Synthetic Coverage Data

  * Run `mix seed_synthetic --reset` to fill the local database with fake hotspots and mapper drives around San Francisco, from mid-2021 to late 2026. It replays them through the real ingest pipeline. See `mix help seed_synthetic` for options.
