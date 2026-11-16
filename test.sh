#!/bin/sh
set -eu

cd "$(dirname "$0")"
mkdir -p build/tests
swiftc -target arm64-apple-macos13.0 \
    Sources/Models.swift Sources/ModePolicy.swift Tests/ModePolicyTests.swift \
    -o build/tests/mode-policy-tests
build/tests/mode-policy-tests
swiftc -target arm64-apple-macos13.0 -framework IOKit \
    Sources/Models.swift Sources/ModePolicy.swift Sources/BTDHID.swift Tests/HardwareSmoke.swift \
    -o build/tests/hardware-smoke
swiftc -target arm64-apple-macos13.0 -framework IOKit \
    Sources/Models.swift Sources/ModePolicy.swift Sources/BTDHID.swift Tests/HardwareReconnect.swift \
    -o build/tests/hardware-reconnect
echo "For a read-only device check: build/tests/hardware-smoke"
echo "For a temporary mode-change test: build/tests/hardware-smoke --roundtrip"
echo "With the app running and Gaming preferred: build/tests/hardware-smoke --test-app-restore"
echo "With the app running: build/tests/hardware-reconnect (interrupts Bluetooth)"

if [ "${1:-}" = "--ui" ]; then
    swiftc -target arm64-apple-macos13.0 -framework AppKit \
        Sources/NativeModeItem.swift Tests/NativeMenuTests.swift \
        -o build/tests/native-menu-tests
    build/tests/native-menu-tests
fi
