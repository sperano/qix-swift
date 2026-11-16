#!/usr/bin/env python3
"""Renders the app icon variants into the asset catalog, or checks the committed ones.

    python3 Design/render_icons.py           # writes the three PNGs; commit them
    python3 Design/render_icons.py --check   # fails when a committed PNG differs from its render

The icon is pixel art like the game's sprites, so it is squares only and needs no vector
renderer: Python's standard library writes the PNGs on Linux and macOS alike. Its colours and
sprites are read from the game's own sources (QixKit's Palette.swift and Sprite.swift), so the
icon cannot drift from what the board draws. A playfield: the border, a fast and a slow claim,
the Qix's trail in the open, a Sparx on the border and the marker on a claim's corner. Square and
full bleed: iOS rounds the corners itself.

Variants, as in solitaire: the light icon on the playfield's background, written without an alpha
channel (App Store Connect rejects an App Store icon with one, even fully opaque: ITMS-90717); the
dark one with the background left clear, since iOS draws its own dark gradient under it; the
tinted one in greys on a clear background, which the system colours.
"""

import argparse
import pathlib
import re
import struct
import sys
import zlib

REPOSITORY = pathlib.Path(__file__).resolve().parent.parent
PALETTE = REPOSITORY / "QixKit/Sources/QixKit/FrontEnd/Palette.swift"
SPRITE = REPOSITORY / "QixKit/Sources/QixKit/FrontEnd/Sprite.swift"
ICON_SET = REPOSITORY / "Qix/Resources/Assets.xcassets/AppIcon.appiconset"

SIZE = 1024
CHANNEL_MAX = 255
TRANSPARENT = (0, 0, 0, 0)

# The playfield's lattice lines, in pixels: the board's sides, and the claims' edges.
BOARD_LEFT, BOARD_TOP, BOARD_RIGHT, BOARD_BOTTOM = 128, 128, 896, 896
FAST_CLAIM_RIGHT, FAST_CLAIM_TOP = 450, 520
SLOW_CLAIM_LEFT, SLOW_CLAIM_BOTTOM = 640, 330
# Width of the border lines, centred on their lattice lines, in pixels.
BORDER_WIDTH = 28
# The Qix's trail, oldest segment first, each moved on and turned from the last, one per colour of
# the palette's trail; and the side of the squares its staircase lines are stamped with, in pixels.
TRAIL = (
    ((548, 602), (692, 398)),
    ((552, 617), (732, 443)),
    ((559, 628), (769, 492)),
    ((570, 637), (802, 543)),
    ((585, 644), (831, 596)),
    ((605, 650), (855, 650)),
    ((629, 656), (875, 704)),
    ((658, 663), (890, 757)),
)
QIX_PIXEL = 24
# The sprites' pixels, in pixels, and where they are centred.
MARKER_PIXEL = 16
MARKER_CENTRE = (FAST_CLAIM_RIGHT, FAST_CLAIM_TOP)
SPARX_PIXEL = 12
SPARX_CENTRE = (300, BOARD_TOP)

# Rec. 709 luma weights, for the tinted icon's greys.
LUMA = (0.2126, 0.7152, 0.0722)

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
BIT_DEPTH = 8
COLOUR_TYPE_RGB = 2
COLOUR_TYPE_RGBA = 6
COMPRESSION_LEVEL = 9
NO_FILTER = b"\x00"

# name, keeps the background, greys
VARIANTS = (("AppIcon", True, False), ("AppIcon-Dark", False, False), ("AppIcon-Tinted", False, True))


class SourceError(Exception):
    """A colour or sprite the icon needs is not in the Swift sources."""


def palette(source):
    """The colours `Palette.swift` declares, by name, as (red, green, blue) tuples; the trail's as
    a list."""
    colours = {}
    for name, red, green, blue in re.findall(
        r"static let (\w+) = RGBA\(red: (\d+), green: (\d+), blue: (\d+)\)", source
    ):
        colours[name] = (int(red), int(green), int(blue))
    for name, level in re.findall(r"static let (\w+) = RGBA\.grey\((\d+|\.max)\)", source):
        value = CHANNEL_MAX if level == ".max" else int(level)
        colours[name] = (value, value, value)
    trail = re.search(r"static let qixTrail: \[RGBA\] = \[(.*?)\n    \]", source, re.DOTALL)
    if trail is None:
        raise SourceError("Palette.swift has no qixTrail")
    colours["qixTrail"] = [
        tuple(int(c) for c in rgb)
        for rgb in re.findall(r"RGBA\(red: (\d+), green: (\d+), blue: (\d+)\)", trail.group(1))
    ]
    return colours


def masks(source):
    """The marker's mask and the first spark frame from `Sprite.swift`, as lists of rows."""
    marker = re.search(r"static let markerMask: Mask = \[(.*?)\]", source, re.DOTALL)
    spark = re.search(r"static let sparkFrames: \[Mask\] = \[\s*\[(.*?)\]", source, re.DOTALL)
    if marker is None or spark is None:
        raise SourceError("Sprite.swift has no markerMask or sparkFrames")
    return re.findall(r'"([^"]*)"', marker.group(1)), re.findall(r'"([^"]*)"', spark.group(1))


def grey(colour):
    level = round(sum(weight * channel for weight, channel in zip(LUMA, colour)))
    return (level, level, level)


class Canvas:
    """A square of RGBA pixels, painted with axis-aligned rectangles."""

    def __init__(self, background):
        self.pixels = bytearray(bytes(background) * (SIZE * SIZE))

    def rect(self, left, top, right, bottom, colour):
        left, top = max(int(left), 0), max(int(top), 0)
        right, bottom = min(int(right), SIZE), min(int(bottom), SIZE)
        if left >= right:
            return
        row = bytes(colour) * (right - left)
        for y in range(top, bottom):
            start = (y * SIZE + left) * 4
            self.pixels[start : start + len(row)] = row

    def line(self, start, end, width, colour):
        """An axis-aligned line `width` wide centred on the lattice line from `start` to `end`, its
        ends squared off by half its width."""
        half = width // 2
        (x0, y0), (x1, y1) = sorted((start, end))
        self.rect(x0 - half, y0 - half, x1 + half, y1 + half, colour)

    def staircase(self, start, end, colour):
        """A line from `start` to `end` stamped with `QIX_PIXEL` squares snapped to their grid."""
        (x0, y0), (x1, y1) = start, end
        steps = max(abs(x1 - x0), abs(y1 - y0)) // QIX_PIXEL + 1
        for i in range(steps + 1):
            x = x0 + (x1 - x0) * i / steps
            y = y0 + (y1 - y0) * i / steps
            left = round(x / QIX_PIXEL) * QIX_PIXEL - QIX_PIXEL // 2
            top = round(y / QIX_PIXEL) * QIX_PIXEL - QIX_PIXEL // 2
            self.rect(left, top, left + QIX_PIXEL, top + QIX_PIXEL, colour)

    def sprite(self, mask, centre, pixel, colour_of):
        """`mask` centred on `centre`, one `pixel`-wide square per painted pixel."""
        left = centre[0] - len(mask[0]) * pixel // 2
        top = centre[1] - len(mask) * pixel // 2
        for row, line in enumerate(mask):
            for col, role in enumerate(line):
                colour = colour_of.get(role)
                if colour is not None:
                    x, y = left + col * pixel, top + row * pixel
                    self.rect(x, y, x + pixel, y + pixel, colour)


def render(colours, sprites, keeps_background, greys):
    """The icon's pixels as RGBA bytes, row by row from the top."""

    def paint(colour):
        return (grey(colour) if greys else colour) + (CHANNEL_MAX,)

    background = paint(colours["playfieldBackground"]) if keeps_background else TRANSPARENT
    canvas = Canvas(background)
    canvas.rect(BOARD_LEFT, FAST_CLAIM_TOP, FAST_CLAIM_RIGHT, BOARD_BOTTOM, paint(colours["fastFill"]))
    canvas.rect(SLOW_CLAIM_LEFT, BOARD_TOP, BOARD_RIGHT, SLOW_CLAIM_BOTTOM, paint(colours["slowFill"]))
    for (start, end), colour in zip(TRAIL, colours["qixTrail"]):
        canvas.staircase(start, end, paint(colour))
    border = paint(colours["border"])
    corners = (
        ((BOARD_LEFT, BOARD_TOP), (BOARD_RIGHT, BOARD_TOP)),
        ((BOARD_LEFT, BOARD_BOTTOM), (BOARD_RIGHT, BOARD_BOTTOM)),
        ((BOARD_LEFT, BOARD_TOP), (BOARD_LEFT, BOARD_BOTTOM)),
        ((BOARD_RIGHT, BOARD_TOP), (BOARD_RIGHT, BOARD_BOTTOM)),
        ((BOARD_LEFT, FAST_CLAIM_TOP), (FAST_CLAIM_RIGHT, FAST_CLAIM_TOP)),
        ((FAST_CLAIM_RIGHT, FAST_CLAIM_TOP), (FAST_CLAIM_RIGHT, BOARD_BOTTOM)),
        ((SLOW_CLAIM_LEFT, SLOW_CLAIM_BOTTOM), (BOARD_RIGHT, SLOW_CLAIM_BOTTOM)),
        ((SLOW_CLAIM_LEFT, BOARD_TOP), (SLOW_CLAIM_LEFT, SLOW_CLAIM_BOTTOM)),
    )
    for start, end in corners:
        canvas.line(start, end, BORDER_WIDTH, border)
    marker, spark = sprites
    spark_colours = {"B": paint(colours["sparx"]), "C": paint(colours["sparxCore"])}
    canvas.sprite(spark, SPARX_CENTRE, SPARX_PIXEL, spark_colours)
    marker_colours = {
        "O": paint(colours["markerOutline"]),
        "I": paint(colours["marker"]),
        "H": paint(colours["markerHighlight"]),
    }
    canvas.sprite(marker, MARKER_CENTRE, MARKER_PIXEL, marker_colours)
    return bytes(canvas.pixels)


def scanlines(rgba, keeps_alpha):
    """`rgba` as PNG scanlines: each row unfiltered, with or without its alpha bytes."""
    channels = 4 if keeps_alpha else 3
    rows = []
    for y in range(SIZE):
        row = rgba[y * SIZE * 4 : (y + 1) * SIZE * 4]
        if not keeps_alpha:
            row = bytes(b for i, b in enumerate(row) if i % 4 != 3)
        assert len(row) == SIZE * channels
        rows.append(NO_FILTER + row)
    return b"".join(rows)


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))


def header(keeps_alpha):
    colour_type = COLOUR_TYPE_RGBA if keeps_alpha else COLOUR_TYPE_RGB
    return struct.pack(">IIBBBBB", SIZE, SIZE, BIT_DEPTH, colour_type, 0, 0, 0)


def png(rgba, keeps_alpha):
    return (
        PNG_SIGNATURE
        + chunk(b"IHDR", header(keeps_alpha))
        + chunk(b"IDAT", zlib.compress(scanlines(rgba, keeps_alpha), COMPRESSION_LEVEL))
        + chunk(b"IEND", b"")
    )


def decoded(data):
    """The header and the decompressed scanlines of a PNG, or None when it is not one."""
    if not data.startswith(PNG_SIGNATURE):
        return None
    position, ihdr, idat = len(PNG_SIGNATURE), None, b""
    while position + 8 <= len(data):
        (length,) = struct.unpack(">I", data[position : position + 4])
        kind = data[position + 4 : position + 8]
        body = data[position + 8 : position + 8 + length]
        if kind == b"IHDR":
            ihdr = body
        elif kind == b"IDAT":
            idat += body
        position += length + 12
    try:
        return ihdr, zlib.decompress(idat)
    except zlib.error:
        return None


def variants():
    """Each variant's file name and PNG bytes."""
    colours = palette(PALETTE.read_text(encoding="utf-8"))
    sprites = masks(SPRITE.read_text(encoding="utf-8"))
    for name, keeps_background, greys in VARIANTS:
        rgba = render(colours, sprites, keeps_background, greys)
        yield f"{name}.png", png(rgba, keeps_alpha=not keeps_background)


def write(directory):
    for name, data in variants():
        (directory / name).write_bytes(data)
        print(f"wrote {directory / name}")


def check(directory):
    """The names of the PNGs in `directory` whose pixels differ from their render."""
    stale = []
    for name, data in variants():
        path = directory / name
        committed = decoded(path.read_bytes()) if path.exists() else None
        if committed != decoded(data):
            stale.append(name)
    return stale


def main(arguments):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="check the committed icons instead")
    parser.add_argument("--directory", type=pathlib.Path, default=ICON_SET, help=argparse.SUPPRESS)
    options = parser.parse_args(arguments)
    if not options.check:
        write(options.directory)
        return 0
    stale = check(options.directory)
    for name in stale:
        print(f"{options.directory / name} is not what render_icons.py draws; run it and commit", file=sys.stderr)
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
