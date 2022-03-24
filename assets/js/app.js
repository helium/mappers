import React from "react"
import ReactDOM from "react-dom"
import { BrowserRouter, Routes, Route } from "react-router-dom";
import MapScreen from "./pages/MapScreen"

class App extends React.Component {
  render() {
    return (
      <MapScreen />
    )
  }
}

ReactDOM.render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<App />} >
        <Route path="uplinks" element={<App />}>
          <Route path="hex" element={<App />}>
            <Route path=":hexId" element={<App />} />
          </Route>
        </Route>
      </Route>
    </Routes>
  </BrowserRouter>,
  document.getElementById("react-app")
)
