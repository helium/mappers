import React, { useRef, useEffect, useState } from 'react';
import mapboxgl from 'mapbox-gl';
import '../../css/app.css'

mapboxgl.accessToken = process.env.PUBLIC_MAPBOX_KEY;

const Map = () => {
  const mapContainerRef = useRef(null);

  const [lng, setLng] = useState(-122.21);
  const [lat, setLat] = useState(37.58);
  const [zoom, setZoom] = useState(10);

  const [map, setMap] = useState(null);
  const sourceId = 'public.h3_res9';

  // Initialize map when component mounts
  useEffect(() => {
    const map = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/petermain/ckmwdn50a1ebk17o3h5e6wwui',
      center: [lng, lat],
      zoom: zoom
    });

    // Add navigation control (the +/- zoom buttons)
    map.addControl(new mapboxgl.NavigationControl(), 'top-right');

    map.on('move', () => {
      setLng(map.getCenter().lng.toFixed(4));
      setLat(map.getCenter().lat.toFixed(4));
      setZoom(map.getZoom().toFixed(2));
    });

    map.on('load', () => {
      map.addSource('h3-vector-db', {
        type: 'vector',
        url: `https://mappers-tileserver.herokuapp.com/${sourceId}.json`
      });

      map.addLayer({
        id: sourceId,
        type: 'fill',
        source: 'h3-vector-db',
        'source-layer': sourceId,
        'paint': {
          'fill-color': [
            'interpolate',
            ['linear'],
            ['get', 'average_rssi'],
            -120,
            'rgba(38,251,202,0.1)',
            -100,
            'rgba(38,251,202,0.45)',
            -80,
            'rgba(38,251,202,0.8)'
          ],
          'fill-opacity': 0.9
        }
      });

      setMap(map);
    });

    // Clean up on unmount
    return () => map.remove();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div>
      <div className='sidebarStyle'>
        <div>
          Longitude: {lng} | Latitude: {lat} | Zoom: {zoom}
        </div>
      </div>
      <div className='map-container' ref={mapContainerRef} />
    </div>
  );
};

export default Map;