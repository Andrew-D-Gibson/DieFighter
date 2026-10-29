"""Builds the Readable Font option's fonts: a clear sans rescaled so that, at
the same font size, it takes up the room of one of the game's pixel fonts.

Every font size in the game (theme sizes, overrides, draw_string calls) was
picked for m3x6 or m5x7. Rather than scale each of those when the player
turns Readable Font on, the readable font is rescaled once, here: its em is
grown (unitsPerEm) until neither a line of mixed text nor a line of
capitals is wider than in the pixel font, and its ascent and descent are copied from the pixel font
so line height and baseline match too. FontSwap then only swaps fonts.

Capitals decide it (the pixel fonts' are unusually narrow), so mixed-case
text comes out a little narrower than in the pixel font.

Usage (needs fonttools and skia-pathops: pip install fonttools skia-pathops):
    python3 tools/fit_readable_font.py <readable.ttf> <pixel.ttf> <out.ttf> [--wght 500]

The current fonts were built from Atkinson Hyperlegible Next (OFL,
github.com/googlefonts/atkinson-hyperlegible-next, via google/fonts) at
wght 500:
    python3 tools/fit_readable_font.py AtkinsonHyperlegibleNext[wght].ttf \
        Assets/Fonts/m3x6/m3x6.ttf \
        Assets/Fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext-Medium-m3x6.ttf
    (and the same with m5x7)

Import the result with multichannel_signed_distance_field on and msdf_size
192 (not the default 64): the game samples textures with nearest filtering,
and through the 6x camera a coarser field shows as stair-stepped strokes.
test_font_swap.gd checks it.
"""
import argparse
import math

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

## The font is fitted so that neither sentences nor all-caps labels (buttons,
## tabs) come out wider than in the pixel font. Capitals are the tighter
## constraint: the pixel fonts' are as narrow as their lower case.
SAMPLES = (
    "The quick brown fox jumps over the lazy dog 0123456789",
    "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG 0123456789",
)
## Godot lays text out at this size, rounding ascent and descent to whole
## pixels; matching the rounded values keeps line heights identical.
GAME_FONT_SIZE = 16
## Hinting tables tuned for the original em are dropped; the game renders
## these as MSDF, which ignores hinting.
HINTING_TABLES = ("fpgm", "prep", "cvt ", "hdmx", "LTSH", "VDMX", "gasp")


def sample_width(font: TTFont, sample: str) -> float:
    cmap = font.getBestCmap()
    return sum(font["hmtx"][cmap[ord(c)]][0] for c in sample) / font["head"].unitsPerEm


def rounded_px(units: int, upm: int) -> int:
    return round(abs(units) * GAME_FONT_SIZE / upm)


def rename(font: TTFont, pixel_name: str) -> None:
    # A modified font shouldn't pass for the original (OFL section 3 asks
    # this only of Reserved Font Names, which this font has none of).
    for record in font["name"].names:
        if record.nameID in (1, 3, 4, 6, 16):
            text = record.toUnicode()
            # The PostScript name (6) can't contain spaces.
            suffix = "-Fit" + pixel_name if record.nameID == 6 else " Fit " + pixel_name
            record.string = text + suffix


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("readable")
    parser.add_argument("pixel")
    parser.add_argument("out")
    parser.add_argument("--wght", type=float, default=None)
    args = parser.parse_args()

    font = TTFont(args.readable)
    if "fvar" in font:
        axes = {axis.axisTag: axis.defaultValue for axis in font["fvar"].axes}
        if args.wght is not None:
            axes["wght"] = args.wght
        # Overlapping contours (normal in variable fonts) show as seams in
        # MSDF rendering.
        font = instancer.instantiateVariableFont(font, axes, overlap=instancer.OverlapMode.REMOVE, updateFontNames=True)
    pixel = TTFont(args.pixel)
    pixel_upm = pixel["head"].unitsPerEm

    scale = min(sample_width(pixel, sample) / sample_width(font, sample) for sample in SAMPLES)
    new_upm = round(font["head"].unitsPerEm / scale)
    font["head"].unitsPerEm = new_upm
    for tag in HINTING_TABLES:
        if tag in font:
            del font[tag]

    # Rounded down: Godot rounds the MSDF metrics up, and a hair over a whole
    # pixel would add a line-height pixel.
    ascent = math.floor(rounded_px(pixel["hhea"].ascent, pixel_upm) * new_upm / GAME_FONT_SIZE)
    descent = -math.floor(rounded_px(pixel["hhea"].descent, pixel_upm) * new_upm / GAME_FONT_SIZE)
    font["hhea"].ascent, font["hhea"].descent, font["hhea"].lineGap = ascent, descent, 0
    os2 = font["OS/2"]
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = ascent, descent, 0
    os2.usWinAscent, os2.usWinDescent = ascent, -descent

    pixel_name = args.pixel.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    rename(font, pixel_name)
    font.save(args.out)
    print(f"{args.out}: scale {scale:.3f}, unitsPerEm {new_upm}, ascent {ascent}, descent {descent}")


main()
