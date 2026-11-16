# BTD 700 Control

A native Apple Silicon macOS menu-bar app for the Sennheiser BTD 700. It
communicates with the dongle over USB HID; the app does not need Python.

## Use

Open `build/BTD 700 Control.app` and click the USB dongle icon in the menu bar.
The menu displays the dongle's connection state, **reported active mode**,
codec, and preferred mode. Select High Quality, Gaming / Low Latency, or
Auracast Broadcast; a checkmark marks the preference. The menu stays open when
you click a mode and closes when you click elsewhere.

The app remembers the preference across app launches and tries to restore it
when headphones reconnect while the app is running. On first run, it adopts the
currently active unicast mode when available. Broadcast is never adopted on
first run: it must be selected and confirmed explicitly. Once confirmed, it
will be restored automatically like the other modes and can broadcast audio to
nearby compatible receivers.

The BTD 700 does not identify the connected headphones through this interface,
so the preference applies to the dongle, not a specific pair of headphones.
For safety, the app refuses to choose if multiple BTD 700 dongles are attached.
It pauses mode changes during voice calls. If gaming mode fails while SBC is
active, it attempts a bounded Bluetooth disconnect/reconnect to renegotiate
the codec. This may briefly interrupt audio, and reconnecting can fail.

Choose **Quit BTD 700 Control** to stop it. It has no Dock icon and does **not**
install a daemon or launch automatically at login. The mode can only be restored
while the app is open; open it again after restarting or logging out.

## Build

Requires Apple Silicon, macOS 13 or later, and Apple's command line developer
tools. Xcode and third-party Swift packages are not required.

```sh
cd ~/repos/btd-700-control
sh ./build-app.sh
open "build/BTD 700 Control.app"
```

Quit the running app before rebuilding it. The locally built app is ad-hoc
signed, not notarized. The menu-bar app does not install itself in Applications.

The editable SVG artwork is in `assets/`. To restore the custom Finder icon
for this project folder after moving or cloning it, build the app and run:

```sh
swift tools/SetProjectIcon.swift "$PWD" "$PWD/build/BTD 700 Control.app/Contents/Resources/AppIcon.icns"
```

## Tests

```sh
sh ./test.sh
sh ./test.sh --ui                         # briefly opens a test dropdown
build/tests/hardware-smoke                 # read-only USB status
build/tests/hardware-smoke --roundtrip     # temporarily changes and restores mode
```

With the app open and Gaming selected, `build/tests/hardware-smoke
--test-app-restore` temporarily selects High Quality and checks that the app
restores Gaming. `build/tests/hardware-reconnect` exercises a Bluetooth
disconnect and reconnect while the app is running. These tests interrupt audio.

The HID protocol is based on the reverse-engineered commands in
<https://github.com/sobalap/btd700ctl>; it is not official Sennheiser
documentation. A reported gaming mode or aptX codec does not itself guarantee
a particular end-to-end latency.
