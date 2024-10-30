import * as React from 'react';
import { useState, useRef } from 'react';
import MapGL, { Source, Layer, FlyToInterpolator, LinearInterpolator, WebMercatorViewport, GeolocateControl, LngLat } from 'react-map-gl';
import InfoPane from "../components/InfoPane"
import WelcomeModal from "../components/WelcomeModal"
import { uplinkTileServerLayer, hotspotTileServerLayer, uplinkHotspotsLineLayer, uplinkHotspotsCircleLayer, uplinkHotspotsHexLayer, uplinkChannelLayer } from './Layers.js';
import bbox from '@turf/bbox';
import { get } from '../data/Rest'
import { geoToH3, h3ToGeo, h3ToGeoBoundary } from "h3-js";
import socket from "../socket";
import geojson2h3 from 'geojson2h3';
import useLocalStorageState from 'use-local-storage-state';
import '../../css/app.css';
import { useNavigate, useLocation } from "react-router-dom";

const MAPBOX_TOKEN = process.env.PUBLIC_MAPBOX_KEY;
var selectedStateIdTile = null;
var selectedStateIdChannel = null;
const channel = socket.channel("h3:new")

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
    const [showWelcomeModal, setShowWelcomeModal] = useLocalStorageState('welcomeModalOpen_v1', true);
    const onCloseWelcomeModalClick = () => setShowWelcomeModal(false);
    const routerParams = props.routerParams;
    const [initComplete, setInitComplete] = useState(false);
    const [lastPath, setLastPath] = useState(false);
    const [showHexPaneCloseButton, setShowHexPaneCloseButton] = useState(false);

    let navigate = useNavigate();
    const location = useLocation();

    React.useEffect(() => {
        if (!initComplete && location.pathname != lastPath) {
            setLastPath(location.pathname);
            let features = []
            channel.on("new_h3", payload => {
                var new_feature = geojson2h3.h3ToFeature(payload.body.id_string, { 'id': payload.body.id, 'id_string': payload.body.id_string, 'best_rssi': payload.body.best_rssi, 'snr': payload.body.snr })
                new_feature.id = payload.body.id
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

    const clearSelectedHex = () => {
        const map = mapRef.current.getMap();
        // unselect any currently selected hex on both hex layers
        if (selectedStateIdTile !== null || selectedStateIdTile !== null) {
            map.setFeatureState(
                { source: 'uplink-tileserver', sourceLayer: 'public.h3_res9', id: selectedStateIdTile },
                { selected: true }
            );
            map.setFeatureState(
                { source: 'uplink-channel', id: selectedStateIdChannel },
                { selected: true }
            );
        }
    }

    const simulateUplinkHexClick = event => {
        const map = mapRef.current.getMap();

        if (map.areTilesLoaded()) {
            var features = map.querySourceFeatures('uplink-tileserver', { sourceLayer: 'public.h3_res9' })
            features.forEach(function (feature_i) {
                if (feature_i.properties.id == routerParams.hexId) {
                    feature_i.layer = { id: "public.h3_res9", layout: {}, source: "uplink-tileserver", sourceLayer: "public.h3_res9", type: "fill" }
                    var event = { features: [feature_i] }
                    onClick(event)
                }
            });
        }
        else {
            setTimeout(() => { simulateUplinkHexClick() }, 500)
        }
    }

    const getHex = h3_index => {
        get("uplinks/hex/" + h3_index)
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
                var hotspot_line_features = [];
                var hotspot_circle_features = [];
                var hotspot_hex_features = [];
                setUplinks(uplinks.uplinks)
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

    const onClick = event => {
        const features = event.features;
        const map = mapRef.current.getMap();
        setShowHexPaneCloseButton(false);
        if (features) {
            features.forEach(feature => {
                if (feature.layer.id == "public.h3_res9") {
                    navigate("/uplinks/hex/" + feature.properties.id);
                    // set hex data for info pane
                    setBestRssi(feature.properties.best_rssi);
                    setSnr(feature.properties.snr.toFixed(2));
                    setHexId(feature.properties.id);
                    getHex(feature.properties.id);
                    setShowHexPane(true);

                    // unselect any currently selected hex on both hex layers
                    if (selectedStateIdTile !== null || selectedStateIdTile !== null) {
                        map.setFeatureState(
                            { source: 'uplink-tileserver', sourceLayer: 'public.h3_res9', id: selectedStateIdTile },
                            { selected: true }
                        );
                        map.setFeatureState(
                            { source: 'uplink-channel', id: selectedStateIdChannel },
                            { selected: true }
                        );
                    }
                    selectedStateIdTile = feature.id;
                    map.setFeatureState(
                        { source: 'uplink-tileserver', sourceLayer: 'public.h3_res9', id: selectedStateIdTile },
                        { selected: false }
                    );
                    setTimeout(() => { setShowHexPaneCloseButton(true); }, 1000)
                }
                else if (feature.layer.id == "uplinkChannelLayer") {
                    navigate("/uplinks/hex/" + feature.properties.id_string);
                    // set hex data for info pane
                    setBestRssi(feature.properties.best_rssi);
                    setSnr(feature.properties.snr.toFixed(2));
                    setHexId(feature.properties.id_string);
                    getHex(feature.properties.id_string);
                    setShowHexPane(true);

                    // unselect any currently selected hex on both hex layers
                    if (selectedStateIdChannel !== null || selectedStateIdTile !== null) {
                        map.setFeatureState(
                            { source: 'uplink-channel', id: selectedStateIdChannel },
                            { selected: true }
                        );
                        map.setFeatureState(
                            { source: 'uplink-tileserver', sourceLayer: 'public.h3_res9', id: selectedStateIdTile },
                            { selected: true }
                        );
                    }
                    selectedStateIdChannel = feature.id;
                    map.setFeatureState(
                        { source: 'uplink-channel', id: selectedStateIdChannel },
                        { selected: false }
                    );

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
                    setTimeout(() => { setShowHexPaneCloseButton(true); }, 1000)
                }
            });
        }
    };

    return (
        <div className='map-container'>
            <MapGL
                {...viewport}
                width="100vw"
                height="100vh"
                mapStyle="mapbox://styles/petermain/ckmwdn50a1ebk17o3h5e6wwui"
                onClick={onClick}
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
                <Source id="hotspot-tileserver" type="vector" url={"https://emt.heliumgeek.net/v1/hg.gateways-rewarded-r8.hexes.json"}>
                    <Layer {...hotspotTileServerLayer} source-layer={"hg.gateways-rewarded-r8.hexes"} />
                </Source>
                <Source id="uplink-tileserver" type="vector" url={"https://mappers-tileserver.helium.wtf/public.h3_res9.json"}>
                    <Layer {...uplinkTileServerLayer} source-layer={"public.h3_res9"} />
                </Source>
                <Source id="uplink-channel" type="geojson" data={uplinkChannelData}>
                    <Layer {...uplinkChannelLayer} />
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
            <InfoPane hexId={hexId} bestRssi={bestRssi} snr={snr} uplinks={uplinks} showHexPane={showHexPane} onCloseHexPaneClick={onCloseHexPaneClick} showHexPaneCloseButton={showHexPaneCloseButton} />
            <WelcomeModal showWelcomeModal={showWelcomeModal} onCloseWelcomeModalClick={onCloseWelcomeModalClick} />
        </div>
    );
}

export default Map;