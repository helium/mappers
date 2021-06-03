import * as React from 'react';
import { useState } from 'react';
import { render } from 'react-dom';
import MapGL from 'react-map-gl';

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
            />
        </div>
    );
}

export default Map;