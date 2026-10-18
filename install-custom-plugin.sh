#!/bin/sh
# Builds this fork's plugin and installs it over the local RojoCustom plugin.
# Studio hot-reloads it into every open place, so start 7.7.1+ servers first.
set -e
cd "$(dirname "$0")"
rojo_exe="$HOME/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo.exe"
mkdir -p build
"$rojo_exe" build plugin.project.json -o build/RojoCustom.rbxmx
cp build/RojoCustom.rbxmx "$LOCALAPPDATA/Roblox/Plugins/RojoCustom.rbxmx"
echo "Installed RojoCustom.rbxmx"
