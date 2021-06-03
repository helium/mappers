import * as React from 'react';
import { useState } from 'react';
import { render } from 'react-dom';
import MapGL, { Source, Layer } from 'react-map-gl';
import InfoPane from "../components/InfoPane"
import { uplinkTileServerLayer } from './MapStyles.js';

const MAPBOX_TOKEN = process.env.PUBLIC_MAPBOX_KEY;

function Map() {
    const [viewport, setViewport] = useState({
        latitude: 37.8,
        longitude: -122.4,
        zoom: 14,
        bearing: 0,
        pitch: 0
    });

    return (
        <div className='map-container'>
            <MapGL
                {...viewport}
                width="100vw"
                height="100vh"
                mapStyle="mapbox://styles/petermain/ckmwdn50a1ebk17o3h5e6wwui"
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