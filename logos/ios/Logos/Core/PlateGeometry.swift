import Foundation

/// Parses the corpus's engraving plates (a small SVG subset: <path d> and
/// <circle>, with opacity, fill and stroke-dasharray) into drawing commands,
/// so the phone draws the same plates the web does, as vectors.
public struct PlateShape: Equatable {
    public enum Op: Equatable {
        case move(Double, Double)
        case line(Double, Double)
        case curve(Double, Double, Double, Double, Double, Double) // c1, c2, end
        case close
    }
    public var ops: [Op]
    public var opacity: Double = 1
    public var filled = false
    public var dash: [Double] = []
}

public enum PlateGeometry {
    public static let viewBox = (w: 240.0, h: 130.0)

    public static func parse(_ svg: String) -> [PlateShape] {
        var shapes: [PlateShape] = []
        var i = svg.startIndex
        while let open = svg[i...].firstIndex(of: "<"), let close = svg[open...].firstIndex(of: ">") {
            let tag = String(svg[svg.index(after: open)..<close])
            i = svg.index(after: close)
            let name = tag.prefix { $0.isLetter }
            let attrs = attributes(tag)
            var shape: PlateShape
            if name == "path", let d = attrs["d"] { shape = PlateShape(ops: pathOps(d)) }
            else if name == "circle", let cx = attrs["cx"].flatMap(Double.init), let cy = attrs["cy"].flatMap(Double.init),
                    let r = attrs["r"].flatMap(Double.init) { shape = PlateShape(ops: circleOps(cx, cy, r)) }
            else { continue }
            shape.opacity = attrs["opacity"].flatMap(Double.init) ?? 1
            shape.filled = attrs["fill"] == "currentColor"
            shape.dash = (attrs["stroke-dasharray"] ?? "").split(separator: " ").compactMap { Double($0) }
            if shape.opacity > 0 { shapes.append(shape) }
        }
        return shapes
    }

    static func attributes(_ tag: String) -> [String: String] {
        var out: [String: String] = [:]
        let scalars = Array(tag)
        var k = 0
        while k < scalars.count {
            guard let eq = scalars[k...].firstIndex(of: "="), eq + 1 < scalars.count, scalars[eq + 1] == "\"" else { break }
            var s = eq - 1
            while s >= 0, scalars[s] != " " { s -= 1 }
            let name = String(scalars[(s + 1)..<eq])
            guard let end = scalars[(eq + 2)...].firstIndex(of: "\"") else { break }
            out[name] = String(scalars[(eq + 2)..<end])
            k = end + 1
        }
        return out
    }

    static func circleOps(_ cx: Double, _ cy: Double, _ r: Double) -> [PlateShape.Op] {
        let k = 0.5522847498 * r
        return [.move(cx + r, cy),
                .curve(cx + r, cy + k, cx + k, cy + r, cx, cy + r),
                .curve(cx - k, cy + r, cx - r, cy + k, cx - r, cy),
                .curve(cx - r, cy - k, cx - k, cy - r, cx, cy - r),
                .curve(cx + k, cy - r, cx + r, cy - k, cx + r, cy),
                .close]
    }

    /// Tokenises numbers the way SVG does: "3-7", ".5.5", "1e-3" all split correctly.
    static func tokens(_ d: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var sawDot = false, sawExp = false
        func flush() { if !cur.isEmpty { out.append(cur) }; cur = ""; sawDot = false; sawExp = false }
        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" { flush(); out.append(String(ch)) }
            else if ch == "e" || ch == "E" { cur.append(ch); sawExp = true }
            else if ch == "-" || ch == "+" {
                if let last = cur.last, last == "e" || last == "E" { cur.append(ch) } else { flush(); cur.append(ch) }
            }
            else if ch == "." { if sawDot || sawExp { flush() }; cur.append(ch); sawDot = true }
            else if ch.isNumber { cur.append(ch) }
            else { flush() }
        }
        flush()
        return out
    }

    public static func pathOps(_ d: String) -> [PlateShape.Op] {
        var ops: [PlateShape.Op] = []
        let t = tokens(d)
        var i = 0
        var cmd: Character = "M"
        var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0
        var lastC2: (Double, Double)? = nil
        func num() -> Double? {
            guard i < t.count, let v = Double(t[i]) else { return nil }
            i += 1; return v
        }
        while i < t.count {
            if let c = t[i].first, c.isLetter { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let ox = rel ? x : 0, oy = rel ? y : 0
            switch cmd.uppercased().first! {
            case "M":
                guard let a = num(), let b = num() else { i += 1; continue }
                x = ox + a; y = oy + b; sx = x; sy = y
                ops.append(.move(x, y)); lastC2 = nil
                cmd = rel ? "l" : "L"                       // implicit lineto after moveto
            case "L":
                guard let a = num(), let b = num() else { i += 1; continue }
                x = ox + a; y = oy + b; ops.append(.line(x, y)); lastC2 = nil
            case "H":
                guard let a = num() else { i += 1; continue }
                x = ox + a; ops.append(.line(x, y)); lastC2 = nil
            case "V":
                guard let b = num() else { i += 1; continue }
                y = oy + b; ops.append(.line(x, y)); lastC2 = nil
            case "C":
                guard let a = num(), let b = num(), let c = num(), let e = num(), let f = num(), let g = num() else { i += 1; continue }
                ops.append(.curve(ox + a, oy + b, ox + c, oy + e, ox + f, oy + g))
                lastC2 = (ox + c, oy + e); x = ox + f; y = oy + g
            case "S":
                guard let c = num(), let e = num(), let f = num(), let g = num() else { i += 1; continue }
                let c1 = lastC2.map { (2 * x - $0.0, 2 * y - $0.1) } ?? (x, y)
                ops.append(.curve(c1.0, c1.1, ox + c, oy + e, ox + f, oy + g))
                lastC2 = (ox + c, oy + e); x = ox + f; y = oy + g
            case "A":
                guard let rx = num(), let ry = num(), let rot = num(), let large = num(), let sweep = num(),
                      let ex = num(), let ey = num() else { i += 1; continue }
                ops.append(contentsOf: arc(x, y, rx, ry, rot, large != 0, sweep != 0, ox + ex, oy + ey))
                x = ox + ex; y = oy + ey; lastC2 = nil
            case "Z":
                ops.append(.close); x = sx; y = sy; lastC2 = nil
            default:
                i += 1
            }
        }
        return ops
    }

    /// SVG endpoint arc to cubic Béziers (W3C implementation notes, F.6).
    static func arc(_ x1: Double, _ y1: Double, _ rxIn: Double, _ ryIn: Double, _ angle: Double,
                    _ large: Bool, _ sweep: Bool, _ x2: Double, _ y2: Double) -> [PlateShape.Op] {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || (x1 == x2 && y1 == y2) { return [.line(x2, y2)] }
        let phi = angle * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (x1 - x2) / 2, dy = (y1 - y2) / 2
        let x1p = cp * dx + sp * dy, y1p = -sp * dx + cp * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry, cyp = -coef * ry * x1p / rx
        let cx = cp * cxp - sp * cyp + (x1 + x2) / 2, cy = sp * cxp + cp * cyp + (y1 + y2) / 2
        func ang(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let segs = max(1, Int(ceil(abs(dt) / (.pi / 2))))
        let delta = dt / Double(segs)
        let k = 4.0 / 3.0 * tan(delta / 4)
        var ops: [PlateShape.Op] = []
        var th = t1
        for _ in 0..<segs {
            let c1 = cos(th), s1 = sin(th), c2 = cos(th + delta), s2 = sin(th + delta)
            func pt(_ px: Double, _ py: Double) -> (Double, Double) { (cx + rx * px * cp - ry * py * sp, cy + rx * px * sp + ry * py * cp) }
            let p1 = pt(c1 - k * s1, s1 + k * c1), p2 = pt(c2 + k * s2, s2 - k * c2), p3 = pt(c2, s2)
            ops.append(.curve(p1.0, p1.1, p2.0, p2.1, p3.0, p3.1))
            th += delta
        }
        return ops
    }
}
