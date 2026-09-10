#!/bin/bash
#
# Rebuilds the app screenshots on this page from the app's own interface code.
#
# Run this after any UI change in the app repository, or the page keeps
# advertising an interface that no longer ships.
#
# The renders come from the app repo's Scripts/preview.sh, which compiles the
# real SwiftUI views against seeded sample windows — so these are screenshots of
# the shipping interface, not mock-ups, and they contain no real window titles.
#
# Environment:
#   APP_REPO   path to the Window Pin source checkout
set -euo pipefail

SITE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_REPO="${APP_REPO:-$HOME/Documents/app-floating}"
IMAGES="${SITE}/images"

[[ -x "${APP_REPO}/Scripts/preview.sh" ]] || {
  echo "error: no preview script at ${APP_REPO}/Scripts/preview.sh" >&2
  echo "       set APP_REPO to the Window Pin checkout" >&2
  exit 1
}

echo "==> Rendering the interface"
"${APP_REPO}/Scripts/preview.sh" >/dev/null
PREV="${APP_REPO}/build/preview"

# macOS draws popovers with rounded corners and a shadow. Without both, a
# screenshot reads as a flat rectangle pasted onto the page rather than as a
# window floating above it.
round_and_shadow() {
  local src="$1" dst="$2" radius="$3" w h
  w=$(magick identify -format '%w' "$src")
  h=$(magick identify -format '%h' "$src")
  magick -size "${w}x${h}" xc:black -fill white \
    -draw "roundrectangle 0,0 $((w-1)),$((h-1)) ${radius},${radius}" /tmp/_wp_mask.png
  magick "$src" /tmp/_wp_mask.png -alpha Off -compose CopyOpacity -composite /tmp/_wp_round.png
  magick /tmp/_wp_round.png \( +clone -background black -shadow 55x24+0+12 \) \
    +swap -background none -layers merge +repage "$dst"
}

echo "==> Composing"
for theme in dark light; do
  # The popover is one surface in the app; the harness renders its two halves
  # separately, so they are rejoined here across the same hairline the app draws.
  [[ "${theme}" == dark ]] && line='#3A3A3C' || line='#D8D8DC'
  magick "${PREV}/panel-header-${theme}.png" \
         \( -size 680x2 xc:"${line}" \) \
         "${PREV}/controller-${theme}.png" \
         -append +repage /tmp/_wp_popover.png
  round_and_shadow /tmp/_wp_popover.png "${IMAGES}/screenshot-popover-${theme}.png" 24
  round_and_shadow "${PREV}/drop-zone-${theme}.png" "${IMAGES}/screenshot-panel-${theme}.png" 20
  round_and_shadow "${PREV}/permission-${theme}.png" "${IMAGES}/screenshot-permission-${theme}.png" 20
done

# Hero: both surfaces on one backdrop in the page's own palette.
W=1440; H=860
magick -size ${W}x${H} gradient:'#1B2440-#0D1322' /tmp/_wp_bg.png
magick /tmp/_wp_bg.png \
  \( -size ${W}x${H} radial-gradient:'#2F62E8'-none -resize ${W}x${H}\! \) \
  -compose Overlay -define compose:args=22 -composite -alpha off /tmp/_wp_bg2.png
magick "${IMAGES}/screenshot-popover-dark.png" -resize 62% /tmp/_wp_pop.png
magick "${IMAGES}/screenshot-panel-dark.png"   -resize 88% /tmp/_wp_pan.png
magick /tmp/_wp_bg2.png \
  /tmp/_wp_pan.png -geometry +605+185 -composite \
  /tmp/_wp_pop.png -geometry +115+45  -composite \
  +repage "${IMAGES}/screenshot-hero.png"

rm -f /tmp/_wp_*.png

echo
echo "The width/height attributes in index.html must match these files, or the"
echo "page reserves the wrong space and the layout jumps as the images load:"
for f in "${IMAGES}"/screenshot-*.png; do
  printf "  %-40s %s\n" "$(basename "$f")" "$(magick identify -format '%wx%h' "$f")"
done
