import React from "react"
import ReactDOM from "react-dom"
import MapScreen from "./pages/MapScreen"

class App extends React.Component {
  render() {
    return (
        <MapScreen />
    )
  }
}

ReactDOM.render(
  <App/>,
  document.getElementById("react-app")
)
