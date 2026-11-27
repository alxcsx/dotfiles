#!/usr/bin/env bash
set -euo pipefail

geom="$(slurp -d)" || exit 0
[ -n "$geom" ] || exit 0

tmp="$(mktemp --suffix=.png /tmp/screenshot-XXXXXX)"
trap 'rm -f "$tmp"' EXIT

grim -g "$geom" "$tmp"
wl-copy --type image/png < "$tmp"

action="$(notify-send \
    -t 8000 \
    -a "Screenshot" \
    -i "$tmp" \
    -A "default=Editar no Satty" \
    -A "edit=Editar no Satty" \
    "Screenshot copiado" \
    "Clique para abrir e anotar no Satty" || true)"

if [ "$action" = "default" ] || [ "$action" = "edit" ]; then
    satty --filename "$tmp"
fi
