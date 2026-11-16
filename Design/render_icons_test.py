#!/usr/bin/env python3
"""Tests of render_icons.py: what it reads from the Swift sources, the three variants it draws, the
PNGs it writes and its check of the committed icons.

    python3 Design/render_icons_test.py
"""

import importlib.util
import pathlib
import struct
import tempfile
import unittest
import zlib

SCRIPT = pathlib.Path(__file__).resolve().parent / "render_icons.py"
SPEC = importlib.util.spec_from_file_location("render_icons", SCRIPT)
icons = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(icons)

RGB_CHANNELS = 3
RGBA_CHANNELS = 4
# Bytes before IHDR's width: the signature, then the chunk's length and type.
IHDR_OFFSET = len(icons.PNG_SIGNATURE) + 8
# IHDR's colour type, after the width, height and bit depth.
COLOUR_TYPE_OFFSET = IHDR_OFFSET + 9
# The pixel sampled inside the fast claim, away from its border and the marker.
INSIDE_FAST_CLAIM = (200, 800)
# A filter type past the five the PNG specification defines.
UNKNOWN_FILTER = 5
# A bit depth the check does not read.
SIXTEEN_BITS = 16
ADAM7_INTERLACE = 1
COLOUR_TYPE_PALETTE = 3
# A zlib level other than the renderer's.
FAST_COMPRESSION = 1

PALETTE_SOURCE = """
    public static let playfieldBackground = RGBA(red: 6, green: 6, blue: 20)
    public static let border = RGBA.grey(.max)
    public static let hudLabel = RGBA.grey(150)
    public static let qixTrail: [RGBA] = [
        RGBA(red: 255, green: 70, blue: 70),
        RGBA(red: 80, green: 120, blue: 255),
    ]
"""

SPRITE_SOURCE = """
    public static let markerMask: Mask = [
        ".O.",
        "OIO",
        ".O.",
    ]
    public static let sparkFrames: [Mask] = [
        [
            "B.B",
            ".C.",
            "B.B",
        ],
        [
            ".B.",
        ],
    ]
"""


def rendered():
    """Each variant's name and the RGBA pixels its PNG decodes to."""
    images = {}
    for name, data in icons.variants():
        ihdr, raw = icons.decoded(data)
        width, height, _, colour_type = struct.unpack(">IIBB", ihdr[:10])
        channels = RGBA_CHANNELS if colour_type == icons.COLOUR_TYPE_RGBA else RGB_CHANNELS
        pixels = []
        for i in range(0, width * height * channels, channels):
            pixel = tuple(raw[i : i + channels])
            pixels.append(pixel if channels == RGBA_CHANNELS else pixel + (icons.CHANNEL_MAX,))
        images[name] = (width, height, pixels)
    return images


IMAGES = rendered()


def pixel(name, x, y):
    width, _, pixels = IMAGES[name]
    return pixels[y * width + x]


def paeth(a, b, c):
    """The Paeth predictor as the PNG specification writes it: a left, b up, c up and left."""
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def filtered(kind, row, previous, channels):
    """`row` filtered with `kind` against the row above, its filter type byte first; a kind the
    specification does not define is written unfiltered."""
    out = bytearray([kind])
    for i, byte in enumerate(row):
        a = row[i - channels] if i >= channels else 0
        b = previous[i]
        c = previous[i - channels] if i >= channels else 0
        predictors = {
            icons.FILTER_NONE: 0,
            icons.FILTER_SUB: a,
            icons.FILTER_UP: b,
            icons.FILTER_AVERAGE: (a + b) // 2,
            icons.FILTER_PAETH: paeth(a, b, c),
        }
        out.append((byte - predictors.get(kind, 0)) % icons.BYTE_VALUES)
    return bytes(out)


def with_idat(ihdr, idat):
    """A PNG of the header `ihdr` and the compressed data `idat`."""
    return icons.PNG_SIGNATURE + icons.chunk(b"IHDR", ihdr) + icons.chunk(b"IDAT", idat) + icons.chunk(b"IEND", b"")


def encoded(ihdr, pixels, filters, level=FAST_COMPRESSION):
    """A PNG of `pixels` under `ihdr`, the rows filtered in turn with the types of `filters`."""
    width, height, _, colour_type = struct.unpack(">IIBB", ihdr[:10])
    channels = RGBA_CHANNELS if colour_type == icons.COLOUR_TYPE_RGBA else RGB_CHANNELS
    stride = width * channels
    rows, previous = [], bytes(stride)
    for y in range(height):
        row = pixels[y * stride : (y + 1) * stride]
        rows.append(filtered(filters[y % len(filters)], row, previous, channels))
        previous = row
    return with_idat(ihdr, zlib.compress(b"".join(rows), level))


class SourceTests(unittest.TestCase):
    def test_the_palette_reads_rgb_colours_greys_and_the_trail(self):
        colours = icons.palette(PALETTE_SOURCE)
        self.assertEqual(colours["playfieldBackground"], (6, 6, 20))
        self.assertEqual(colours["border"], (255, 255, 255))
        self.assertEqual(colours["hudLabel"], (150, 150, 150))
        self.assertEqual(colours["qixTrail"], [(255, 70, 70), (80, 120, 255)])

    def test_a_palette_without_a_trail_is_refused(self):
        with self.assertRaises(icons.SourceError):
            icons.palette("public static let border = RGBA.grey(.max)")

    def test_the_masks_are_the_marker_and_the_first_spark_frame(self):
        marker, spark = icons.masks(SPRITE_SOURCE)
        self.assertEqual(marker, [".O.", "OIO", ".O."])
        self.assertEqual(spark, ["B.B", ".C.", "B.B"])

    def test_sources_without_the_masks_are_refused(self):
        with self.assertRaises(icons.SourceError):
            icons.masks("public static let markerMask: Mask = []")

    def test_the_game_sources_hold_every_colour_the_icon_paints(self):
        colours = icons.palette(icons.PALETTE.read_text(encoding="utf-8"))
        names = ("playfieldBackground", "border", "fastFill", "slowFill", "marker", "markerOutline")
        names += ("markerHighlight", "sparx", "sparxCore")
        for name in names:
            self.assertIn(name, colours)
        self.assertEqual(len(colours["qixTrail"]), len(icons.TRAIL))

    def test_a_grey_keeps_the_luminance_of_its_colour(self):
        self.assertEqual(icons.grey((255, 255, 255)), (255, 255, 255))
        self.assertEqual(icons.grey((0, 0, 0)), (0, 0, 0))
        # 0.7152 of 255: green is most of the luminance.
        self.assertEqual(icons.grey((0, 255, 0)), (182, 182, 182))


class VariantTests(unittest.TestCase):
    def setUp(self):
        self.colours = icons.palette(icons.PALETTE.read_text(encoding="utf-8"))

    def test_there_is_a_light_a_dark_and_a_tinted_icon_of_full_size(self):
        self.assertEqual(sorted(IMAGES), ["AppIcon-Dark.png", "AppIcon-Tinted.png", "AppIcon.png"])
        for width, height, _ in IMAGES.values():
            self.assertEqual((width, height), (icons.SIZE, icons.SIZE))

    def test_the_light_icon_is_written_without_an_alpha_channel(self):
        data = dict(icons.variants())
        self.assertEqual(data["AppIcon.png"][COLOUR_TYPE_OFFSET], icons.COLOUR_TYPE_RGB)
        self.assertEqual(data["AppIcon-Dark.png"][COLOUR_TYPE_OFFSET], icons.COLOUR_TYPE_RGBA)
        self.assertEqual(data["AppIcon-Tinted.png"][COLOUR_TYPE_OFFSET], icons.COLOUR_TYPE_RGBA)

    def test_the_light_icon_sits_on_the_playfield(self):
        self.assertEqual(pixel("AppIcon.png", 0, 0), self.colours["playfieldBackground"] + (255,))

    def test_the_dark_and_tinted_icons_leave_the_background_to_the_system(self):
        for name in ("AppIcon-Dark.png", "AppIcon-Tinted.png"):
            self.assertEqual(pixel(name, 0, 0), icons.TRANSPARENT, name)

    def test_the_dark_icon_keeps_the_colours_of_the_light_one(self):
        self.assertEqual(pixel("AppIcon-Dark.png", *INSIDE_FAST_CLAIM), self.colours["fastFill"] + (255,))
        background = self.colours["playfieldBackground"] + (255,)
        _, _, light = IMAGES["AppIcon.png"]
        _, _, dark = IMAGES["AppIcon-Dark.png"]
        expected = [icons.TRANSPARENT if p == background else p for p in light]
        self.assertEqual(sum(p != icons.TRANSPARENT for p in dark), sum(p != background for p in light))
        self.assertTrue(dark == expected)

    def test_the_tinted_icon_is_grey(self):
        _, _, pixels = IMAGES["AppIcon-Tinted.png"]
        self.assertTrue(all(p[3] == 0 or p[0] == p[1] == p[2] for p in pixels))
        self.assertEqual(pixel("AppIcon-Tinted.png", *INSIDE_FAST_CLAIM)[:3], icons.grey(self.colours["fastFill"]))

    def test_the_marker_sits_on_the_corner_of_the_fast_claim(self):
        self.assertEqual(pixel("AppIcon.png", *icons.MARKER_CENTRE), self.colours["marker"] + (255,))


class CheckTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = pathlib.Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)

    def test_freshly_written_icons_pass(self):
        icons.write(self.path)
        self.assertEqual(icons.check(self.path), [])
        self.assertEqual(icons.main(["--check", "--directory", str(self.path)]), 0)

    def test_the_same_pixels_compressed_otherwise_pass(self):
        icons.write(self.path)
        ihdr, pixels = icons.decoded((self.path / "AppIcon.png").read_bytes())
        (self.path / "AppIcon.png").write_bytes(encoded(ihdr, pixels, [icons.FILTER_NONE]))
        self.assertEqual(icons.check(self.path), [])

    def test_the_same_pixels_filtered_otherwise_pass(self):
        icons.write(self.path)
        kinds = [icons.FILTER_NONE, icons.FILTER_SUB, icons.FILTER_UP, icons.FILTER_AVERAGE, icons.FILTER_PAETH]
        ihdr, pixels = icons.decoded((self.path / "AppIcon-Dark.png").read_bytes())
        reencoded = encoded(ihdr, pixels, kinds)
        self.assertTrue(icons.decoded(reencoded) == (ihdr, pixels), "the filters were not undone")
        (self.path / "AppIcon-Dark.png").write_bytes(reencoded)
        self.assertEqual(icons.check(self.path), [])

    def test_the_same_pixels_split_across_idat_chunks_pass(self):
        icons.write(self.path)
        single = (self.path / "AppIcon.png").read_bytes()
        ihdr = next(body for kind, body in icons.chunks(single) if kind == b"IHDR")
        stream = b"".join(body for kind, body in icons.chunks(single) if kind == b"IDAT")
        half = len(stream) // 2
        split = (
            icons.PNG_SIGNATURE
            + icons.chunk(b"IHDR", ihdr)
            + icons.chunk(b"IDAT", stream[:half])
            + icons.chunk(b"IDAT", stream[half:])
            + icons.chunk(b"IEND", b"")
        )
        self.assertEqual(icons.decoded(split), icons.decoded(single))
        (self.path / "AppIcon.png").write_bytes(split)
        self.assertEqual(icons.check(self.path), [])

    def test_a_changed_pixel_fails(self):
        icons.write(self.path)
        ihdr, pixels = icons.decoded(dict(icons.variants())["AppIcon-Dark.png"])
        changed = bytearray(pixels)
        changed[0] ^= 1
        (self.path / "AppIcon-Dark.png").write_bytes(encoded(ihdr, bytes(changed), [icons.FILTER_NONE]))
        self.assertEqual(icons.check(self.path), ["AppIcon-Dark.png"])
        self.assertEqual(icons.main(["--check", "--directory", str(self.path)]), 1)

    def test_a_missing_or_unreadable_icon_fails(self):
        icons.write(self.path)
        (self.path / "AppIcon.png").unlink()
        (self.path / "AppIcon-Tinted.png").write_bytes(b"not a png")
        self.assertEqual(icons.check(self.path), ["AppIcon.png", "AppIcon-Tinted.png"])

    def test_a_png_the_check_cannot_read_fails(self):
        icons.write(self.path)
        ihdr, pixels = icons.decoded((self.path / "AppIcon-Tinted.png").read_bytes())
        width, height, _, colour_type = struct.unpack(">IIBB", ihdr[:10])

        # The depth and interlace cases hold rows of the 8-bit length, so only their header can
        # reject them.
        def header(depth=icons.BIT_DEPTH, colour=colour_type, interlace=icons.NO_INTERLACE):
            return struct.pack(icons.IHDR_FORMAT, width, height, depth, colour, 0, 0, interlace)

        unreadable = {
            "a damaged IDAT": with_idat(ihdr, b"garbage"),
            "no IHDR": icons.PNG_SIGNATURE + icons.chunk(b"IEND", b""),
            "a short IHDR": icons.PNG_SIGNATURE + icons.chunk(b"IHDR", ihdr[:-1]),
            "sixteen bits a channel": encoded(header(depth=SIXTEEN_BITS), pixels, [icons.FILTER_NONE]),
            "a palette": with_idat(header(colour=COLOUR_TYPE_PALETTE), zlib.compress(b"")),
            "Adam7 interlacing": encoded(header(interlace=ADAM7_INTERLACE), pixels, [icons.FILTER_NONE]),
            "rows missing": with_idat(ihdr, zlib.compress(icons.NO_FILTER)),
            "an unknown filter type": encoded(ihdr, pixels, [UNKNOWN_FILTER]),
        }
        for case, data in unreadable.items():
            with self.subTest(case):
                self.assertIsNone(icons.decoded(data))
                (self.path / "AppIcon-Tinted.png").write_bytes(data)
                self.assertEqual(icons.check(self.path), ["AppIcon-Tinted.png"])

    def test_the_committed_icons_are_the_render(self):
        self.assertEqual(icons.check(icons.ICON_SET), [])


if __name__ == "__main__":
    unittest.main()
