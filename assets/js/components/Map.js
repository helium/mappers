import React, { useRef, useEffect, useState } from 'react';
import InfoPane from "../components/InfoPane"
import mapboxgl from 'mapbox-gl';
import '../../css/app.css'
import socket from "../socket"
import geojson2h3 from 'geojson2h3';
import { get } from '../data/Rest'
import GeoJSON from "geojson";
import { geoToH3, h3ToGeo } from "h3-js";

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

  const [uplinks, setUplinks] = useState(null);

  const [showHexPane, setShowHexPane] = useState(false);
  const onCloseHexPaneClick = () => setShowHexPane(false)

  const sourceId = 'public.h3_res9';

  var selectedStateId = null;

  // Initialize map when component mounts
  useEffect(() => {
    const map = new mapboxgl.Map({
      container: mapContainerRef.current,
      style: 'mapbox://styles/petermain/ckmwdn50a1ebk17o3h5e6wwui',
      center: [lng, lat],
      zoom: zoom
    });

    function getHex(h3_index) {
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
          map.getSource('uplink-hotspots').setData(hotspotFeatureCollection)
        })
        .catch(err => {
          alert(err)
        })
    }

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
      var hexState = e.features[0].properties.state;

      if (e.features.length > 0) {
        if (selectedStateId !== null) {
          map.setFeatureState(
            { source: 'h3-vector-db', sourceLayer: 'public.h3_res9', id: selectedStateId },
            { selected: true }
          );
        }
        selectedStateId = e.features[0].id;
        map.setFeatureState(
          { source: 'h3-vector-db', sourceLayer: 'public.h3_res9', id: selectedStateId },
          { selected: false }
        );
      }

      getHex(hexId);

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

      map.addSource('uplink-hotspots', {
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
            'case',
            ['boolean',
              ['feature-state', 'selected'], true],
            ['interpolate',
              ['linear'],
              ['get', 'avg_rssi'],
              -120,
              'rgba(38,251,202,0.1)',
              -100,
              'rgba(38,251,202,0.45)',
              -80,
              'rgba(38,251,202,0.8)']
            ,
            '#b67ffe'
          ],
          'fill-opacity': 0.9,
          'fill-outline-color': [
            'case',
            ['boolean',
              ['feature-state', 'selected'], true],
            'rgba(38,251,202,0.45)',
            '#FFFFFF'
          ]
        }
      });

      map.addLayer({
        'id': 'uplink-hotspots-line',
        'type': 'line',
        'source': 'uplink-hotspots',
        'layout': {
          'line-join': 'round',
          'line-cap': 'round'
        },
        'paint': {
          'line-color': '#d8d51d',
          'line-width': 2
        }
      });

      map.addLayer({
        'id': 'uplink-hotspots-circle',
        'type': 'circle',
        'source': 'uplink-hotspots',
        'layout': {},
        'paint': {
          'circle-color': '#d8d51d',
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
      <InfoPane hexId={hexId} avgRssi={avgRssi} avgSnr={avgSnr} showHexPane={showHexPane} onCloseHexPaneClick={onCloseHexPaneClick} uplinks={uplinks} lng={lng} lat={lat} zoom={zoom} />
    </div>
  );
};

export default Map;