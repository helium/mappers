import * as React from 'react';
import { useState, useRef } from 'react';
import MapGL, { Source, Layer, FlyToInterpolator, LinearInterpolator, WebMercatorViewport, GeolocateControl, LngLat } from 'react-map-gl';
import InfoPane from "../components/InfoPane"

import { uplinkTileServerLayer, hotspotTileServerLayer, uplinkHotspotsLineLayer, uplinkHotspotsCircleLayer, uplinkHotspotsHexLayer, uplinkChannelLayer, selectedHotspotLayer, COLOR_BY_SIGNAL, COLOR_BY_LAST_HEARD } from './Layers.js';
import bbox from '@turf/bbox';
import { get } from '../data/Rest'
import { geoToH3, h3ToGeo, h3ToGeoBoundary } from "h3-js";
import socket from "../socket";
import geojson2h3 from 'geojson2h3';

import '../../css/app.css';
import { useNavigate, useLocation } from "react-router-dom";

const MAPBOX_TOKEN = process.env.PUBLIC_MAPBOX_KEY;
const MAPBOX_STYLE = process.env.PUBLIC_MAPBOX_STYLE;
const TILESERVER_URL = process.env.PUBLIC_TILESERVER_URL;
const TILE_LAYER = 'public.h3_res9'
const CHANNEL_LAYER = 'uplinkChannelLayer'
// only coverage hexes take clicks, so the hotspot overlays drawn for a
// selected hex never shadow the hexes beneath them
const HEX_LAYERS = [TILE_LAYER, CHANNEL_LAYER]
// h3 index string of the selected hex; both hex sources key features by it
var selectedHexId = null;
const channel = socket.channel("h3:new")
const EMPTY_FILTERS = { start: '', end: '', hotspot: '' }
const DAY_MS = 24 * 60 * 60 * 1000
const COLOR_BY_KEY = 'mappers.colorBy'

// localStorage can be missing or throw (private mode, blocked storage), and the
// choice is only a convenience, so fall back to signal.
const loadColorBy = () => {
    try {
        const saved = window.localStorage.getItem(COLOR_BY_KEY)
        return saved === COLOR_BY_LAST_HEARD ? COLOR_BY_LAST_HEARD : COLOR_BY_SIGNAL
    } catch (err) {
        return COLOR_BY_SIGNAL
    }
}

const saveColorBy = colorBy => {
    try {
        window.localStorage.setItem(COLOR_BY_KEY, colorBy)
    } catch (err) {
        console.warn('Unable to save color mode', err)
    }
}

// the API allows 60 requests a minute per IP, shared with hex lookups and
// hotspot search
const LATEST_REFRESH_MS = 60 * 1000
const LATEST_ZOOM = 15

// Query string for the filtered tile source and hex API. The end date is
// inclusive in the UI and exclusive in the API, so it moves forward a day.
// Returns '' when no filter applies or the range is invalid.
const toFilterQuery = filters => {
    if (filters.start && filters.end && filters.start > filters.end) return ''
    const params = new URLSearchParams()
    if (filters.start) params.set('start', filters.start)
    if (filters.end) params.set('end', new Date(Date.parse(filters.end + 'T00:00:00Z') + DAY_MS).toISOString().slice(0, 10))
    if (filters.hotspot) params.set('hotspot', filters.hotspot)
    return params.toString()
}

function Map(props) {
    const [viewport, setViewport] = useState({
        latitude: props.startLatitude,
        longitude: props.startLongitude,
        zoom: 11,
        bearing: 0,
        pitch: 0
    });
    const mapRef = useRef(null);
    const [uplinks, setUplinks] = useState(null);
    const [uplinkHotspotsData, setUplinkHotspotsData] = useState({ line: null, circle: null, hex: null });
    const [uplinkChannelData, setUplinkChannelData] = useState(null);
    const [hexId, setHexId] = useState(null);
    const [bestRssi, setBestRssi] = useState(null);
    const [snr, setSnr] = useState(null);
    const [showHexPane, setShowHexPane] = useState(false);
    const routerParams = props.routerParams;
    const [initComplete, setInitComplete] = useState(false);
    const [lastPath, setLastPath] = useState(false);
    const [showHexPaneCloseButton, setShowHexPaneCloseButton] = useState(false);
    const [filters, setFilters] = useState(EMPTY_FILTERS);
    const [selectedHotspot, setSelectedHotspot] = useState(null);
    const [colorBy, setColorBy] = useState(loadColorBy);
    // the legend bucket being hovered, focused, or tapped, which narrows the hex layers
    const [legendBucket, setLegendBucket] = useState(null);
    // ages are measured from page load, which is close enough for day-scale stops
    const [nowSeconds] = useState(() => Math.floor(Date.now() / 1000));
    // undefined until the first response for the current filters, null when none match
    const [latestUplink, setLatestUplink] = useState(undefined);
    const latestRequestRef = useRef(0);
    const filterQuery = toFilterQuery(filters);
    const activeBucket = legendBucket && legendBucket.colorBy === colorBy ? legendBucket : null;
    const uplinkTiles = filterQuery
        ? [TILESERVER_URL + "/rpc/public.h3_res9_filtered/{z}/{x}/{y}.pbf?" + filterQuery]
        : [TILESERVER_URL + "/public.h3_res9/{z}/{x}/{y}.pbf"];

    let navigate = useNavigate();
    const routeHexIdRef = React.useRef();
    routeHexIdRef.current = routerParams.hexId;
    const location = useLocation();

    React.useEffect(() => {
        if (!initComplete && location.pathname != lastPath) {
            setLastPath(location.pathname);
            let features = []
            channel.on("new_h3", payload => {
                // payload.body.id is the h3 index as an integer past
                // Number.MAX_SAFE_INTEGER, so features are keyed by id_string
                var new_feature = geojson2h3.h3ToFeature(payload.body.id_string, { 'id_string': payload.body.id_string, 'best_rssi': payload.body.best_rssi, 'snr': payload.body.snr, 'last_heard': payload.body.last_heard })
                features.push(new_feature)
                const featureCollection =
                {
                    "type": "FeatureCollection",
                    "features": [...features]
                }
                // Update data 
                setUplinkChannelData(featureCollection)
            })

            channel.join()
                .receive("ok", resp => { console.log("Joined successfully", resp) })
                .receive("error", resp => { console.log("Unable to join", resp) })

            if (routerParams.hexId != null) {
                setTimeout(() => {
                    simulateUplinkHexClick()
                }, 500)
            }

            setInitComplete(true);
        }
        else if (initComplete && location.pathname != lastPath) {

            setLastPath(location.pathname);
            if (routerParams.hexId != null && routerParams.hexId != 'undefined') {
                setTimeout(() => {
                    simulateUplinkHexClick()
                }, 500)
            }
        }

    }, [location,])

    const fetchLatestUplink = () => {
        const request = ++latestRequestRef.current;
        get("uplinks/latest" + (filterQuery ? "?" + filterQuery : ""))
            .then(res => {
                if (!res.ok) throw new Error("Latest uplink request failed: " + res.status)
                return res.json()
            })
            .then(body => {
                if (request === latestRequestRef.current) setLatestUplink(body.latest)
            })
            // keep the last good value; the next refresh tries again
            .catch(err => console.warn(err))
    }

    // reruns when the filters change, so the interval always fetches with the current ones
    React.useEffect(() => {
        setLatestUplink(undefined);
        fetchLatestUplink();
        const interval = setInterval(() => {
            if (!document.hidden) fetchLatestUplink();
        }, LATEST_REFRESH_MS);
        return () => clearInterval(interval);
    }, [filterQuery])

    const onCloseHexPaneClick = () => {
        setShowHexPane(false);

        clearSelectedHex();
        const hotspotLineFeatureCollection =
        {
            "type": "FeatureCollection",
            "features": []
        }
        const hotspotCircleFeatureCollection =
        {
            "type": "FeatureCollection",
            "features": []
        }
        const hotspotHexFeatureCollection =
        {
            "type": "FeatureCollection",
            "features": []
        }
        setUplinkHotspotsData({ line: hotspotLineFeatureCollection, circle: hotspotCircleFeatureCollection, hex: hotspotHexFeatureCollection })
        navigate("/");
        setShowHexPaneCloseButton(false);
    }

    const onFiltersChange = nextFilters => {
        // the open hex's stats came from the old tiles, so close it
        if (showHexPane) onCloseHexPaneClick();
        if (nextFilters.hotspot !== filters.hotspot) setSelectedHotspot(null);
        setFilters(nextFilters);
    }

    const onColorByChange = nextColorBy => {
        setColorBy(nextColorBy);
        saveColorBy(nextColorBy);
    }

    const onHotspotSelect = hotspot => {
        onFiltersChange({ ...filters, hotspot: hotspot.name });
        setSelectedHotspot(hotspot);
        setViewport({
            ...viewport,
            latitude: hotspot.lat,
            longitude: hotspot.lng,
            zoom: Math.min(viewport.zoom, 11.5),
            transitionInterpolator: new FlyToInterpolator(),
            transitionDuration: 1000
        });
    }

    const onPlaceSelect = place => {
        const [lng, lat] = place.center
        // a street address or point of interest needs a closer look than a city
        const pointZoom = place.place_type.some(t => t === 'address' || t === 'poi') ? 16 : 12
        let target = { longitude: lng, latitude: lat, zoom: pointZoom }
        if (place.bbox) {
            const [minLng, minLat, maxLng, maxLat] = place.bbox
            try {
                const vp = new WebMercatorViewport({ ...viewport, width: window.innerWidth, height: window.innerHeight })
                const fit = vp.fitBounds([[minLng, minLat], [maxLng, maxLat]], { padding: 40, maxZoom: 16 })
                target = { longitude: fit.longitude, latitude: fit.latitude, zoom: fit.zoom }
            } catch (err) {
                // fitBounds throws when the padding does not fit the window; the center is good enough
            }
        }
        setViewport({
            ...viewport,
            ...target,
            transitionInterpolator: new FlyToInterpolator(),
            transitionDuration: 1500
        });
    }

    const selectedHotspotData = {
        "type": "FeatureCollection",
        "features": selectedHotspot ? [{
            "type": "Feature",
            "geometry": { "type": "Point", "coordinates": [selectedHotspot.lng, selectedHotspot.lat] },
            "properties": { "name": selectedHotspot.name }
        }] : []
    }

    // a live hex can also be in the tiles, so mark it in both sources
    const setHexSelected = (map, id, selected) => {
        map.setFeatureState(
            { source: 'uplink-tileserver', sourceLayer: TILE_LAYER, id: id },
            { selected: selected }
        );
        map.setFeatureState(
            { source: 'uplink-channel', id: id },
            { selected: selected }
        );
    }

    const clearSelectedHex = () => {
        if (selectedHexId === null) return;
        setHexSelected(mapRef.current.getMap(), selectedHexId, false);
        selectedHexId = null;
    }

    const simulateUplinkHexClick = () => {
        // runs from a timer, so read the route as it is now, not as it was when
        // the timer was set; selecting a hex navigates to its route, which lands
        // here again
        const hexId = routeHexIdRef.current;
        if (!hexId || hexId === selectedHexId) return;
        const map = mapRef.current.getMap();

        if (map.areTilesLoaded()) {
            // a hex that crosses a tile edge comes back once per tile
            const feature = map.querySourceFeatures('uplink-tileserver', { sourceLayer: TILE_LAYER })
                .find(f => f.id === hexId)
            if (feature) selectHex(feature);
        }
        else {
            setTimeout(() => { simulateUplinkHexClick() }, 500)
        }
    }

    const onLatestUplinkClick = () => {
        if (!latestUplink) return;
        const id = latestUplink.h3_id;
        const [latitude, longitude] = h3ToGeo(id);
        setViewport({
            ...viewport,
            latitude,
            longitude,
            zoom: LATEST_ZOOM,
            transitionInterpolator: new FlyToInterpolator(),
            transitionDuration: 'auto'
        });
        // the hex may not be drawn until the flight lands, so its stats come
        // from the hex API; feature state applies once its tile loads
        selectHex({ id: id, properties: null });
    }

    const getHex = (h3_index, fillStats) => {
        get("uplinks/hex/" + h3_index + (filterQuery ? "?" + filterQuery : ""))
            .then(res => {
                if (res.status == 429) {
                    alert("Too many requests, take a break");
                    return Promise.reject("Try again in a minute")
                }
                else
                    return res
            })
            .then(res => res.json())
            .then(uplinks => {
                // a quick second click or a close can land before this response
                if (selectedHexId !== h3_index) return;
                var hotspot_line_features = [];
                var hotspot_circle_features = [];
                var hotspot_hex_features = [];
                setUplinks(uplinks.uplinks)
                // the hex API lists the strongest uplink first
                if (fillStats && uplinks.uplinks.length > 0) {
                    const best = uplinks.uplinks[0]
                    setBestRssi(best.rssi)
                    setSnr(best.snr.toFixed(2))
                }
                const uplink_coords = h3ToGeo(h3_index)
                uplinks.uplinks.map((h, i) => {
                    const hotspot_h3_index = geoToH3(h.lat, h.lng, 8)
                    const hotspot_coords = h3ToGeo(hotspot_h3_index)
                    const hotspot_polygon_coords = h3ToGeoBoundary(hotspot_h3_index, true)
                    hotspot_line_features.push(
                        {
                            "type": "Feature",
                            "geometry": {
                                "type": "LineString",
                                "coordinates": [
                                    [hotspot_coords[1], hotspot_coords[0]], [uplink_coords[1], uplink_coords[0]]
                                ]
                            }
                        }
                    )
                    hotspot_circle_features.push(
                        {
                            "type": "Feature",
                            "geometry": {
                                "type": "Point",
                                "coordinates": [hotspot_coords[1], hotspot_coords[0]]
                            },
                            "properties": {
                                "name": h.hotspot_name
                            }
                        }
                    )
                    hotspot_hex_features.push(
                        {
                            "type": "Feature",
                            "geometry": {
                                "type": "Polygon",
                                "coordinates": [
                                    hotspot_polygon_coords
                                ]
                            },
                            "properties": {
                                "name": h.hotspot_name
                            }
                        }
                    )
                })
                const hotspotLineFeatureCollection =
                {
                    "type": "FeatureCollection",
                    "features": hotspot_line_features
                }
                const hotspotCircleFeatureCollection =
                {
                    "type": "FeatureCollection",
                    "features": hotspot_circle_features
                }
                const hotspotHexFeatureCollection =
                {
                    "type": "FeatureCollection",
                    "features": hotspot_hex_features
                }

                setUplinkHotspotsData({ line: hotspotLineFeatureCollection, circle: hotspotCircleFeatureCollection, hex: hotspotHexFeatureCollection })
            })
            .catch(err => {
                alert(err)
            })
    }

    const selectHex = feature => {
        const map = mapRef.current.getMap();
        const id = feature.id;

        clearSelectedHex();
        selectedHexId = id;
        setHexSelected(map, id, true);

        navigate("/uplinks/hex/" + id);
        // set hex data for info pane
        setShowHexPaneCloseButton(false);
        // a hex selected without a rendered feature gets its stats from getHex
        const stats = feature.properties;
        setBestRssi(stats ? stats.best_rssi : null);
        setSnr(stats ? stats.snr.toFixed(2) : null);
        setHexId(id);
        getHex(id, !stats);
        setShowHexPane(true);
        setTimeout(() => { setShowHexPaneCloseButton(true); }, 1000)
    }

    const centerOnFeature = (feature, event) => {
        // calculate the bounding box of the feature
        const [minLng, minLat, maxLng, maxLat] = bbox(feature);
        // construct a viewport instance from the current state
        const vp = new WebMercatorViewport(viewport);
        var { longitude, latitude } = vp.fitBounds(
            [
                [minLng, minLat],
                [maxLng, maxLat]
            ],
            {
                padding: 40
            }
        );

        setViewport({
            ...viewport,
            longitude,
            latitude,
            transitionInterpolator: new LinearInterpolator({
                around: [event.offsetCenter.x, event.offsetCenter.y]
            }),
            transitionDuration: 700
        });
    }

    const onClick = event => {
        // topmost hex under the click; interactiveLayerIds filters the rest
        const feature = event.features && event.features[0];
        if (!feature) return;

        if (feature.id === selectedHexId) {
            onCloseHexPaneClick();
            return;
        }

        selectHex(feature);
        if (feature.layer.id === CHANNEL_LAYER) centerOnFeature(feature, event);
    };

    return (
        <div className='map-container'>
            <MapGL
                {...viewport}
                width="100vw"
                height="100vh"
                mapStyle={MAPBOX_STYLE}
                onClick={onClick}
                interactiveLayerIds={HEX_LAYERS}
                onViewportChange={setViewport}
                ref={mapRef}
                mapboxApiAccessToken={MAPBOX_TOKEN}
            >
                <GeolocateControl
                    positionOptions={{ enableHighAccuracy: true }}
                    fitBoundsOptions={{ maxZoom: viewport.zoom }}
                    trackUserLocation={true}
                    disabledLabel="Unable to locate"
                    className="geolocate-button"
                />
                <Source id="hotspot-tileserver" type="vector" url={"https://api-iot.heliumtools.org/v1/hg.gateways-rewarded-r8.hexes.json"}>
                    <Layer {...hotspotTileServerLayer} source-layer={"hg.gateways-rewarded-r8.hexes"} />
                </Source>
                {/* tiles rather than a TileJSON url: changing tiles swaps the source in place via setTiles */}
                <Source id="uplink-tileserver" type="vector" tiles={uplinkTiles} maxzoom={22} promoteId="id">
                    <Layer {...uplinkTileServerLayer(colorBy, nowSeconds, activeBucket)} source-layer={TILE_LAYER} />
                </Source>
                {/* live hexes ignore filters, so hide them while one is applied.
                    tolerance 0: geojson-vt otherwise drops polygons smaller than
                    its simplification tolerance, which hides res 9 hexes at zoom 6
                    and below while the tiles still draw them */}
                <Source id="uplink-channel" type="geojson" data={uplinkChannelData} promoteId="id_string" tolerance={0}>
                    <Layer {...uplinkChannelLayer(colorBy, nowSeconds, activeBucket)} layout={{ visibility: filterQuery ? 'none' : 'visible' }} />
                </Source>
                <Source id="selected-hotspot" type="geojson" data={selectedHotspotData}>
                    <Layer {...selectedHotspotLayer} />
                </Source>
                <Source id="uplink-hotspots-hex" type="geojson" data={uplinkHotspotsData.hex}>
                    <Layer {...uplinkHotspotsHexLayer} />
                </Source>
                <Source id="uplink-hotspots-line" type="geojson" data={uplinkHotspotsData.line}>
                    <Layer {...uplinkHotspotsLineLayer} />
                </Source>
                <Source id="uplink-hotspots-circle" type="geojson" data={uplinkHotspotsData.circle}>
                    <Layer {...uplinkHotspotsCircleLayer} />
                </Source>

            </MapGL>
            <InfoPane mapCenter={{ latitude: viewport.latitude, longitude: viewport.longitude }} onPlaceSelect={onPlaceSelect} colorBy={colorBy} onColorByChange={onColorByChange} onLegendBucketChange={setLegendBucket} filters={filters} onFiltersChange={onFiltersChange} onHotspotSelect={onHotspotSelect} hexId={hexId} bestRssi={bestRssi} snr={snr} uplinks={uplinks} showHexPane={showHexPane} onCloseHexPaneClick={onCloseHexPaneClick} showHexPaneCloseButton={showHexPaneCloseButton} latestUplink={latestUplink} onLatestUplinkClick={onLatestUplinkClick} />
        </div>
    );
}

export default Map;