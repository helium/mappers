import * as React from 'react';
import { useState, useRef } from 'react';
import MapGL, { Source, Layer, LinearInterpolator, WebMercatorViewport } from 'react-map-gl';
import InfoPane from "../components/InfoPane"
import { uplinkTileServerLayer, uplinkHotspotsLineLayer, uplinkHotspotsCircleLayer } from './Layers.js';
import bbox from '@turf/bbox';
import { get } from '../data/Rest'
import { geoToH3, h3ToGeo } from "h3-js";

const MAPBOX_TOKEN = process.env.PUBLIC_MAPBOX_KEY;
var selectedStateId = null;

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
    const [uplinkHotspotsData, setUplinkHotspotsData] = useState(null);
    const [hexId, setHexId] = useState(null);
    const [avgRssi, setAvgRssi] = useState(null);
    const [avgSnr, setAvgSnr] = useState(null);
    const [showHexPane, setShowHexPane] = useState(false);
    const onCloseHexPaneClick = () => setShowHexPane(false);

    const getHex = h3_index => {
        get("uplinks/hex/" + h3_index)
            .then(res => res.json())
            .then(uplinks => {
                var hotspot_features = [];
                setUplinks(uplinks.uplinks)
                const uplink_coords = h3ToGeo(h3_index)
                uplinks.uplinks.map((h, i) => {
                    const hotspot_h3_index = geoToH3(h.lat, h.lng, 8)
                    const hotspot_coords = h3ToGeo(hotspot_h3_index)
                    hotspot_features.push(
                        {
                            "type": "Feature",
                            "geometry": {
                                "type": "LineString",
                                "coordinates": [
                                    [hotspot_coords[1], hotspot_coords[0]], [uplink_coords[1], uplink_coords[0]]
                                ]
                            }
                        },
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
                })
                const hotspotFeatureCollection =
                {
                    "type": "FeatureCollection",
                    "features": hotspot_features
                }
                setUplinkHotspotsData(hotspotFeatureCollection)
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
                setAvgRssi(feature.properties.avg_rssi);
                setAvgSnr(feature.properties.avg_snr.toFixed(2));
                setHexId(feature.properties.id);
                getHex(feature.properties.id);
                setShowHexPane(true);

                if (selectedStateId !== null) {
                    map.setFeatureState(
                        { source: 'uplink-tileserver', sourceLayer: 'public.h3_res9', id: selectedStateId },
                        { selected: true }
                    );
                }
                selectedStateId = feature.id;
                map.setFeatureState(
                    { source: 'uplink-tileserver', sourceLayer: 'public.h3_res9', id: selectedStateId },
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
                <Source id="uplink-tileserver" type="vector" url={"https://mappers-tileserver-martin.herokuapp.com/public.h3_res9.json"}>
                    <Layer {...uplinkTileServerLayer} source-layer={"public.h3_res9"} />
                </Source>
                <Source id="uplink-hotspots" type="geojson" data={uplinkHotspotsData}>
                    <Layer {...uplinkHotspotsLineLayer} />
                    <Layer {...uplinkHotspotsCircleLayer} />
                </Source>
            </MapGL>
            <InfoPane hexId={hexId} avgRssi={avgRssi} avgSnr={avgSnr} uplinks={uplinks} showHexPane={showHexPane} onCloseHexPaneClick={onCloseHexPaneClick} />
        </div>
    );
}

export default Map;