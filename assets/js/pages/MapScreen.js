import React from "react"
import Map from "../components/Map"
import { useParams } from "react-router-dom";
import { h3ToGeo } from "h3-js";

function MapScreen() {
  let routerParams = useParams();

  if (routerParams.hexId != null) {
    const hotspot_coords = h3ToGeo(routerParams.hexId)
    var longitude = hotspot_coords[1]
    var latitude = hotspot_coords[0]
  }
  else {
    var latitude = 37.8;
    var longitude = -122.4;
  }

  return (
    <div>
      <Map startLatitude={latitude} startLongitude={longitude} routerParams={routerParams}/>
    </div>
  )

}

export default MapScreen;