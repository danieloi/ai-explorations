import * as React from "react";
import * as ReactDOM from "react-dom";
import Home from "./home";

document.addEventListener("DOMContentLoaded", () => {
  const rootEl = document.getElementById("root");
  ReactDOM.render(<Home />, rootEl);
});
