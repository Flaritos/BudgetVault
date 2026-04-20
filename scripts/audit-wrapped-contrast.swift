#!/usr/bin/env swift
//
// audit-wrapped-contrast.swift
// Computes WCAG 2.1 contrast ratios for every text-on-background pair on
// the Wrapped surface. Exits non-zero if any non-decorative pair < 4.5:1.
//
// Usage:
//   swift scripts/audit-wrapped-contrast.swift
//
import Foundation

struct RGB { let r: Double; let g: Double; let b: Double }

func hex(_ s: String) -> RGB {
    let h = s.replacingOccurrences(of: "#", with: "")
    var int: UInt64 = 0
    Scanner(string: h).scanHexInt64(&int)
    return RGB(r: Double((int >> 16) & 0xFF) / 255.0,
               g: Double((int >>  8) & 0xFF) / 255.0,
               b: Double( int        & 0xFF) / 255.0)
}

func composite(fg: RGB, alpha: Double, bg: RGB) -> RGB {
    RGB(r: fg.r * alpha + bg.r * (1 - alpha),
        g: fg.g * alpha + bg.g * (1 - alpha),
        b: fg.b * alpha + bg.b * (1 - alpha))
}

func luminance(_ c: RGB) -> Double {
    func t(_ v: Double) -> Double {
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * t(c.r) + 0.7152 * t(c.g) + 0.0722 * t(c.b)
}

func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
    let la = luminance(a) + 0.05
    let lb = luminance(b) + 0.05
    return la > lb ? la / lb : lb / la
}

let navy = hex("#0F1B33")
let white = hex("#FFFFFF")
let neonGreen = hex("#34D399")
let neonPurple = hex("#A78BFA")

struct Pair { let label: String; let fg: RGB; let alpha: Double; let bg: RGB; let isLargeText: Bool }

let pairs: [Pair] = [
    Pair(label: "Slide 1 'YOUR STORY' eyebrow @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
    Pair(label: "Slide 1 'SAVED' label @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
    Pair(label: "Slide 1 body subtitle @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
    Pair(label: "Slide 2 'WHERE IT WENT' @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
    Pair(label: "Slide 2 'That's X%' caption @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
    Pair(label: "Slide 3 'YOUR SPENDING TYPE' @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
    Pair(label: "Slide 4 'BY THE NUMBERS' @ 0.7", fg: white, alpha: 0.7, bg: navy, isLargeText: false),
    Pair(label: "Saved% on green (slide 1)", fg: neonGreen, alpha: 1.0, bg: navy, isLargeText: true),
    Pair(label: "Top category amount on purple", fg: neonPurple, alpha: 1.0, bg: navy, isLargeText: true),
]

var failed = 0
for p in pairs {
    let fg = composite(fg: p.fg, alpha: p.alpha, bg: p.bg)
    let cr = contrastRatio(fg, p.bg)
    let threshold = p.isLargeText ? 3.0 : 4.5
    let pass = cr >= threshold
    let mark = pass ? "PASS" : "FAIL"
    print("[\(mark)] \(String(format: "%.2f", cr)):1 — \(p.label) (need \(threshold):1)")
    if !pass { failed += 1 }
}

print("")
if failed > 0 {
    print("FAILED: \(failed) pair(s) below WCAG threshold")
    exit(1)
} else {
    print("All pairs pass WCAG 2.1 AA")
}
