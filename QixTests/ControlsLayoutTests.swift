import CoreGraphics
import QixKit
import XCTest
@testable import Qix

/// The safe area of `PlayfieldLayoutTests`' phone, whose board is 320 × 240 at x 148 and y 32.
private let phone = CGRect(x: 0, y: 0, width: 616, height: 280)

/// Where the stick's thumb lands in the knob tests.
private let centre = CGPoint(x: 100, y: 100)

/// Tolerance for comparing opacities, which the settings hold as a `Float`: `Float(0.7)` is
/// 1.2e-8 off 0.7.
private let opacityEpsilon = 1e-6

/// Tolerance for comparing screen coordinates, in points.
private let pointEpsilon: CGFloat = 1e-9

/// The standard stick's layout, away from any board.
private let standard = ControlsLayout(in: .zero, beside: .zero)

/// The stick at its largest size, 1.5 times the standard one, and the controls at an opacity of
/// 0.4, away from any board.
private let largest = ControlsLayout(
    in: .zero, beside: .zero,
    settings: Settings(stickSize: StickSize(StickSize.range.upperBound), controlsOpacity: ControlsOpacity(0.4))
)

final class ControlsLayoutTests: XCTestCase {
    /// 16 points from the safe area's edges and 8 from the board: 148 - 8 - 16 = 124 points wide,
    /// 280 - 2 × 16 = 248 high.
    func testTheZonesFlankTheBoardClearOfTheEdges() {
        let layout = ControlsLayout(in: phone, beside: PlayfieldLayout(in: phone).field)

        XCTAssertEqual(layout.stick, CGRect(x: 16, y: 16, width: 124, height: 248))
        XCTAssertEqual(layout.slow, CGRect(x: 476, y: 16, width: 124, height: 248))
        XCTAssertEqual(layout.stickRest, CGPoint(x: 78, y: 140))
        XCTAssertEqual(layout.slowCentre, CGPoint(x: 538, y: 140))
    }

    /// The zones of `testTheZonesFlankTheBoardClearOfTheEdges`, swapped.
    func testLeftHandedTheStickIsRightOfTheBoardAndTheSlowButtonLeftOfIt() {
        let field = PlayfieldLayout(in: phone).field

        let layout = ControlsLayout(in: phone, beside: field, settings: Settings(leftHanded: true))

        XCTAssertEqual(layout.stick, CGRect(x: 476, y: 16, width: 124, height: 248))
        XCTAssertEqual(layout.slow, CGRect(x: 16, y: 16, width: 124, height: 248))
        XCTAssertEqual(layout.stickRest, CGPoint(x: 538, y: 140))
        XCTAssertEqual(layout.slowCentre, CGPoint(x: 78, y: 140))
    }

    func testTheStandardStickAndOpacityAreTheDefaultSettings() {
        XCTAssertEqual(standard.baseRadius, ControlsLayout.standardBaseRadius)
        XCTAssertEqual(standard.knobRadius, ControlsLayout.standardKnobRadius)
        XCTAssertEqual(standard.touchedOpacity, 0.7, accuracy: opacityEpsilon)
        XCTAssertEqual(standard.idleOpacity, 0.245, accuracy: opacityEpsilon)
    }

    /// 1.5 times 44 and 22 points; idle, 0.35 of the touched opacity.
    func testTheStickSizeScalesTheStickAndTheOpacitySetsBothControls() {
        XCTAssertEqual(largest.baseRadius, 66)
        XCTAssertEqual(largest.knobRadius, 33)
        XCTAssertEqual(largest.touchedOpacity, 0.4, accuracy: opacityEpsilon)
        XCTAssertEqual(largest.idleOpacity, 0.14, accuracy: opacityEpsilon)
    }

    /// Following the finger, the board is the steering's zone, the stick has none and the Slow
    /// button keeps its own, on either hand.
    func testFollowingTheFingerTheBoardTakesTheSticksPlace() {
        let field = PlayfieldLayout(in: phone).field
        for leftHanded in [false, true] {
            let settings = Settings(controlScheme: .followTheFinger, leftHanded: leftHanded)

            let layout = ControlsLayout(in: phone, beside: field, settings: settings)

            XCTAssertEqual(layout.board, field)
            XCTAssertTrue(layout.stick.isEmpty)
            XCTAssertEqual(
                layout.slow,
                ControlsLayout(in: phone, beside: field, settings: Settings(leftHanded: leftHanded)).slow
            )
        }
    }

    func testWithTheStickTheBoardIsNoZone() {
        let layout = ControlsLayout(in: phone, beside: PlayfieldLayout(in: phone).field)

        XCTAssertTrue(layout.board.isEmpty)
    }

    func testTheStickSizeLeavesTheZonesAlone() {
        let field = PlayfieldLayout(in: phone).field
        let settings = Settings(stickSize: StickSize(StickSize.range.upperBound))

        let layout = ControlsLayout(in: phone, beside: field, settings: settings)

        XCTAssertEqual(layout.stick, ControlsLayout(in: phone, beside: field).stick)
        XCTAssertEqual(layout.slow, ControlsLayout(in: phone, beside: field).slow)
    }

    func testTheZonesFollowAnOffsetSafeArea() {
        let available = phone.offsetBy(dx: 50, dy: 20)

        let layout = ControlsLayout(in: available, beside: PlayfieldLayout(in: available).field)

        XCTAssertEqual(layout.stick, CGRect(x: 66, y: 36, width: 124, height: 248))
        XCTAssertEqual(layout.slow, CGRect(x: 526, y: 36, width: 124, height: 248))
    }

    func testABoardLeavingNoRoomGivesEmptyZones() {
        let available = CGRect(x: 0, y: 0, width: 100, height: 100)

        let layout = ControlsLayout(in: available, beside: CGRect(x: 20, y: 0, width: 60, height: 100))

        XCTAssertTrue(layout.stick.isEmpty)
        XCTAssertTrue(layout.slow.isEmpty)
    }

    func testASafeAreaShorterThanItsClearancesGivesEmptyZones() {
        let available = CGRect(x: 0, y: 0, width: 616, height: ControlsLayout.edgeClearance)

        let layout = ControlsLayout(in: available, beside: CGRect(x: 300, y: 0, width: 16, height: 16))

        XCTAssertEqual(layout.stick.height, 0)
        XCTAssertEqual(layout.slow.height, 0)
    }

    func testTheKnobIsUnderAThumbOnTheBase() {
        let thumb = CGPoint(x: 110, y: 120)

        XCTAssertEqual(standard.knob(centre: centre, thumb: thumb), thumb)
    }

    func testTheKnobIsUnderAThumbOnTheRim() {
        let thumb = CGPoint(x: centre.x, y: centre.y - ControlsLayout.standardBaseRadius)

        XCTAssertEqual(standard.knob(centre: centre, thumb: thumb), thumb)
    }

    /// A thumb 100 points away along a 3-4-5 triangle: the knob is 44 points away along it.
    func testTheKnobStaysOnTheRimTowardsAThumbBeyondIt() {
        let knob = standard.knob(centre: centre, thumb: CGPoint(x: 160, y: 180))

        XCTAssertEqual(knob.x, 100 + 0.6 * 44, accuracy: pointEpsilon)
        XCTAssertEqual(knob.y, 100 + 0.8 * 44, accuracy: pointEpsilon)
    }

    /// The thumb of `testTheKnobStaysOnTheRimTowardsAThumbBeyondIt`, 50 points away: inside the
    /// largest stick's 66-point base, beyond the standard one's 44.
    func testALargerStickTakesTheKnobFurther() {
        let thumb = CGPoint(x: 130, y: 140)

        XCTAssertEqual(largest.knob(centre: centre, thumb: thumb), thumb)
        XCTAssertNotEqual(standard.knob(centre: centre, thumb: thumb), thumb)
    }
}
