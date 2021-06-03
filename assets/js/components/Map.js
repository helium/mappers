import * as React from 'react';
import { useState } from 'react';
import { render } from 'react-dom';
import MapGL, { Source, Layer, LinearInterpolator, WebMercatorViewport } from 'react-map-gl';
import InfoPane from "../components/InfoPane"
import { uplinkTileServerLayer } from './MapStyles.js';
import bbox from '@turf/bbox';

const MAPBOX_TOKEN = process.env.PUBLIC_MAPBOX_KEY;

function Map() {
    const [viewport, setViewport] = useState({
        latitude: 37.8,
        longitude: -122.4,
        zoom: 11,
        bearing: 0,
        pitch: 0
    });

    const onClick = event => {
        const feature = event.features[0];
        if (feature) {
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
                mapboxApiAccessToken={MAPBOX_TOKEN}
            >
                <Source id="uplink-tileserver" type="vector" url={"https://mappers-tileserver-martin.herokuapp.com/public.h3_res9.json"}>
                    <Layer {...uplinkTileServerLayer} source-layer={"public.h3_res9"} />
                </Source>
            </MapGL>
            <InfoPane />
        </div>
    );
}

export default Map;