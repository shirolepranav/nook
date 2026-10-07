/// Retail barcode check digits (C-07): EAN-8, EAN-13, UPC-A and UPC-E. A misread barcode
/// fails its check digit, so the scanner waits for a good read instead of filling it.
public enum EAN {
    public static func isValid(_ code: String) -> Bool {
        guard code.allSatisfy(\.isASCII), code.allSatisfy(\.isNumber) else { return false }
        let digits = code.compactMap(\.wholeNumberValue)
        switch digits.count {
        case 12, 13: return checks(digits)
        case 8: return checks(digits) || (digits[0] <= 1 && checks(expandUPCE(digits)))
        default: return false
        }
    }

    /// Weights 3 and 1 from the right, starting next to the check digit.
    private static func checks(_ digits: [Int]) -> Bool {
        let body = digits.dropLast().reversed()
        let sum = body.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 3 : 1) }
        return (10 - sum % 10) % 10 == digits.last
    }

    /// UPC-E (number system, 6 digits, check) to its 12-digit UPC-A.
    private static func expandUPCE(_ e: [Int]) -> [Int] {
        let d = Array(e[1...6])
        let middle: [Int] = switch d[5] {
        case 0...2: [d[0], d[1], d[5], 0, 0, 0, 0, d[2], d[3], d[4]]
        case 3: [d[0], d[1], d[2], 0, 0, 0, 0, 0, d[3], d[4]]
        case 4: [d[0], d[1], d[2], d[3], 0, 0, 0, 0, 0, d[4]]
        default: [d[0], d[1], d[2], d[3], d[4], 0, 0, 0, 0, d[5]]
        }
        return [e[0]] + middle + [e[7]]
    }
}
