#!/usr/bin/env bash

set -x  # Print each command as it runs for debugging

# directory for CMake output
BUILD=build

# directory for application output
mkdir -p out

# Show what's in the current directory and src before building
ls -l
echo "--- src directory ---"
ls -l src || echo "src directory missing"
echo "--- CMakeLists.txt ---"
ls -l CMakeLists.txt || echo "CMakeLists.txt missing"

echo "--- /tmp/meeting-sdk-linux-sample ---"
ls -l /tmp/meeting-sdk-linux-sample || echo "/tmp/meeting-sdk-linux-sample missing"

setup-pulseaudio() {
  # Enable dbus
  if [[  ! -d /var/run/dbus ]]; then
    mkdir -p /var/run/dbus
    dbus-uuidgen > /var/lib/dbus/machine-id

    dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address
  fi

  usermod -G pulse-access,audio root

  # Cleanup to be "stateless" on startup, otherwise pulseaudio daemon can't start
  rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse/
  mkdir -p ~/.config/pulse/ && cp -r /etc/pulse/* "$_"

  pulseaudio -D --exit-idle-time=-1 --system --disallow-exit

  # Create a virtual speaker output

  pactl load-module module-null-sink sink_name=SpeakerOutput
  pactl set-default-sink SpeakerOutput
  pactl set-default-source SpeakerOutput.monitor

  # Make config file
  echo -e "[General]\nsystem.audio.type=default" > ~/.config/zoomus.conf
}

build() {
  # Only run CMake if the Makefile does not exist
  [[ ! -f "$BUILD/Makefile" ]] && {
    cmake -B "$BUILD" -S . || { echo "CMake configuration failed"; exit 1; }
    npm --prefix=client install
  }

  # Rename the shared library
  LIB="lib/zoomsdk/libmeetingsdk.so"
  [[ ! -f "${LIB}.1" ]] && cp "$LIB"{,.1}

  # Set up and start pulseaudio
  setup-pulseaudio || exit

# Set PulseAudio server for all processes
export PULSE_SERVER=localhost

# Show PulseAudio info for debugging
pactl info || echo "pactl info failed"

  # Build the Source Code
  cmake --build "$BUILD" || { echo "CMake build failed"; exit 1; }
}

run() {
    exec ./"$BUILD"/zoomsdk
}

build && run;

exit $?

