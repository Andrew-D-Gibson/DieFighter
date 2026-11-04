#!/usr/bin/env python3
"""Build and recolor controller prompt icons for Xbox, PlayStation, and Steam.

All icons are strictly recolored to the 33-color approved palette from
Art/_Palettes/aseprite_palette_final.aseprite, with outlines in #040217 (never pure black).
"""
import os
import subprocess
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
KENNEY_TILES = ROOT / "Assets" / "Inspiration Resources" / "Input Prompts Pixel" / "Tiles"
OUT_ART = ROOT / "Art" / "Textures" / "UI" / "InputPrompts"
ASEPRITE = "/Applications/Aseprite.app/Contents/MacOS/aseprite"

# Approved 33-color palette colors
C_TRANSPARENT = (0, 0, 0, 0)
C_OUTLINE = (4, 2, 23, 255)         # #040217 (outlines, never pure black)
C_DARK_SHADOW = (15, 12, 46, 255)   # #0f0c2e
C_DARK_BG = (52, 51, 48, 255)       # #343330
C_MID_GRAY = (99, 96, 92, 255)      # #63605c
C_LIGHT_GRAY = (142, 139, 133, 255) # #8e8b85
C_PALE_GRAY = (165, 162, 157, 255)  # #a5a29d
C_WHITE = (196, 193, 188, 255)      # #c4c1bc
C_HIGHLIGHT = (206, 240, 241, 255)  # #cef0f1

# Saturated / Accent colors
C_GREEN = (122, 189, 51, 255)       # #7abd33 (Xbox A / PS Triangle)
C_GREEN_DARK = (76, 117, 32, 255)   # #4c7520
C_RED = (208, 54, 86, 255)          # #d03656 (Xbox B / PS Circle)
C_RED_DARK = (144, 38, 60, 255)     # #90263c
C_BLUE = (67, 166, 252, 255)        # #43a6fc (Xbox X / PS Cross)
C_BLUE_DARK = (44, 113, 170, 255)   # #2c71aa
C_YELLOW = (238, 211, 93, 255)      # #eed35d (Xbox Y / D-pad highlights / Mouse click)
C_YELLOW_DARK = (152, 135, 59, 255) # #98873b
C_PURPLE = (197, 82, 241, 255)      # #c552f1 (PS Square)
C_PURPLE_DARK = (128, 53, 157, 255) # #80359d

def load_tile(idx: int) -> Image.Image:
    path = KENNEY_TILES / f"tile_{idx:04d}.png"
    return Image.open(path).convert("RGBA")

def recolor_button(tile_idx: int, face_color, dark_face_color, letter_color=C_WHITE, outline_color=C_OUTLINE) -> Image.Image:
    src = load_tile(tile_idx)
    im = Image.new("RGBA", src.size, C_TRANSPARENT)
    for y in range(src.height):
        for x in range(src.width):
            p = src.getpixel((x, y))
            if p[3] == 0:
                continue
            r, g, b = p[:3]
            # Outer border / dark outline
            if r == 67 and g == 74 and b == 95:
                im.putpixel((x, y), outline_color)
            elif r == 255 and g == 255 and b == 255:
                im.putpixel((x, y), letter_color)
            # Kenney tile highlights / top rim
            elif (r > 200 and g > 200 and b < 150) or (r < 150 and g > 200 and b > 200) or (r > 240 and g > 130 and b > 100):
                im.putpixel((x, y), face_color)
            # Main face
            elif (r > 150 or g > 150 or b > 150):
                im.putpixel((x, y), face_color)
            # Dark bottom shadow of the button face
            else:
                im.putpixel((x, y), dark_face_color)
    return im

def recolor_dark_button(tile_idx: int, letter_color=C_WHITE) -> Image.Image:
    """Dark button (PlayStation / Steam style) with white or colored symbol."""
    src = load_tile(tile_idx)
    im = Image.new("RGBA", src.size, C_TRANSPARENT)
    for y in range(src.height):
        for x in range(src.width):
            p = src.getpixel((x, y))
            if p[3] == 0:
                continue
            r, g, b = p[:3]
            if r == 67 and g == 74 and b == 95:
                im.putpixel((x, y), C_OUTLINE)
            elif r == 255 and g == 255 and b == 255:
                im.putpixel((x, y), letter_color)
            elif r > 180 and g > 180 and b > 180:
                im.putpixel((x, y), C_MID_GRAY)
            elif r > 100 and g > 100 and b > 100:
                im.putpixel((x, y), C_DARK_BG)
            else:
                im.putpixel((x, y), C_DARK_SHADOW)
    return im

def recolor_hardware_tile(tile_idx: int, highlight_color=None) -> Image.Image:
    """Recolors bumpers, triggers, sticks, and d-pads."""
    src = load_tile(tile_idx)
    im = Image.new("RGBA", src.size, C_TRANSPARENT)
    for y in range(src.height):
        for x in range(src.width):
            p = src.getpixel((x, y))
            if p[3] == 0:
                continue
            r, g, b = p[:3]
            # Outer dark border
            if r < 80 and g < 85 and b < 105:
                im.putpixel((x, y), C_OUTLINE)
            # White text / arrows
            elif r > 200 and g > 200 and b > 200:
                if highlight_color:
                    im.putpixel((x, y), highlight_color)
                else:
                    im.putpixel((x, y), C_WHITE)
            # Light/top surface
            elif r > 160 and g > 160 and b > 160:
                im.putpixel((x, y), C_LIGHT_GRAY)
            # Mid body
            elif r > 100 and g > 100 and b > 100:
                im.putpixel((x, y), C_MID_GRAY)
            # Shaded body
            else:
                im.putpixel((x, y), C_DARK_BG)
    return im

def make_ps_shape_button(shape_type: str, shape_color) -> Image.Image:
    """Base dark button (from tile 46) + clean pixel geometric shape."""
    base = recolor_dark_button(46)
    # Tile 46 has center area from x=5..10, y=5..10
    # Center is at x=7.5, y=7.5
    # Let's draw the clean 5x5 PlayStation geometric shape
    if shape_type == "cross":
        pixels = [
            (5, 5), (9, 5),
            (6, 6), (8, 6),
            (7, 7),
            (6, 8), (8, 8),
            (5, 9), (9, 9),
        ]
    elif shape_type == "circle":
        pixels = [
            (6, 5), (7, 5), (8, 5),
            (5, 6), (9, 6),
            (5, 7), (9, 7),
            (5, 8), (9, 8),
            (6, 9), (7, 9), (8, 9),
        ]
    elif shape_type == "square":
        pixels = [
            (5, 5), (6, 5), (7, 5), (8, 5), (9, 5),
            (5, 6), (9, 6),
            (5, 7), (9, 7),
            (5, 8), (9, 8),
            (5, 9), (6, 9), (7, 9), (8, 9), (9, 9),
        ]
    elif shape_type == "triangle":
        pixels = [
            (7, 5),
            (6, 6), (8, 6),
            (6, 7), (8, 7),
            (5, 8), (9, 8),
            (5, 9), (6, 9), (7, 9), (8, 9), (9, 9),
        ]
    for px, py in pixels:
        base.putpixel((px, py), shape_color)
    return base

def make_mouse_icon(button: str) -> Image.Image:
    """16x16 mouse indicator with designated button highlighted in yellow."""
    im = Image.new("RGBA", (16, 16), C_TRANSPARENT)
    # Outer shape of mouse (matches mouse_indicator.png)
    body_pixels = [
        # Outer shell
        (6, 2), (7, 2), (8, 2), (9, 2),
        (5, 3), (10, 3),
        (4, 4), (11, 4),
        (4, 5), (11, 5),
        (4, 6), (11, 6),
        (4, 7), (11, 7),
        (4, 8), (11, 8),
        (4, 9), (11, 9),
        (4, 10), (11, 10),
        (5, 11), (10, 11),
        (5, 12), (10, 12),
        (6, 13), (9, 13),
        (7, 14), (8, 14),
    ]
    # Draw outline
    for px, py in body_pixels:
        im.putpixel((px, py), C_OUTLINE)

    # Fill lower body (rows 7..13)
    for y in range(7, 14):
        for x in range(5, 11):
            if (x, y) not in body_pixels and (x-1, y) in body_pixels and (x+1, y) in body_pixels or (5 <= x <= 10 and 7 <= y <= 12):
                im.putpixel((x, y), C_DARK_BG)

    # Dividing seam between left and right button (x=7,8, y=3..6)
    # Left button area: x=5..7, y=3..6
    # Right button area: x=8..10, y=3..6
    left_color = C_YELLOW if button == "left" else C_MID_GRAY
    left_dark = C_YELLOW_DARK if button == "left" else C_DARK_BG
    right_color = C_YELLOW if button == "right" else C_MID_GRAY
    right_dark = C_YELLOW_DARK if button == "right" else C_DARK_BG
    mid_color = C_YELLOW if button == "middle" else C_LIGHT_GRAY

    # Fill buttons
    for y in range(3, 7):
        for x in range(5, 8):
            im.putpixel((x, y), left_color if y < 5 else left_dark)
        for x in range(8, 11):
            im.putpixel((x, y), right_color if y < 5 else right_dark)

    # Middle wheel: (7, 4), (7, 5)
    im.putpixel((7, 4), mid_color)
    im.putpixel((7, 5), mid_color)
    # Seam between buttons
    im.putpixel((7, 3), C_OUTLINE)
    im.putpixel((7, 6), C_OUTLINE)
    return im

def make_compound_bumpers(left_im: Image.Image, right_im: Image.Image) -> Image.Image:
    """Creates a side-by-side LB/RB or L1/R1 combo prompt (26x16)."""
    combo = Image.new("RGBA", (26, 16), C_TRANSPARENT)
    # Left bumper cropped/placed at (0, 0)
    combo.paste(left_im.crop((1, 0, 14, 16)), (0, 0))
    # Right bumper cropped/placed at (13, 0)
    combo.paste(right_im.crop((2, 0, 15, 16)), (13, 0))
    return combo

def save_and_convert(im: Image.Image, name: str):
    tmp_png = Path(f"/tmp/{name}.png")
    out_ase = OUT_ART / f"{name}.aseprite"
    im.save(tmp_png)
    subprocess.run([ASEPRITE, "-b", str(tmp_png), "--save-as", str(out_ase)], check=True)
    tmp_png.unlink(missing_ok=True)
    print(f"Authored: {out_ase.name}")

def main():
    OUT_ART.mkdir(parents=True, exist_ok=True)

    # 1. Xbox Prompts
    xbox_a = recolor_button(4, C_GREEN, C_GREEN_DARK, C_WHITE)
    xbox_b = recolor_button(5, C_RED, C_RED_DARK, C_WHITE)
    xbox_x = recolor_button(6, C_BLUE, C_BLUE_DARK, C_WHITE)
    xbox_y = recolor_button(7, C_YELLOW, C_YELLOW_DARK, C_WHITE)
    save_and_convert(xbox_a, "xbox_a")
    save_and_convert(xbox_b, "xbox_b")
    save_and_convert(xbox_x, "xbox_x")
    save_and_convert(xbox_y, "xbox_y")

    xbox_lb = recolor_hardware_tile(619)
    xbox_rb = recolor_hardware_tile(620)
    xbox_lt = recolor_hardware_tile(621)
    xbox_rt = recolor_hardware_tile(622)
    save_and_convert(xbox_lb, "xbox_lb")
    save_and_convert(xbox_rb, "xbox_rb")
    save_and_convert(xbox_lt, "xbox_lt")
    save_and_convert(xbox_rt, "xbox_rt")

    xbox_ls = recolor_hardware_tile(625)
    xbox_rs = recolor_hardware_tile(626)
    save_and_convert(xbox_ls, "xbox_ls")
    save_and_convert(xbox_rs, "xbox_rs")

    save_and_convert(recolor_hardware_tile(815), "xbox_dpad")
    save_and_convert(recolor_hardware_tile(811, C_YELLOW), "xbox_dpad_up")
    save_and_convert(recolor_hardware_tile(813, C_YELLOW), "xbox_dpad_down")
    save_and_convert(recolor_hardware_tile(812, C_YELLOW), "xbox_dpad_left")
    save_and_convert(recolor_hardware_tile(814, C_YELLOW), "xbox_dpad_right")

    save_and_convert(recolor_dark_button(651, C_WHITE), "xbox_menu")
    save_and_convert(recolor_dark_button(650, C_WHITE), "xbox_view")
    save_and_convert(make_compound_bumpers(xbox_lb, xbox_rb), "xbox_lb_rb")

    # 2. PlayStation Prompts
    ps_cross = make_ps_shape_button("cross", C_BLUE)
    ps_circle = make_ps_shape_button("circle", C_RED)
    ps_square = make_ps_shape_button("square", C_PURPLE)
    ps_triangle = make_ps_shape_button("triangle", C_GREEN)
    save_and_convert(ps_cross, "ps_cross")
    save_and_convert(ps_circle, "ps_circle")
    save_and_convert(ps_square, "ps_square")
    save_and_convert(ps_triangle, "ps_triangle")

    ps_l1 = recolor_hardware_tile(631)
    ps_r1 = recolor_hardware_tile(632)
    ps_l2 = recolor_hardware_tile(663)
    ps_r2 = recolor_hardware_tile(664)
    save_and_convert(ps_l1, "ps_l1")
    save_and_convert(ps_r1, "ps_r1")
    save_and_convert(ps_l2, "ps_l2")
    save_and_convert(ps_r2, "ps_r2")

    ps_l3 = recolor_hardware_tile(633)
    ps_r3 = recolor_hardware_tile(634)
    save_and_convert(ps_l3, "ps_l3")
    save_and_convert(ps_r3, "ps_r3")

    save_and_convert(recolor_hardware_tile(815), "ps_dpad")
    save_and_convert(recolor_hardware_tile(811, C_HIGHLIGHT), "ps_dpad_up")
    save_and_convert(recolor_hardware_tile(813, C_HIGHLIGHT), "ps_dpad_down")
    save_and_convert(recolor_hardware_tile(812, C_HIGHLIGHT), "ps_dpad_left")
    save_and_convert(recolor_hardware_tile(814, C_HIGHLIGHT), "ps_dpad_right")

    save_and_convert(recolor_dark_button(651, C_WHITE), "ps_options")
    save_and_convert(recolor_dark_button(650, C_WHITE), "ps_share")
    save_and_convert(make_compound_bumpers(ps_l1, ps_r1), "ps_l1_r1")

    # 3. Steam Prompts
    steam_a = recolor_button(13, C_DARK_BG, C_DARK_SHADOW, C_WHITE)
    steam_b = recolor_button(14, C_DARK_BG, C_DARK_SHADOW, C_WHITE)
    steam_x = recolor_button(15, C_DARK_BG, C_DARK_SHADOW, C_WHITE)
    steam_y = recolor_button(16, C_DARK_BG, C_DARK_SHADOW, C_WHITE)
    save_and_convert(steam_a, "steam_a")
    save_and_convert(steam_b, "steam_b")
    save_and_convert(steam_x, "steam_x")
    save_and_convert(steam_y, "steam_y")

    save_and_convert(xbox_lb, "steam_l1")
    save_and_convert(xbox_rb, "steam_r1")
    save_and_convert(xbox_lt, "steam_l2")
    save_and_convert(xbox_rt, "steam_r2")
    save_and_convert(xbox_ls, "steam_l3")
    save_and_convert(xbox_rs, "steam_r3")
    save_and_convert(recolor_hardware_tile(815), "steam_dpad")
    save_and_convert(recolor_hardware_tile(811, C_WHITE), "steam_dpad_up")
    save_and_convert(recolor_hardware_tile(813, C_WHITE), "steam_dpad_down")
    save_and_convert(recolor_hardware_tile(812, C_WHITE), "steam_dpad_left")
    save_and_convert(recolor_hardware_tile(814, C_WHITE), "steam_dpad_right")
    save_and_convert(recolor_dark_button(651, C_WHITE), "steam_menu")
    save_and_convert(recolor_dark_button(650, C_WHITE), "steam_view")
    save_and_convert(make_compound_bumpers(xbox_lb, xbox_rb), "steam_lb_rb")

    # 4. Mouse Prompts
    save_and_convert(make_mouse_icon("left"), "mouse_left")
    save_and_convert(make_mouse_icon("right"), "mouse_right")
    save_and_convert(make_mouse_icon("middle"), "mouse_middle")

    print("\nAll input prompt .aseprite sources generated successfully.")

if __name__ == "__main__":
    main()
