The approved app-icon concept is stored at assets/brand/easyflow-app-icon-concept.png.
It has an opaque white canvas, so it cannot produce a correct macOS icon with
transparent outer corners.

Supply a 1024 x 1024 transparent production master, or an Apple Icon Composer
.icon source, based on the approved two-panel artwork. Then export these standard
iconset names without changing the artwork:

icon_16x16.png
icon_16x16@2x.png
icon_32x32.png
icon_32x32@2x.png
icon_128x128.png
icon_128x128@2x.png
icon_256x256.png
icon_256x256@2x.png
icon_512x512.png
icon_512x512@2x.png

The packaging script creates EasyFlow.icns when these PNGs are present.
