#!/bin/sh
echo -ne '\033c\033]0;Zoomer Battle\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Zoomies-Server.x86_64" "$@"
