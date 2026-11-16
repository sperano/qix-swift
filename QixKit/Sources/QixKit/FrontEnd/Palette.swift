// The colours the game is painted with: qix-rs's `crates/qix/src/palette.rs`, as 8-bit RGBA so the
// claimed cells' image is built without a graphics framework. The app turns them into SwiftUI
// colours.

/// An sRGB colour with 8-bit channels; `alpha` 255 is opaque.
public struct RGBA: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    /// Fully transparent black: a free cell of the claimed cells' image.
    public static let transparent = Self(red: 0, green: 0, blue: 0, alpha: 0)

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = .max) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Black at `alpha`: egui's `Color32::from_black_alpha`.
    public static func black(alpha: UInt8) -> Self {
        Self(red: 0, green: 0, blue: 0, alpha: alpha)
    }

    /// A grey of `level` on every channel: egui's `Color32::from_gray`.
    public static func grey(_ level: UInt8) -> Self {
        Self(red: level, green: level, blue: level)
    }

    /// This colour moved `share` of the way to `other`, each channel on its 8-bit value and
    /// rounded: egui's `Color32::lerp_to_gamma`. Past either end, the channels saturate.
    public func lerpToGamma(_ other: Self, _ share: Float) -> Self {
        let channel = { (from: UInt8, to: UInt8) -> UInt8 in
            let value = (1 - share) * Float(from) + share * Float(to)
            return UInt8(min(max(value + Self.roundingOffset, 0), Float(UInt8.max)))
        }
        return Self(
            red: channel(red, other.red), green: channel(green, other.green), blue: channel(blue, other.blue),
            alpha: channel(alpha, other.alpha)
        )
    }

    /// Added before truncating to round to the nearest value, as egui's `fast_round` does.
    private static let roundingOffset: Float = 0.5
}

public enum Palette {
    /// The free area of the playfield.
    public static let playfieldBackground = RGBA(red: 6, green: 6, blue: 20)

    /// The border the marker and the Sparx travel.
    public static let border = RGBA.grey(.max)

    /// Cells claimed by a fast draw.
    public static let fastFill = RGBA(red: 20, green: 55, blue: 165)

    /// Cells claimed by a slow draw.
    public static let slowFill = RGBA(red: 145, green: 40, blue: 30)

    /// Segments of the stix drawn fast.
    public static let fastStix = RGBA(red: 90, green: 160, blue: 255)

    /// Segments of the stix drawn slow.
    public static let slowStix = RGBA(red: 255, green: 115, blue: 75)

    /// The bright colour the stix being drawn flickers to, from the colour of its kind.
    public static let stixFlicker = RGBA(red: 255, green: 250, blue: 225)

    /// The bright colour newly claimed cells start from, before they settle to the fill of their
    /// kind.
    public static let claimFlash = RGBA(red: 235, green: 245, blue: 255)

    /// The inside of the player's marker.
    public static let marker = RGBA(red: 255, green: 220, blue: 60)

    /// The outline of the marker's sprite: dark enough to stand out from the white border and the
    /// claimed cells alike.
    public static let markerOutline = RGBA(red: 140, green: 70, blue: 0)

    /// The highlight on the marker's sprite.
    public static let markerHighlight = RGBA(red: 255, green: 255, blue: 200)

    /// The colours the Qix's trail cycles through, one per segment.
    public static let qixTrail: [RGBA] = [
        RGBA(red: 255, green: 70, blue: 70),
        RGBA(red: 255, green: 160, blue: 40),
        RGBA(red: 240, green: 240, blue: 60),
        RGBA(red: 80, green: 230, blue: 80),
        RGBA(red: 60, green: 230, blue: 230),
        RGBA(red: 80, green: 120, blue: 255),
        RGBA(red: 170, green: 90, blue: 255),
        RGBA(red: 255, green: 80, blue: 210),
    ]

    /// A Sparx walking the border.
    public static let sparx = RGBA(red: 255, green: 90, blue: 90)

    /// A Super Sparx.
    public static let superSparx = RGBA(red: 90, green: 255, blue: 140)

    /// The bright heart of a Sparx's sprite.
    public static let sparxCore = RGBA(red: 255, green: 235, blue: 210)

    /// The bright heart of a Super Sparx's sprite.
    public static let superSparxCore = RGBA(red: 225, green: 255, blue: 235)

    /// The fuse's burning point.
    public static let fuse = RGBA(red: 255, green: 255, blue: 230)

    /// The glow around the fuse, before it is made translucent.
    public static let fuseGlow = RGBA(red: 255, green: 170, blue: 40)

    /// Over the playfield behind a screen, translucent so it stays visible.
    public static let screenDim = RGBA.black(alpha: 110)

    /// Behind a screen's text.
    public static let screenBackground = RGBA.black(alpha: 200)

    /// A screen's heading.
    public static let screenHeading = marker

    /// The lines under a screen's heading.
    public static let screenText = RGBA.grey(.max)

    /// The names of the HUD's fields.
    public static let hudLabel = RGBA.grey(150)

    /// The values of the HUD's fields.
    public static let hudValue = RGBA.grey(.max)

    /// The lives left, in the HUD: the marker they stand for.
    public static let hudLife = marker

    /// The outline of the Sparx meter's bar.
    public static let hudMeterFrame = RGBA.grey(150)

    /// The fill of cells claimed with `kind`.
    public static func fill(_ kind: DrawKind) -> RGBA {
        switch kind {
        case .fast: fastFill
        case .slow: slowFill
        }
    }

    /// The colour of stix segments drawn with `kind`.
    public static func stix(_ kind: DrawKind) -> RGBA {
        switch kind {
        case .fast: fastStix
        case .slow: slowStix
        }
    }

    /// The fill of the Sparx meter's bar counting down to `expiry`: the colour of the Sparx it
    /// releases, then of the Super Sparx they turn into.
    public static func meter(_ expiry: MeterExpiry) -> RGBA {
        switch expiry {
        case .release: sparx
        case .super: superSparx
        }
    }

    /// The colour of a Sparx of `kind`.
    public static func sparx(_ kind: SparxKind) -> RGBA {
        switch kind {
        case .normal: sparx
        case .super: superSparx
        }
    }

    /// The colour of the heart of a Sparx of `kind`.
    public static func sparxCore(_ kind: SparxKind) -> RGBA {
        switch kind {
        case .normal: sparxCore
        case .super: superSparxCore
        }
    }
}
