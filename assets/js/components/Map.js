import React, { useRef, useEffect, useState } from 'react';
import InfoPane from "../components/InfoPane"
import mapboxgl from 'mapbox-gl';
import '../../css/app.css'
import socket from "../socket"
import geojson2h3 from 'geojson2h3';

mapboxgl.accessToken = process.env.PUBLIC_MAPBOX_KEY;

function Map() {

  const mapContainerRef = useRef(null);
  const [lng, setLng] = useState(-122.21);
  const [lat, setLat] = useState(37.58);
  const [zoom, setZoom] = useState(10);
  const [map, setMap] = useState(null);

  const [hexId, setHexId] = useState(null);
  const [hexState, setHexState] = useState(null);
  const [avgRssi, setAvgRssi] = useState(null);
  const [avgSnr, setAvgSnr] = useState(null);

  const [showHexPane, setShowHexPane] = useState(false);
  const onCloseHexPaneClick = () => setShowHexPane(false)

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
      var avgRssi = e.features[0].properties.avg_rssi;
      var avgSnr = e.features[0].properties.avg_snr;
      var hexId = e.features[0].properties.id;
      var hexState = e.features[0].properties.id;

      setHexId(hexId);
      setAvgRssi(avgRssi);
      setAvgSnr(avgSnr.toFixed(2));
      setHexState(hexState);
      setShowHexPane(true);

      // Ensure that if the map is zoomed out such that multiple
      // copies of the feature are visible, the popup appears
      // over the copy being pointed to.
      while (Math.abs(e.lngLat.lng - coordinates[0]) > 180) {
        coordinates[0] += e.lngLat.lng > coordinates[0] ? 360 : -360;
      }
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
      var rssi = e.features[0].properties.avg_rssi;

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
        features.push(geojson2h3.h3ToFeature(payload.body.h3_id, { 'avg_rssi': payload.body.avg_rssi }))
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
        url: `https://mappers-tileserver-martin.herokuapp.com/${sourceId}.json`
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
            ['get', 'avg_rssi'],
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
      <div className='map-container' ref={mapContainerRef} />
      <InfoPane hexId={hexId} avgRssi={avgRssi} avgSnr={avgSnr} showHexPane={showHexPane} onCloseHexPaneClick={onCloseHexPaneClick} lng={lng} lat={lat} zoom={zoom} />
    </div>
  );
};

export default Map;