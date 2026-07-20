import { fetchNui } from "./fetchNui.js";

const optionsList = document.getElementById("options-list");
const targetTextUi = document.getElementById("target-textui");

const ICONS = {
  money: '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M7 9H6v1M17 15h1v-1"/>',
  door: '<path d="M4 21h16M6 21V4a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v17M13 12h.01"/>',
  car: '<path d="M5 17H3v-5l2-5h14l2 5v5h-2M7 17h10M7 17v2M17 17v2M6 13h.01M18 13h.01"/>',
  user: '<path d="M20 21a8 8 0 0 0-16 0M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10Z"/>',
  box: '<path d="m21 8-9 5-9-5 9-5 9 5ZM3 8v8l9 5 9-5V8M12 13v8"/>',
  wrench: '<path d="M21 6a5 5 0 0 1-6.7 4.7l-7 7a2 2 0 1 1-2.8-2.9l7-7A5 5 0 0 1 18 3l-3 3 3 3 3-3Z"/>',
  hand: '<path d="M7 11V6a2 2 0 0 1 4 0v4-6a2 2 0 0 1 4 0v6-4a2 2 0 0 1 4 0v8c0 5-3 8-8 8-3 0-5-2-7-5l-2-3a2 2 0 0 1 3-2l2 2"/>',
  default: '<circle cx="12" cy="12" r="8"/><path d="m9 12 2 2 4-4"/>'
};

function iconMarkup(name = "", label = "") {
  const value = `${name} ${label}`.toLowerCase();
  if (/atm|bank|cash|money|dollar|dinheiro|banco|sacar|depositar/.test(value)) {
    return `<svg class="option-icon" viewBox="0 0 24 24" aria-hidden="true">${ICONS.money}</svg>`;
  }
  const key = Object.keys(ICONS).find((item) => item !== "default" && value.includes(item));
  return `<svg class="option-icon" viewBox="0 0 24 24" aria-hidden="true">${ICONS[key || "default"]}</svg>`;
}

function onClick() {
  this.style.pointerEvents = "none";
  fetchNui("select", [this.targetType, this.targetId, this.zoneId]);
  setTimeout(() => (this.style.pointerEvents = "auto"), 100);
}

export function createOptions(type, data, id, zoneId) {
  if (data.hide) return;

  const option = document.createElement("div");
  option.innerHTML = iconMarkup(data.icon, data.label);

  const label = document.createElement("p");
  label.className = "option-label";
  label.textContent = data.label;
  option.appendChild(label);

  option.className = "option-container";
  option.targetType = type;
  option.targetId = id;
  option.zoneId = zoneId;
  option.dataset.label = data.label;
  option.title = data.label;
  if (data.iconColor) option.style.setProperty("--icon-color", data.iconColor);

  option.addEventListener("mouseenter", () => { targetTextUi.textContent = data.label; });
  option.addEventListener("focus", () => { targetTextUi.textContent = data.label; });
  option.addEventListener("click", onClick);
  optionsList.appendChild(option);
}
