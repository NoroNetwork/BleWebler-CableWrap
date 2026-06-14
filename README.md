# BleWebler (Cable-Wrap Edition)

**BleWebler** is a browser-based solution for thermal label printing. It leverages the **Web Bluetooth API** to connect directly to supported Bluetooth Low Energy (BLE) printers, eliminating the need for drivers, proprietary apps, or vendor lock-in.

> This is a personal fork of the original [BleWebler by josb25](https://github.com/josb25/BleWebler),
> adding a dedicated **Cable Wrap** label mode. All BLE printing, the editor, QR codes, and dithering
> come from the upstream project (GPLv3) — see [Credits](#credits--third-party-libraries).
>
> 📱 **Native iOS app:** a SwiftUI + CoreBluetooth version lives in [`ios/`](ios/README.md)
> (iOS Safari can't do Web Bluetooth, so the app uses CoreBluetooth directly).

---

## Key Features

### Privacy-First & Open Source
BleWebler runs entirely within your browser. **No data is ever sent to a server.** Your designs and labels stay on your device, ensuring complete privacy and security.

### Zero Installation
- **No Drivers**: Connects directly to hardware via Web Bluetooth.
- **No Apps**: Works on any modern operating system (Windows, macOS, Linux, Android, ChromeOS) with a compatible browser.
- **Instant Start**: Just open the URL and start printing.

### Image Processing
Thermal printers require specific image preparation. BleWebler includes industry standard dithering algorithms to ensure your images look crisp and clear on 1-bit printers:
- **Floyd-Steinberg**
- **Atkinson**
- **Bayer**
- **Binary Threshold**

### Flexible Media Support
- **Infinite Paper**: Support for continuous label rolls with variable lengths.
- **Fixed Sizes**: Presets for standard label sizes.
- **Auto-Scaling**: Canvas automatically adjusts to the printer's resolution (DPI).

### Cable Wrap Mode *(added in this fork)*
A dedicated mode for marking cables. Pick the **Cable** tab and choose a style:
- **Flag**: text printed on both ends with a bare wrap zone in the middle. Wrap the middle
  around the cable and stick the ends back-to-back to form a flag that reads upright on both
  faces (the far end is auto-rotated 180°). Wrap zone is computed as `π × cable diameter`.
- **Repeating**: the text is tiled along the whole label so it stays readable however the
  label is wound around the cable.

The text auto-fits the label height, and the canvas updates live as you type — then just press **Print!**.

---

## Supported Hardware

BleWebler currently supports the following Marklife printers:
- Marklife P12
- Marklife P15
- Pristar P15
- L13 (SilverCrest and others)

*More models can and will be added via the modular printer driver architecture.*

---

## Requirements

- **Browser**: A Chromium-based browser (Chrome, Edge, ...) with Web Bluetooth Support.
- **Hardware**: A computer or mobile device with Bluetooth 4.0+ support.

---

## License

Licensed under the **GPLv3 License**. You are free to use, modify, and distribute this software in accordance with the license terms.


## Credits / Third Party Libraries

This project is based on **[BleWebler by josb25](https://github.com/josb25/BleWebler)** (GPLv3).
The Bluetooth printing protocol, editor, QR generation, and dithering are all from that project.

It also makes use of open source libraries:

### Fabric.js
* **Website:** [http://fabricjs.com/](http://fabricjs.com/)
* **Version:** 5.3.0
* **Copyright:** © 2008-2015 Juriy Zaytsev & Kangax
* **License:** [MIT License](https://github.com/fabricjs/fabric.js/blob/master/LICENSE)