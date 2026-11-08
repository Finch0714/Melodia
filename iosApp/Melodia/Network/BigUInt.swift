import Foundation

struct BigUInt: Equatable {
    private(set) var bytes: [UInt8]

    static let zero = BigUInt([0])
    static let one = BigUInt([1])

    init(_ bytes: [UInt8]) {
        let trimmed = bytes.drop { $0 == 0 }
        self.bytes = trimmed.isEmpty ? [0] : Array(trimmed)
    }

    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var value = [UInt8]()
        value.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(String(hex[index..<next]), radix: 16) else { return nil }
            value.append(byte)
            index = next
        }
        self.init(value)
    }

    var isZero: Bool { bytes == [0] }

    func hexPadded(to length: Int) -> String {
        let value = bytes.map { String(format: "%02x", $0) }.joined()
        return String(repeating: "0", count: max(0, length - value.count)) + value
    }

    static func compare(_ lhs: BigUInt, _ rhs: BigUInt) -> Int {
        if lhs.bytes.count != rhs.bytes.count {
            return lhs.bytes.count < rhs.bytes.count ? -1 : 1
        }
        for (left, right) in zip(lhs.bytes, rhs.bytes) where left != right {
            return left < right ? -1 : 1
        }
        return 0
    }

    static func add(_ lhs: BigUInt, _ rhs: BigUInt) -> BigUInt {
        let count = max(lhs.bytes.count, rhs.bytes.count)
        var result = [UInt8](repeating: 0, count: count + 1)
        var carry = 0
        for offset in 0..<count {
            let left = offset < lhs.bytes.count ? Int(lhs.bytes[lhs.bytes.count - 1 - offset]) : 0
            let right = offset < rhs.bytes.count ? Int(rhs.bytes[rhs.bytes.count - 1 - offset]) : 0
            let sum = left + right + carry
            result[count - offset] = UInt8(sum & 0xFF)
            carry = sum >> 8
        }
        result[0] = UInt8(carry)
        return BigUInt(result)
    }

    static func subtract(_ lhs: BigUInt, _ rhs: BigUInt) -> BigUInt {
        precondition(compare(lhs, rhs) >= 0)
        let count = lhs.bytes.count
        var result = [UInt8](repeating: 0, count: count)
        var borrow = 0
        for offset in 0..<count {
            let left = Int(lhs.bytes[count - 1 - offset])
            let right = offset < rhs.bytes.count ? Int(rhs.bytes[rhs.bytes.count - 1 - offset]) : 0
            var value = left - right - borrow
            if value < 0 {
                value += 256
                borrow = 1
            } else {
                borrow = 0
            }
            result[count - 1 - offset] = UInt8(value)
        }
        return BigUInt(result)
    }

    static func addMod(_ lhs: BigUInt, _ rhs: BigUInt, modulus: BigUInt) -> BigUInt {
        let sum = add(lhs, rhs)
        return compare(sum, modulus) >= 0 ? subtract(sum, modulus) : sum
    }

    static func multiplyMod(_ lhs: BigUInt, _ rhs: BigUInt, modulus: BigUInt) -> BigUInt {
        var result = zero
        let addend = lhs
        for byte in rhs.bytes {
            for bit in stride(from: 7, through: 0, by: -1) {
                result = addMod(result, result, modulus: modulus)
                if ((Int(byte) >> bit) & 1) == 1 {
                    result = addMod(result, addend, modulus: modulus)
                }
            }
        }
        return result
    }

    func modPow(_ exponent: UInt64, modulus: BigUInt) -> BigUInt {
        guard !modulus.isZero else { return .zero }
        var result = BigUInt.one
        var base = self
        var power = exponent
        while power > 0 {
            if power & 1 == 1 {
                result = BigUInt.multiplyMod(result, base, modulus: modulus)
            }
            power >>= 1
            if power > 0 {
                base = BigUInt.multiplyMod(base, base, modulus: modulus)
            }
        }
        return result
    }
}
