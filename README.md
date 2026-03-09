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

Submit a geo-tagged device uplink.

```http
POST https://mappers.helium.com/api/v1/ingest/uplink
Content-Type: application/json
```

The request body should include a `decoded.payload` object with the following required fields:

| Parameter   | Type  | Description              | Unit            | Example        |
|-------------|-------|--------------------------|-----------------|----------------|
| `latitude`  | float | Device latitude          | Decimal Degrees | `37.795186`    |
| `longitude` | float | Device longitude         | Decimal Degrees | `-122.393844`  |
| `altitude`  | int   | Device altitude          | Meters          | `10`           |
| `accuracy`  | float | Device GPS accuracy      | Meters          | `2.3`          |

Example payload:

```json
{
  "decoded": {
    "payload": {
      "latitude": 37.795186,
      "longitude": -122.393844,
      "altitude": 10,
      "accuracy": 2.3
    }
  }
}
```

**Responses:**
- `200` — Submission successful
- `400` — Required parameters missing or invalid

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

If webpack fails with `ERR_OSSL_EVP_UNSUPPORTED` (Node 17+), set:

```bash
export NODE_OPTIONS=--openssl-legacy-provider
```

### 3. Edit your environment variables:

* Open the .sample.env file located at the root of the project
* Create a Mapbox account and copy your public access token
* Paste it in place of <replace me> for the PUBLIC_MAPBOX_KEY variable. That line should now look like this:

`PUBLIC_MAPBOX_KEY=pk.ey[...the rest of your access token...]`

Rename the file ".env" (delete ".sample" from the file name)

### 4. Install Node.js dependencies with `cd assets && yarn`

### 5. Start development server:
* Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To Reset Database

  * Run `mix ecto.reset`
