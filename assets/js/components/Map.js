import React, { useRef, useEffect, useState } from 'react';
import mapboxgl from 'mapbox-gl';
import '../../css/app.css'
import socket from "../socket"
import geojson2h3 from 'geojson2h3';

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

    // Change the cursor to a pointer when the mouse is over a hexagon.
    map.on('mouseenter', 'public.h3_res9', function () {
      map.getCanvas().style.cursor = 'pointer';
    });

    // Change it back to a pointer when it leaves.
    map.on('mouseleave', 'public.h3_res9', function () {
      map.getCanvas().style.cursor = '';
    });

    map.on('click', 'public.h3_res9', function (e) {
      var coordinates = e.features[0].geometry.coordinates[0][0];
      var rssi = e.features[0].properties.average_rssi;

      // Ensure that if the map is zoomed out such that multiple
      // copies of the feature are visible, the popup appears
      // over the copy being pointed to.
      while (Math.abs(e.lngLat.lng - coordinates[0]) > 180) {
        coordinates[0] += e.lngLat.lng > coordinates[0] ? 360 : -360;
      }

      new mapboxgl.Popup()
        .setLngLat(coordinates)
        .setHTML('rssi: ' + rssi)
        .addTo(map);
    });

    // Change the cursor to a pointer when the mouse is over a hexagon.
    map.on('mouseenter', 'new-h3', function () {
      map.getCanvas().style.cursor = 'pointer';
    });

    // Change it back to a pointer when it leaves.
    map.on('mouseleave', 'new-h3', function () {
      map.getCanvas().style.cursor = '';
    });

    map.on('click', 'new-h3', function (e) {
      var coordinates = e.features[0].geometry.coordinates[0][0];
      var rssi = e.features[0].properties.average_rssi;

      // Ensure that if the map is zoomed out such that multiple
      // copies of the feature are visible, the popup appears
      // over the copy being pointed to.
      while (Math.abs(e.lngLat.lng - coordinates[0]) > 180) {
        coordinates[0] += e.lngLat.lng > coordinates[0] ? 360 : -360;
      }

      new mapboxgl.Popup()
        .setLngLat(coordinates)
        .setHTML('rssi: ' + rssi)
        .addTo(map);
    });

    map.on('load', () => {
      let features = []

      let channel = socket.channel("h3:new")
      channel.on("new_h3", payload => {
        features.push(geojson2h3.h3ToFeature(payload.body.h3_id, {'average_rssi': payload.body.average_rssi}))
        const featureCollection =
        {
          "type": "FeatureCollection",
          "features": features
        }
        // Update map data source
        map.getSource('new-h3').setData(featureCollection)
      })

      channel.join()
        .receive("ok", resp => { console.log("Joined successfully", resp) })
        .receive("error", resp => { console.log("Unable to join", resp) })

      map.addSource('new-h3', {
        type: 'geojson', data:
        {
          "type": "FeatureCollection",
          "features": []
        }
      });

      map.addLayer({
        id: 'new-h3',
        type: 'fill',
        source: 'new-h3',
        'layout': {},
        'paint': {
          'fill-color': '#faf409',
          'fill-opacity': 0.9
        }
      });

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