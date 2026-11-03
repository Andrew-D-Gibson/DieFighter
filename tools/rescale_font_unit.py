"""Copies a scalable font so that, drawn at one size, it looks exactly like the
source drawn at another: only the em (unitsPerEm) changes, so every outline,
advance, ascent and descent keeps its pixel size.

Why: Godot draws a fallback font at the primary font's size. Readable Font
puts its font (fitted at 16 by tools/fit_readable_font.py) in front of the
language's fonts, so in Chinese and Japanese, whose pixel font is native at
12, the readable font has to lead at 12 too, or Fusion Pixel would draw off
its grid at 16. A copy rescaled from 16 to 12 draws Latin text exactly where
the 16 version did, at size 12.

--ascent / --descent (pixels at the new size) replace the line metrics.
Godot sizes a Label's lines by the tallest font in its fallback chain, plus
the leading font's spacing. Fusion Pixel's own line is 16 px (13 above the
baseline, 3 below) and its face trims 3 px of spacing to make English's 13.
Giving the readable copy Fusion's line and the same trim keeps Label and
RichTextLabel lines alike at 13, Latin or Chinese.

Pure Python, no packages needed:
    python3 tools/rescale_font_unit.py <in.ttf> <out.ttf> <from size> <to size> [--ascent PX --descent PX]

The current copies:
    python3 tools/rescale_font_unit.py \
        Assets/Fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext-Medium-m5x7.ttf \
        Assets/Fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext-Medium-m5x7-at12.ttf 16 12 \
        --ascent 13 --descent 3
    (and the same with m3x6)

unitsPerEm is a whole number, so the copy can be a hair (under 0.05%) smaller
(test_font_roles.gd checks Latin text measures as at 16). Import the copy like
its source (MSDF, msdf_size 192).
"""
import argparse
import math
import struct

_CHECKSUM_MAGIC = 0xB1B0AFBA


def _checksum(data: bytes) -> int:
    padded = data + b"\0" * (-len(data) % 4)
    return sum(struct.unpack(">%dI" % (len(padded) // 4), padded)) & 0xFFFFFFFF


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("out")
    parser.add_argument("from_size", type=int)
    parser.add_argument("to_size", type=int)
    parser.add_argument("--ascent", type=int, default=None)
    parser.add_argument("--descent", type=int, default=None)
    args = parser.parse_args()
    source, out, from_size, to_size = args.source, args.out, args.from_size, args.to_size
    font = bytearray(open(source, "rb").read())
    table_count = struct.unpack(">H", font[4:6])[0]
    tables = {}
    for i in range(table_count):
        entry = 12 + 16 * i
        tag, _, offset, length = struct.unpack(">4sIII", font[entry:entry + 16])
        tables[tag] = (entry, offset, length)

    _, head, _ = tables[b"head"]
    upm = struct.unpack(">H", font[head + 18:head + 20])[0]
    new_upm = round(upm * to_size / from_size)
    struct.pack_into(">H", font, head + 18, new_upm)

    if args.ascent is not None and args.descent is not None:
        # Rounded down, as tools/fit_readable_font.py does: Godot rounds the
        # metrics up, and a hair over a whole pixel would add a pixel.
        ascent = math.floor(args.ascent * new_upm / to_size)
        descent = -math.floor(args.descent * new_upm / to_size)
        hhea = tables[b"hhea"][1]
        struct.pack_into(">hhh", font, hhea + 4, ascent, descent, 0)
        os2 = tables[b"OS/2"][1]
        struct.pack_into(">hhhHH", font, os2 + 68, ascent, descent, 0, ascent, -descent)

    # The head table's checksum is taken with checkSumAdjustment zeroed, and
    # the adjustment then makes the whole file sum to the magic number.
    struct.pack_into(">I", font, head + 8, 0)
    for entry, offset, length in tables.values():
        struct.pack_into(">I", font, entry + 4, _checksum(bytes(font[offset:offset + length])))
    struct.pack_into(">I", font, head + 8, (_CHECKSUM_MAGIC - _checksum(bytes(font))) & 0xFFFFFFFF)

    open(out, "wb").write(font)
    print(f"{out}: unitsPerEm {upm} -> {new_upm} (draws at {to_size} as the source at {from_size})")


main()
