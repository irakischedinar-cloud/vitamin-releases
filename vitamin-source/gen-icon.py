#!/usr/bin/env python3
"""Generate Vitamin Browser icon set - a vitamin capsule in a circle."""

import math
from PIL import Image, ImageDraw

# Brand colors
ORANGE = (255, 107, 0)        # #ff6b00
ORANGE_LIGHT = (255, 133, 51) # #ff8533
DARK_BG = (20, 20, 20)        # #141414
WHITE = (255, 255, 255)

def draw_icon(size):
    """Draw the Vitamin Browser icon at given size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size / 2, size / 2
    margin = size * 0.04
    radius = size / 2 - margin

    # Background circle
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=ORANGE
    )

    # Inner circle (dark)
    inner_r = radius * 0.85
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        fill=DARK_BG
    )

    # Draw vitamin capsule (vertical, centered)
    cap_w = size * 0.22   # capsule width
    cap_h = size * 0.52   # capsule height
    cap_r = cap_w / 2     # end-cap radius

    cap_left = cx - cap_w / 2
    cap_right = cx + cap_w / 2
    cap_top = cy - cap_h / 2
    cap_bot = cy + cap_h / 2

    # Top half of capsule (orange)
    # Top rounded cap
    draw.ellipse(
        [cap_left, cap_top, cap_right, cap_top + cap_w],
        fill=ORANGE
    )
    # Top rectangular body (to midline)
    draw.rectangle(
        [cap_left, cap_top + cap_r, cap_right, cy],
        fill=ORANGE
    )

    # Bottom half of capsule (lighter orange / white)
    # Bottom rounded cap
    draw.ellipse(
        [cap_left, cap_bot - cap_w, cap_right, cap_bot],
        fill=ORANGE_LIGHT
    )
    # Bottom rectangular body (from midline)
    draw.rectangle(
        [cap_left, cy, cap_right, cap_bot - cap_r],
        fill=ORANGE_LIGHT
    )

    # Divider line between halves
    line_thickness = max(1, int(size * 0.015))
    draw.rectangle(
        [cap_left, cy - line_thickness // 2, cap_right, cy + line_thickness // 2 + 1],
        fill=DARK_BG
    )

    # Shine/highlight on top half
    shine_x = cap_left + cap_w * 0.25
    shine_w = cap_w * 0.15
    shine_top = cap_top + cap_w * 0.4
    shine_bot = cy - cap_h * 0.08
    highlight = (255, 160, 80, 120)
    draw.rounded_rectangle(
        [shine_x, shine_top, shine_x + shine_w, shine_bot],
        radius=shine_w / 2,
        fill=highlight
    )

    return img


def main():
    import os
    import sys

    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
    os.makedirs(out_dir, exist_ok=True)

    sizes = [16, 32, 48, 64, 128, 256, 512]

    for s in sizes:
        icon = draw_icon(s)
        path = os.path.join(out_dir, f"vitamin-browser-{s}.png")
        icon.save(path, "PNG")
        print(f"  Generated: {path}")

    # Also create the main icon (128px for pixmaps)
    main_icon = draw_icon(128)
    main_path = os.path.join(out_dir, "vitamin-browser.png")
    main_icon.save(main_path, "PNG")
    print(f"  Main icon: {main_path}")

    print("Done!")


if __name__ == "__main__":
    main()
