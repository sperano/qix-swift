import QixKit
import UIKit
import XCTest

/// The icon set in the asset catalog, rendered by `Design/render_icons.py` (whose own tests check
/// its pixels on Linux): a light icon on the playfield's background, and dark and tinted ones that
/// leave the background to the system. Read from the repository, since the catalog is compiled
/// away.
final class AppIconTests: XCTestCase {
    private static let iconSize = 1_024
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
    private static let iconSet = repository
        .appendingPathComponent("Qix/Resources/Assets.xcassets/AppIcon.appiconset")
    /// Pixels are sampled on this grid: every pixel of a 1024 square is slow for nothing.
    private static let sampleStride = 16

    private struct Appearance: Decodable {
        let appearance: String
        let value: String
    }

    private struct Entry: Decodable {
        let filename: String
        let idiom: String
        let platform: String
        let size: String
        let appearances: [Appearance]?

        var luminosity: String? { appearances?.first { $0.appearance == "luminosity" }?.value }
    }

    private struct IconSet: Decodable {
        let images: [Entry]
    }

    private func entries() throws -> [Entry] {
        let data = try Data(contentsOf: Self.iconSet.appendingPathComponent("Contents.json"))
        return try JSONDecoder().decode(IconSet.self, from: data).images
    }

    private func image(_ entry: Entry) throws -> CGImage {
        let path = Self.iconSet.appendingPathComponent(entry.filename).path
        return try XCTUnwrap(UIImage(contentsOfFile: path)?.cgImage, "\(entry.filename) is missing")
    }

    func testTheSetHasALightADarkAndATintedIcon() throws {
        let entries = try entries()
        XCTAssertEqual(entries.map(\.luminosity), [nil, "dark", "tinted"])
        for entry in entries {
            XCTAssertEqual(entry.idiom, "universal", entry.filename)
            XCTAssertEqual(entry.platform, "ios", entry.filename)
            XCTAssertEqual(entry.size, "\(Self.iconSize)x\(Self.iconSize)", entry.filename)
        }
    }

    func testEveryIconIsFullSize() throws {
        for entry in try entries() {
            let image = try image(entry)
            XCTAssertEqual(image.width, Self.iconSize, entry.filename)
            XCTAssertEqual(image.height, Self.iconSize, entry.filename)
        }
    }

    func testTheLightIconIsOpaqueAndSitsOnThePlayfield() throws {
        let entry = try XCTUnwrap(entries().first { $0.luminosity == nil })
        let pixels = try Pixels(image(entry))
        XCTAssertTrue(pixels.sampled(stride: Self.sampleStride).allSatisfy { $0.alpha == UInt8.max })
        let background = Palette.playfieldBackground
        XCTAssertEqual(pixels.corner.channels, [background.red, background.green, background.blue])
    }

    /// App Store Connect rejects an App Store icon with an alpha channel, even a fully opaque one.
    func testTheLightIconHasNoAlphaChannel() throws {
        let entry = try XCTUnwrap(entries().first { $0.luminosity == nil })
        let opaque: Set<CGImageAlphaInfo> = [.none, .noneSkipFirst, .noneSkipLast]
        XCTAssertTrue(try opaque.contains(image(entry).alphaInfo))
    }

    func testTheDarkAndTintedIconsLeaveTheBackgroundToTheSystem() throws {
        for entry in try entries() where entry.luminosity != nil {
            XCTAssertEqual(try Pixels(image(entry)).corner.alpha, 0, entry.filename)
        }
    }

    func testTheTintedIconIsGrey() throws {
        let entry = try XCTUnwrap(entries().first { $0.luminosity == "tinted" })
        let pixels = try Pixels(image(entry))
        XCTAssertTrue(pixels.sampled(stride: Self.sampleStride).allSatisfy { $0.alpha == 0 || $0.isGrey })
    }
}

/// The bytes of an image as 8-bit RGBA, for sampling.
private struct Pixels {
    struct Pixel {
        let channels: [UInt8]
        let alpha: UInt8
        var isGrey: Bool { channels[0] == channels[1] && channels[1] == channels[2] }
    }

    static let colourChannels = 3
    private static let bytesPerPixel = 4
    private static let bitsPerComponent = 8

    private let data: [UInt8]
    private let width: Int
    private let height: Int

    init(_ image: CGImage) throws {
        let (width, height) = (image.width, image.height)
        var data = [UInt8](repeating: 0, count: width * height * Self.bytesPerPixel)
        // The context writes through its pointer when it draws, so it must not outlive the buffer.
        try data.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: Self.bitsPerComponent,
                bytesPerRow: width * Self.bytesPerPixel, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        self.width = width
        self.height = height
        self.data = data
    }

    var corner: Pixel { pixel(x: 0, y: 0) }

    func pixel(x: Int, y: Int) -> Pixel {
        let offset = (y * width + x) * Self.bytesPerPixel
        let colour = Array(data[offset ..< offset + Self.colourChannels])
        return Pixel(channels: colour, alpha: data[offset + Self.colourChannels])
    }

    func sampled(stride: Int) -> [Pixel] {
        Swift.stride(from: 0, to: height, by: stride).flatMap { y in
            Swift.stride(from: 0, to: width, by: stride).map { pixel(x: $0, y: y) }
        }
    }
}
