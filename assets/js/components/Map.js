import * as React from 'react';
import { useState, useRef } from 'react';
import MapGL, { Source, Layer, LinearInterpolator, WebMercatorViewport, GeolocateControl } from 'react-map-gl';
import InfoPane from "../components/InfoPane"
import WelcomeModal from "../components/WelcomeModal"
import { uplinkTileServerLayer, hotspotTileServerLayer, uplinkHotspotsLineLayer, uplinkHotspotsCircleLayer, uplinkHotspotsHexLayer, uplinkChannelLayer} from './Layers.js';
import bbox from '@turf/bbox';
import { get } from '../data/Rest'
import { geoToH3, h3ToGeo, h3ToGeoBoundary } from "h3-js";
import socket from "../socket";
import geojson2h3 from 'geojson2h3';
import useLocalStorageState from 'use-local-storage-state';
import '../../css/app.css';

const MAPBOX_TOKEN = process.env.PUBLIC_MAPBOX_KEY;
var selectedStateIdTile = null;
var selectedStateIdChannel = null;
const channel = socket.channel("h3:new")

function Map() {
    const [viewport, setViewport] = useState({
        latitude: 37.8,
        longitude: -122.4,
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
    const onCloseHexPaneClick = () => setShowHexPane(false);
    const [showWelcomeModal, setShowWelcomeModal] = useLocalStorageState('welcomeModalOpen_v1', true);
    const onCloseWelcomeModalClick = () => setShowWelcomeModal(false);


    React.useEffect(() => {
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

    }, []) // <-- empty dependency array

    const getHex = h3_index => {
        get("uplinks/hex/" + h3_index)
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
        const feature = event.features[0];
        const map = mapRef.current.getMap();

        if (feature) {
            if (feature.layer.id == "public.h3_res9") {
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

                // setViewport({
                //     ...viewport,
                //     longitude,
                //     latitude,
                //     transitionInterpolator: new LinearInterpolator({
                //         around: [event.offsetCenter.x, event.offsetCenter.y]
                //     }),
                //     transitionDuration: 700
                // });
            }
            else if (feature.layer.id == "uplinkChannelLayer") {
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
            }
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
                    positionOptions={{enableHighAccuracy: true}}
                    fitBoundsOptions={{maxZoom: viewport.zoom}}
                    trackUserLocation={true}
                    disabledLabel="Unable to locate"
                    className="geolocate-button"
                />
                <Source id="hotspot-tileserver" type="vector" url={"https://hotspot-tileserver.helium.wtf/public.h3_res8.json"}>
                    <Layer {...hotspotTileServerLayer} source-layer={"public.h3_res8"} />
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
            <InfoPane hexId={hexId} bestRssi={bestRssi} snr={snr} uplinks={uplinks} showHexPane={showHexPane} onCloseHexPaneClick={onCloseHexPaneClick} />
            <WelcomeModal showWelcomeModal={showWelcomeModal} onCloseWelcomeModalClick={onCloseWelcomeModalClick}/>
        </div>
    );
}

export default Map;