// Cable-label mode.
//
// Generates two styles of cable marker by laying objects onto the existing
// Fabric canvas, which the normal print/preview pipeline then rasterizes:
//
//   * Flag    – text on both ends with a bare "wrap zone" in the middle. You
//               wrap the middle around the cable and stick the two ends back
//               to back, forming a flag that reads upright on both faces (the
//               far end is rotated 180°).
//   * Repeat  – the text is tiled along the whole label so it stays readable
//               however the label is wound around the cable.

// Resolve the active printer's dots-per-mm so mm inputs map to canvas pixels.
function getCableDpm() {
  const sel = document.getElementById("printerSelect");
  const sp = window.supportedPrinters;
  if (sel && sp && sp[sel.value]) return sp[sel.value].dpm;
  return 8; // 203 dpi fallback, matches all currently supported printers
}

// Remove every user object but keep the editor's padding guides.
function clearCableCanvas(canvas) {
  canvas.getObjects().slice().forEach((o) => {
    if (!o.paddingGuide) canvas.remove(o);
  });
}

// Build an IText scaled to fit the given box (fills it; scales up or down),
// preserving aspect ratio. maxW may be null to constrain by height only.
function makeFittedText(text, maxW, maxH, angle) {
  const fontInput = document.getElementById("fontFamilyInput");
  const t = new fabric.IText(text || " ", {
    fontFamily: (fontInput && fontInput.value) || "Arial",
    fontSize: 64,
    fill: "#000000",
    originX: "center",
    originY: "center",
    textAlign: "center",
    angle: angle || 0,
  });

  const sy = maxH / t.height;
  const sx = maxW ? maxW / t.width : Infinity;
  const scale = Math.max(0.05, Math.min(sx, sy));
  t.set({ scaleX: scale, scaleY: scale });
  return t;
}

function generateCableLabel() {
  const canvas = window.getFabricCanvas();
  if (!canvas) return;

  const dpm = getCableDpm();
  const text = (document.getElementById("cableTextInput").value || "").trim() || "Cable";
  const subMode = document.getElementById("cableSubMode").value;
  const printerHeight = canvas.getHeight(); // print-head height in px (e.g. 96)
  const margin = Math.max(2, Math.round(printerHeight * 0.1));
  const contentH = printerHeight - margin * 2;

  clearCableCanvas(canvas);

  if (subMode === "flag") {
    const diameterMm = parseFloat(document.getElementById("cableDiameter").value) || 5;
    const flagLenMm = parseFloat(document.getElementById("cableFlagLength").value) || 20;

    const wrapPx = Math.max(1, Math.round(Math.PI * diameterMm * dpm)); // cable circumference
    const flagPx = Math.max(1, Math.round(flagLenMm * dpm));
    const totalPx = flagPx * 2 + wrapPx;

    if (window.fabricEditor) window.fabricEditor.updateCanvasSize(totalPx, printerHeight);

    const cy = printerHeight / 2;
    const maxTextW = flagPx * 0.9;

    // Left flag: upright. Right flag: rotated 180° so it reads upright once folded.
    const left = makeFittedText(text, maxTextW, contentH, 0);
    left.set({ left: flagPx / 2, top: cy });

    const right = makeFittedText(text, maxTextW, contentH, 180);
    right.set({ left: flagPx + wrapPx + flagPx / 2, top: cy });

    canvas.add(left, right);
  } else {
    // Repeating: tile the text across the current label length.
    const spacingMm = parseFloat(document.getElementById("cableSpacing").value) || 6;
    const spacingPx = Math.max(0, Math.round(spacingMm * dpm));
    const widthPx = canvas.getWidth();
    const cy = printerHeight / 2;

    // Measure one tile, then place as many as fit (at least one).
    const sample = makeFittedText(text, null, contentH, 0);
    const tileW = sample.getScaledWidth();
    const step = tileW + spacingPx;
    const count = Math.max(1, Math.floor((widthPx + spacingPx) / step));
    // Center the whole run within the label.
    const runW = count * tileW + (count - 1) * spacingPx;
    let x = Math.max(0, (widthPx - runW) / 2) + tileW / 2;

    for (let i = 0; i < count; i++) {
      const t = makeFittedText(text, null, contentH, 0);
      t.set({ left: x, top: cy });
      canvas.add(t);
      x += step;
    }
  }

  canvas.discardActiveObject();
  canvas.renderAll();
}

document.addEventListener("DOMContentLoaded", () => {
  const subMode = document.getElementById("cableSubMode");
  const flagParams = document.getElementById("cableFlagParams");
  const repeatParams = document.getElementById("cableRepeatParams");

  const syncSubMode = () => {
    if (!subMode) return;
    const flag = subMode.value === "flag";
    if (flagParams) flagParams.style.display = flag ? "block" : "none";
    if (repeatParams) repeatParams.style.display = flag ? "none" : "block";
  };

  if (subMode) {
    subMode.addEventListener("change", () => {
      syncSubMode();
      generateCableLabel();
    });
    syncSubMode();
  }

  // Live regenerate on any cable input change.
  ["cableTextInput", "cableDiameter", "cableFlagLength", "cableSpacing"].forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("input", generateCableLabel);
  });

  const genBtn = document.getElementById("cableGenerateBtn");
  if (genBtn) genBtn.addEventListener("click", generateCableLabel);
});
