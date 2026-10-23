import { Excalidraw, serializeAsJSON } from "@excalidraw/excalidraw";
import "@excalidraw/excalidraw/index.css";
import { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";

const KEY = "scene";

const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
const hex = (c) =>
  "#" +
  c
    .map((v) =>
      Math.round(Math.min(1, Math.max(0, v)) * 255)
        .toString(16)
        .padStart(2, "0"),
    )
    .join("");
const mix = (a, b, t) => hex(rgb(a).map((v, i) => v * (1 - t) + rgb(b)[i] * t));
const luma = (c) => {
  const [r, g, b] = rgb(c);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};

const unfilter = (c) => {
  const [r, g, b] = rgb(c);
  const y = 0.213 * r + 0.715 * g + 0.072 * b;
  return hex([2 * y - r, 2 * y - g, 2 * y - b].map((v) => (v - 0.93) / -0.86));
};

const vars = (t) => ({
  "--default-bg-color": t.bg,
  "--island-bg-color": t.bgAlt,
  "--popup-bg-color": t.bgAlt,
  "--popup-secondary-bg-color": t.bgDim,
  "--popup-text-color": t.fg,
  "--popup-text-inverted-color": t.bg,
  "--sidebar-bg-color": t.bgAlt,
  "--sidebar-border-color": t.border,
  "--text-primary-color": t.fg,
  "--icon-fill-color": t.fg,
  "--keybinding-color": t.fgMuted,
  "--input-bg-color": t.bg,
  "--input-border-color": t.border,
  "--input-hover-bg-color": t.bgDim,
  "--input-label-color": t.fg,
  "--button-gray-1": t.border,
  "--button-gray-2": t.bgAlt,
  "--button-gray-3": t.bgDim,
  "--button-hover-bg": t.border,
  "--button-bg": t.bgAlt,
  "--default-border-color": t.border,
  "--dialog-border-color": t.border,
  "--color-border-outline": t.fgMuted,
  "--color-border-outline-variant": t.border,
  "--color-surface-high": t.border,
  "--color-surface-mid": t.bgDim,
  "--color-surface-low": t.bgAlt,
  "--color-surface-lowest": t.bgDim,
  "--color-on-surface": t.fg,
  "--color-primary": t.accent,
  "--color-primary-darker": t.accent,
  "--color-primary-darkest": t.accent,
  "--color-primary-hover": mix(t.accent, t.fg, 0.2),
  "--color-primary-light": mix(t.bg, t.accent, 0.3),
  "--color-primary-light-darker": mix(t.bg, t.accent, 0.4),
  "--color-brand-hover": mix(t.accent, t.fg, 0.2),
  "--color-brand-active": mix(t.accent, t.fg, 0.35),
  "--color-on-primary-container": t.fg,
  "--color-surface-primary-container": mix(t.bg, t.accent, 0.3),
  "--color-selection": t.accent,
  "--select-highlight-color": t.accent,
  "--focus-highlight-color": t.accent,
  "--link-color": t.info,
  "--color-logo-text": t.fg,
  "--color-danger": t.error,
  "--color-danger-text": t.error,
  "--color-warning": t.warning,
  "--scrollbar-thumb": t.border,
  "--scrollbar-thumb-hover": t.fgMuted,
  "--overlay-bg-color": t.bg + "99",
});

const style = document.createElement("style");
document.head.append(style);

let pushTheme = null;
let pending = null;
window.applyTheme = (t) => {
  pending = t;
  pushTheme?.(t);
};

const canvas = (t) => (luma(t.bg) < 0.5 ? unfilter(t.bg) : t.bg);

const load = () => {
  try {
    return JSON.parse(localStorage.getItem(KEY));
  } catch {
    return null;
  }
};

function App() {
  const [palette, setPalette] = useState(pending);
  const api = useRef(null);
  const timer = useRef(0);
  const dark = palette ? luma(palette.bg) < 0.5 : true;

  useEffect(() => {
    pushTheme = setPalette;
  }, []);

  useEffect(() => {
    if (!palette) return;
    const body = Object.entries(vars(palette))
      .map(([k, v]) => `${k}: ${v};`)
      .join(" ");
    style.textContent = `:root .excalidraw.theme--dark, :root .excalidraw.theme--light { ${body} } body { background: ${palette.bg}; }`;
    api.current?.updateScene({ appState: { viewBackgroundColor: canvas(palette) } });
  }, [palette]);

  const save = (elements, appState, files) => {
    if (palette && appState.viewBackgroundColor !== canvas(palette)) {
      api.current?.updateScene({ appState: { viewBackgroundColor: canvas(palette) } });
      return;
    }
    clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      try {
        localStorage.setItem(KEY, serializeAsJSON(elements, appState, files, "local"));
      } catch {}
    }, 250);
  };

  return (
    <Excalidraw
      excalidrawAPI={(a) => (api.current = a)}
      initialData={load}
      onChange={save}
      theme={dark ? "dark" : "light"}
      UIOptions={{ canvasActions: { changeViewBackgroundColor: false } }}
    />
  );
}

createRoot(document.getElementById("root")).render(<App />);
