import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import SwoopCore

final class GeometryTests: XCTestCase {
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 875) // below a 25pt menu bar

    func testHalvesWithoutPadding() {
        let g = ActionGeometry(padding: 0)
        let w = CGRect(x: 100, y: 100, width: 400, height: 300)
        XCTAssertEqual(g.frame(for: .leftHalf, window: w, visible: screen), CGRect(x: 0, y: 25, width: 720, height: 875))
        XCTAssertEqual(g.frame(for: .rightHalf, window: w, visible: screen), CGRect(x: 720, y: 25, width: 720, height: 875))
        XCTAssertEqual(g.frame(for: .maximize, window: w, visible: screen), screen)
    }

    func testPaddingIsEqualAtEdgesAndBetweenWindows() {
        let g = ActionGeometry(padding: 10)
        let w = CGRect(x: 100, y: 100, width: 400, height: 300)
        let left = g.frame(for: .leftHalf, window: w, visible: screen)!
        let right = g.frame(for: .rightHalf, window: w, visible: screen)!
        XCTAssertEqual(left.minX, 10)
        XCTAssertEqual(right.minX - left.maxX, 10)
        XCTAssertEqual(screen.maxX - right.maxX, 10)
        XCTAssertEqual(left.minY, 35)
    }

    func testThirdsCoverTheScreen() {
        let g = ActionGeometry(padding: 0)
        let w = CGRect(x: 0, y: 0, width: 10, height: 10)
        let a = g.frame(for: .leftThird, window: w, visible: screen)!
        let b = g.frame(for: .horizontalCenterThird, window: w, visible: screen)!
        let c = g.frame(for: .rightThird, window: w, visible: screen)!
        XCTAssertEqual(a.maxX, b.minX)
        XCTAssertEqual(b.maxX, c.minX)
        XCTAssertEqual(c.maxX, screen.maxX)
    }

    func testCenterKeepsSize() {
        let g = ActionGeometry(padding: 0)
        let w = CGRect(x: 0, y: 25, width: 400, height: 300)
        let r = g.frame(for: .center, window: w, visible: screen)!
        XCTAssertEqual(r.size, w.size)
        XCTAssertEqual(r.midX, screen.midX, accuracy: 1)
        XCTAssertEqual(r.midY, screen.midY, accuracy: 1)
    }

    func testSmallerRespectsMinimum() {
        let g = ActionGeometry(padding: 0, step: 500)
        let w = CGRect(x: 200, y: 200, width: 400, height: 300)
        let r = g.frame(for: .smaller, window: w, visible: screen)!
        XCTAssertEqual(r.width, 240)
        XCTAssertEqual(r.height, 160)
    }

    func testMoveStaysOnScreen() {
        let g = ActionGeometry(padding: 0, step: 100)
        let w = CGRect(x: 20, y: 100, width: 400, height: 300)
        let r = g.frame(for: .moveLeft, window: w, visible: screen)!
        XCTAssertEqual(r.minX, 0)
    }

    func testTransferKeepsRelativeLayout() {
        let g = ActionGeometry(padding: 0)
        let a = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let b = CGRect(x: 1000, y: 0, width: 2000, height: 1000)
        let leftHalf = CGRect(x: 0, y: 0, width: 500, height: 800)
        XCTAssertEqual(g.transfer(leftHalf, from: a, to: b), CGRect(x: 1000, y: 0, width: 1000, height: 1000))
    }
}

final class RadialTests: XCTestCase {
    func testDirections() {
        XCTAssertEqual(RadialDirection.from(dx: 2, dy: 1, deadZone: 10), .center)
        XCTAssertEqual(RadialDirection.from(dx: 50, dy: 0, deadZone: 10), .right)
        XCTAssertEqual(RadialDirection.from(dx: 0, dy: 50, deadZone: 10), .top)
        XCTAssertEqual(RadialDirection.from(dx: -50, dy: 0, deadZone: 10), .left)
        XCTAssertEqual(RadialDirection.from(dx: 0, dy: -50, deadZone: 10), .bottom)
        XCTAssertEqual(RadialDirection.from(dx: 40, dy: 40, deadZone: 10), .topRight)
        XCTAssertEqual(RadialDirection.from(dx: -40, dy: -40, deadZone: 10), .bottomLeft)
        XCTAssertEqual(RadialDirection.from(dx: 50, dy: -5, deadZone: 10), .right) // just below the axis
    }
}

final class CycleTests: XCTestCase {
    func testCycleContinuesOnlyWhenUntouched() {
        var t = CycleTracker()
        let f = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(t.startIndex(key: "k", windowID: 1, currentFrame: f, count: 3), 0)
        t.record(key: "k", windowID: 1, index: 0, frame: f)
        XCTAssertEqual(t.startIndex(key: "k", windowID: 1, currentFrame: f, count: 3), 1)
        XCTAssertEqual(t.startIndex(key: "other", windowID: 1, currentFrame: f, count: 3), 0)
        XCTAssertEqual(t.startIndex(key: "k", windowID: 2, currentFrame: f, count: 3), 0)
        XCTAssertEqual(t.startIndex(key: "k", windowID: 1, currentFrame: f.offsetBy(dx: 50, dy: 0), count: 3), 0)
        t.record(key: "k", windowID: 1, index: 2, frame: f)
        XCTAssertEqual(t.startIndex(key: "k", windowID: 1, currentFrame: f, count: 3), 0) // wraps
    }

    func testHistory() {
        var h = FrameHistory()
        let a = CGRect(x: 0, y: 0, width: 1, height: 1)
        let b = CGRect(x: 5, y: 5, width: 1, height: 1)
        h.record(windowID: 7, frame: a)
        h.record(windowID: 7, frame: b)
        XCTAssertEqual(h.initialFrame(windowID: 7), a)
        XCTAssertEqual(h.popUndo(windowID: 7), b)
        XCTAssertEqual(h.popUndo(windowID: 7), a)
        XCTAssertNil(h.popUndo(windowID: 7))
    }
}

final class TriggerTests: XCTestCase {
    let rightOptionDown: UInt64 = 0x8_0000 | 0x40

    func testTriggerDetection() {
        XCTAssertTrue(TriggerKey.allDown([.rightOption], flags: rightOptionDown))
        XCTAssertFalse(TriggerKey.allDown([.rightOption], flags: 0x8_0000 | 0x20)) // left option only
        XCTAssertFalse(TriggerKey.allDown([], flags: rightOptionDown))
    }

    func testExtraModifiers() {
        XCTAssertEqual(TriggerKey.extraModifiers(flags: rightOptionDown, trigger: [.rightOption]), [])
        let withShift = rightOptionDown | 0x2_0000 | 0x2
        XCTAssertEqual(TriggerKey.extraModifiers(flags: withShift, trigger: [.rightOption]), .shift)
        let bothOptions = rightOptionDown | 0x20
        XCTAssertEqual(TriggerKey.extraModifiers(flags: bothOptions, trigger: [.rightOption]), .option)
    }
}

final class CommandTests: XCTestCase {
    func testParsing() {
        XCTAssertEqual(CommandParser.parse(URL(string: "swoop://action/maximize")!), .action(.builtin(.maximize)))
        XCTAssertEqual(CommandParser.parse(URL(string: "swoop://action/right-two-thirds")!), .action(.builtin(.rightTwoThirds)))
        XCTAssertEqual(CommandParser.parse(URL(string: "swoop://screen/next")!), .action(.builtin(.nextScreen)))
        XCTAssertEqual(CommandParser.parse(URL(string: "swoop://direction/top-left")!), .direction(.topLeft))
        XCTAssertEqual(CommandParser.parse(URL(string: "swoop://maximize")!), .action(.builtin(.maximize)))
        XCTAssertEqual(CommandParser.parse(URL(string: "swoop://list/all")!), .list)
        XCTAssertNil(CommandParser.parse(URL(string: "swoop://action/nope")!))
        XCTAssertNil(CommandParser.parse(URL(string: "https://example.com")!))

        let custom = CustomLayout(name: "Writing Mode", x: 0.2, y: 0, width: 0.6, height: 1)
        XCTAssertEqual(CommandParser.parse(URL(string: "swoop://custom/writing-mode")!, customLayouts: [custom]),
                       .action(.custom(custom.id)))
    }

    func testEveryListedCommandParses() {
        for s in CommandParser.allCommands() {
            XCTAssertNotNil(CommandParser.parse(URL(string: s)!), s)
        }
    }

    func testKebab() {
        XCTAssertEqual(CommandParser.kebab("rightTwoThirds"), "right-two-thirds")
        XCTAssertEqual(CommandParser.kebab("macOSCenter"), "macos-center")
    }
}

final class SettingsTests: XCTestCase {
    func testRoundTrip() throws {
        var s = SwoopSettings()
        s.padding = 12
        s.triggerKeys = [.function, .rightCommand]
        s.customLayouts = [CustomLayout(name: "Focus", x: 0.1, y: 0.1, width: 0.8, height: 0.8)]
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(SwoopSettings.self, from: data)
        XCTAssertEqual(back, s)
    }

    func testForgivingDecode() throws {
        let json = """
        {"padding": 20, "triggerKeys": ["bogus"], "keybinds": [{"keyCode": 124, "actions": ["rightHalf", "fromTheFuture"]}, {"broken": true}]}
        """
        let s = try JSONDecoder().decode(SwoopSettings.self, from: Data(json.utf8))
        XCTAssertEqual(s.padding, 20)
        XCTAssertEqual(s.triggerKeys, [.leftOption]) // fell back to default
        XCTAssertEqual(s.keybinds.count, 1)
        XCTAssertEqual(s.keybinds[0].actions, [.builtin(.rightHalf)])
        XCTAssertEqual(s.radialActions, SwoopSettings.defaultRadialActions)
    }

    func testDefaultKeybindsAreUnique() {
        var seen = Set<String>()
        for k in SwoopSettings.defaultKeybinds {
            XCTAssertTrue(seen.insert("\(k.keyCode)-\(k.modifiers.rawValue)").inserted, k.shortcutLabel)
        }
    }
}

final class StashTests: XCTestCase {
    func testStashGeometry() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let w = CGRect(x: 300, y: 100, width: 400, height: 300)
        XCTAssertEqual(StashGeometry.hiddenFrame(window: w, screen: screen, side: .right, peek: 10).minX, 990)
        XCTAssertEqual(StashGeometry.hiddenFrame(window: w, screen: screen, side: .left, peek: 10).maxX, 10)
        XCTAssertEqual(StashGeometry.revealedFrame(window: w, screen: screen, side: .right).maxX, 1000)
    }

    func testEdgeNextToAnotherDisplayIsNotFree() {
        let main = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let external = CGRect(x: 1000, y: -200, width: 1920, height: 1080)
        XCTAssertFalse(StashGeometry.edgeIsFree(.right, screen: main, otherScreens: [external]))
        XCTAssertTrue(StashGeometry.edgeIsFree(.left, screen: main, otherScreens: [external]))
    }
}
