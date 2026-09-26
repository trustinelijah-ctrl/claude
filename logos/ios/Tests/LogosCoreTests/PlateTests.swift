import XCTest
@testable import LogosCore

final class PlateTests: XCTestCase {
    func testEveryPlateParsesInsideItsViewBox() {
        let plates = CorpusTests.corpus.plates
        XCTAssertFalse(plates.isEmpty)
        for (id, svg) in plates {
            let shapes = PlateGeometry.parse(svg)
            XCTAssertFalse(shapes.isEmpty, id)
            for s in shapes {
                for op in s.ops {
                    var pts: [(Double, Double)] = []
                    switch op {
                    case let .move(x, y), let .line(x, y): pts = [(x, y)]
                    case let .curve(_, _, _, _, x, y): pts = [(x, y)]
                    case .close: break
                    }
                    for (x, y) in pts {
                        XCTAssertTrue(x.isFinite && y.isFinite, id)
                        XCTAssertTrue((-10...250).contains(x) && (-10...140).contains(y), "\(id) point \(x),\(y)")
                    }
                }
            }
        }
    }
    func testTokeniser() {
        XCTAssertEqual(PlateGeometry.tokens("M120 30V16M97 39 87 29l10-10a19 19 0 0 1 32 0"),
                       ["M","120","30","V","16","M","97","39","87","29","l","10","-10","a","19","19","0","0","1","32","0"])
        XCTAssertEqual(PlateGeometry.tokens(".5.5-1"), [".5", ".5", "-1"])
    }
    func testArcEndsWhereItShould() {
        let ops = PlateGeometry.pathOps("M104 44a14 14 0 0 1 28 0")
        guard case let .curve(_, _, _, _, x, y)? = ops.last else { return XCTFail() }
        XCTAssertEqual(x, 132, accuracy: 1e-6); XCTAssertEqual(y, 44, accuracy: 1e-6)
    }
}
