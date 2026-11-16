# BTD 700 Control

A macOS menu bar app for controlling the Sennheiser BTD 700 USB dongle. View connection status, active mode, and codec, and switch between High Quality, Gaming / Low Latency, and Auracast Broadcast.

## Requirements

- Apple Silicon Mac running macOS 13 or later
- Sennheiser BTD 700

## Download

Download the app from [GitHub Releases](https://github.com/seriousm4x/btd-700-control/releases).

## Build and run

Building requires Apple command line developer tools.

```sh
git clone https://github.com/seriousm4x/btd-700-control.git
cd btd-700-control
sh ./build-app.sh
open "build/BTD 700 Control.app"
```

Click the dongle icon in the menu bar to select a mode. The app remembers your preference and attempts to restore it when headphones reconnect, as long as the app is running. It does not start automatically at login.

Auracast requires confirmation and may broadcast audio to nearby compatible devices. The preference applies to the dongle, not individual headphones. Mode changes pause during calls, and the app will not control multiple BTD 700 dongles at once. Switching to Gaming may briefly interrupt audio if a Bluetooth reconnect is needed.

The locally built app is ad-hoc signed and not notarized. Quit the app before rebuilding.

## Tests

Run `sh ./test.sh` for the mode policy tests. Add `--ui` to also run the menu test.

The USB HID commands are based on [btd700ctl](https://github.com/sobalap/btd700ctl), not official Sennheiser documentation.
