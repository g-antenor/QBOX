import { createOptions } from "./createOptions.js?v=6";

const optionsWrapper = document.getElementById("options-wrapper");
const optionsList = document.getElementById("options-list");
const targetTextUi = document.getElementById("target-textui");
const body = document.body;
const eye = document.getElementById("eyeSvg");

window.addEventListener("message", (event) => {
  switch (event.data.event) {
    case "visible": {
      optionsList.replaceChildren();
      targetTextUi.textContent = "";
      optionsWrapper.classList.remove("has-options");
      body.style.visibility = event.data.state ? "visible" : "hidden";
      return eye.classList.remove("eye-hover");
    }

    case "leftTarget": {
      optionsList.replaceChildren();
      targetTextUi.textContent = "";
      optionsWrapper.classList.remove("has-options");
      return eye.classList.remove("eye-hover");
    }

    case "setTarget": {
      optionsList.replaceChildren();
      targetTextUi.textContent = "";
      eye.classList.add("eye-hover");

      if (event.data.options) {
        for (const type in event.data.options) {
          event.data.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
      }

      if (event.data.zones) {
        for (let i = 0; i < event.data.zones.length; i++) {
          event.data.zones[i].forEach((data, id) => {
            createOptions("zones", data, id + 1, i + 1);
          });
        }
      }

      optionsWrapper.classList.toggle("has-options", optionsList.childElementCount > 0);
      targetTextUi.textContent = optionsList.firstElementChild?.dataset.label || "";
    }
  }
});
