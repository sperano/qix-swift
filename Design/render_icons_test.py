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
        stride = width * channels + 1
        pixels = []
        for y in range(height):
            row = raw[y * stride + 1 : (y + 1) * stride]
            for x in range(width):
                pixel = tuple(row[x * channels : (x + 1) * channels])
                pixels.append(pixel if channels == RGBA_CHANNELS else pixel + (icons.CHANNEL_MAX,))
        images[name] = (width, height, pixels)
    return images


IMAGES = rendered()


def pixel(name, x, y):
    width, _, pixels = IMAGES[name]
    return pixels[y * width + x]


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
        self.assertEqual(pixel("AppIcon.png", *INSIDE_FAST_CLAIM), self.colours["fastFill"] + (255,))

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
        ihdr, raw = icons.decoded((self.path / "AppIcon.png").read_bytes())
        recompressed = (
            icons.PNG_SIGNATURE
            + icons.chunk(b"IHDR", ihdr)
            + icons.chunk(b"IDAT", zlib.compress(raw, 1))
            + icons.chunk(b"IEND", b"")
        )
        (self.path / "AppIcon.png").write_bytes(recompressed)
        self.assertEqual(icons.check(self.path), [])

    def test_a_changed_pixel_fails(self):
        icons.write(self.path)
        data = dict(icons.variants())
        ihdr, raw = icons.decoded(data["AppIcon-Dark.png"])
        changed = bytearray(raw)
        changed[1] ^= 1
        tampered = (
            icons.PNG_SIGNATURE
            + icons.chunk(b"IHDR", ihdr)
            + icons.chunk(b"IDAT", zlib.compress(bytes(changed)))
            + icons.chunk(b"IEND", b"")
        )
        (self.path / "AppIcon-Dark.png").write_bytes(tampered)
        self.assertEqual(icons.check(self.path), ["AppIcon-Dark.png"])
        self.assertEqual(icons.main(["--check", "--directory", str(self.path)]), 1)

    def test_a_missing_or_unreadable_icon_fails(self):
        icons.write(self.path)
        (self.path / "AppIcon.png").unlink()
        (self.path / "AppIcon-Tinted.png").write_bytes(b"not a png")
        self.assertEqual(icons.check(self.path), ["AppIcon.png", "AppIcon-Tinted.png"])

    def test_the_committed_icons_are_the_render(self):
        self.assertEqual(icons.check(icons.ICON_SET), [])


if __name__ == "__main__":
    unittest.main()
