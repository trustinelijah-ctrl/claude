#!/usr/bin/env python3
"""App icon: a boxwood king standing on a walnut square, with a fine gilt inlay.
  python3 tools/icon.py App/Resources/Assets.xcassets
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import cairosvg
from pieces import svg_piece

def main(catalog):
    s = 1024
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}" viewBox="0 0 {s} {s}">
<defs>
  <radialGradient id="bg" cx="0.5" cy="0.38" r="0.75">
    <stop offset="0" stop-color="#4A2F1F"/><stop offset="0.55" stop-color="#2A1A11"/><stop offset="1" stop-color="#140C08"/>
  </radialGradient>
  <radialGradient id="pool" cx="0.5" cy="0.86" r="0.3">
    <stop offset="0" stop-color="#000" stop-opacity="0.45"/><stop offset="1" stop-color="#000" stop-opacity="0"/>
  </radialGradient>
</defs>
<rect width="{s}" height="{s}" fill="url(#bg)"/>
<rect x="92" y="92" width="840" height="840" fill="none" stroke="#C9A66B" stroke-opacity="0.55" stroke-width="5"/>
<ellipse cx="512" cy="872" rx="300" ry="60" fill="url(#pool)"/>
{svg_piece('king', 'white', 152, 132, 720)}
</svg>'''
    d = os.path.join(catalog, 'AppIcon.appiconset')
    os.makedirs(d, exist_ok=True)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=os.path.join(d, 'AppIcon.png'), output_width=s, output_height=s)
    json.dump({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, 'Contents.json'), 'w'), indent=2)

    def color(name, r, g, b):
        cd = os.path.join(catalog, f'{name}.colorset')
        os.makedirs(cd, exist_ok=True)
        json.dump({"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
            "red": f"{r/255:.3f}", "green": f"{g/255:.3f}", "blue": f"{b/255:.3f}", "alpha": "1.000"}}}],
            "info": {"author": "xcode", "version": 1}}, open(os.path.join(cd, 'Contents.json'), 'w'), indent=2)
    color('LaunchBackground', 0x14, 0x0F, 0x0C)
    color('AccentColor', 0xD9, 0xB1, 0x72)
    json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(catalog, 'Contents.json'), 'w'), indent=2)

if __name__ == '__main__':
    main(sys.argv[1])
