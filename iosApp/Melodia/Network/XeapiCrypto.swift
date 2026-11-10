import CryptoKit
import Foundation

struct XeapiKeyState {
    let version: String
    let publicKey: String
    let sk: String?
}

// 网易云 xeapi（评论写入接口）加密实现，对应安卓端 XeapiCrypto/XeapiKeyStore。
enum XeapiCrypto {
    static let staticKey = hexData("ab1d5a430f6bb04a3f01e81ddd72bd916d5ce591248ac128714806d7f8fb1b84")
    private static let signKey = "mUHCwVNWJbunMqAHf5MImuirT6plvs6VSFW62MGHstFQxhBGdEoIhLItH3djc4+FB/OKty3+lL2rGeoFBpVe5g=="
    private static let eapiKey = Data("e82ckenh8dichen8".utf8)

    static func sign(timestamp: String, nonce: String) -> String {
        let key = SymmetricKey(data: Data(signKey.utf8))
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data((timestamp + nonce).utf8),
            using: key
        )
        return Data(mac).base64EncodedString()
    }

    static func decryptPublicKeyResponse(_ base64: String) throws -> XeapiKeyState {
        guard let encrypted = Data(base64Encoded: base64),
              let plaintext = NeteaseCrypto.aesECBDecrypt(encrypted, key: staticKey),
              let object = try JSONSerialization.jsonObject(with: plaintext) as? [String: Any]
        else {
            throw NeteaseError.invalidResponse
        }
        let publicKey = object["publicKey"] as? String ?? ""
        let version = object["version"] as? String ?? ""
        let sk = object["sk"] as? String
        guard !publicKey.isEmpty else {
            throw NeteaseError.invalidResponse
        }
        return XeapiKeyState(version: version, publicKey: publicKey, sk: sk)
    }

    static func decryptResponseBody(_ body: Data) throws -> Data {
        if body.first == 0x7B {
            return body
        }
        guard let decrypted = NeteaseCrypto.aesECBDecrypt(body, key: eapiKey) else {
            throw NeteaseError.invalidResponse
        }
        if decrypted.count >= 2, decrypted[decrypted.startIndex] == 0x1F,
           decrypted[decrypted.index(after: decrypted.startIndex)] == 0x8B {
            guard let inflated = gunzip(decrypted) else {
                throw NeteaseError.invalidResponse
            }
            return inflated
        }
        return decrypted
    }

    static func assembleRequest(
        path: String,
        fields: [(String, String)],
        state: XeapiKeyState
    ) throws -> (b: String, s: String, r: String) {
        let plaintext = Data(buildPlaintext(fields: fields).utf8)
        let dynamicKey = randomBytes(16)
        let mask = randomBytes(16)

        guard let innerCipher = NeteaseCrypto.aesECBEncrypt(plaintext, key: staticKey) else {
            throw NeteaseError.invalidResponse
        }
        let transformed = midTransform(innerCipher, mask: mask)
        guard let bCipher = NeteaseCrypto.aesECBEncrypt(transformed, key: dynamicKey) else {
            throw NeteaseError.invalidResponse
        }

        guard let peerData = Data(base64Encoded: state.publicKey) else {
            throw NeteaseError.invalidResponse
        }
        let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerData)
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: peer)
        let sharedData = shared.withUnsafeBytes { Data($0) }
        let aesKey = deriveAESKey(
            sharedSecret: sharedData,
            ephemeralPublicRaw: ephemeral.publicKey.rawRepresentation
        )

        let iv = randomBytes(12)
        let gcmPlaintext = Data("\(dynamicKey.base64EncodedString())|android|\(state.sk ?? "")".utf8)
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealed = try AES.GCM.seal(
            gcmPlaintext,
            using: SymmetricKey(data: aesKey),
            nonce: nonce
        )
        let gcmOutput = sealed.ciphertext + sealed.tag
        let s = ephemeral.publicKey.rawRepresentation + iv + gcmOutput

        guard let rCipher = NeteaseCrypto.aesECBEncrypt(
            Data("\(state.version)|".utf8),
            key: staticKey
        ) else {
            throw NeteaseError.invalidResponse
        }

        return (
            bCipher.base64EncodedString(),
            s.base64EncodedString(),
            rCipher.base64EncodedString()
        )
    }

    private static func buildPlaintext(fields: [(String, String)]) -> String {
        let form = fields.map { field in
            "\(encodeForm(field.0))=\(encodeForm(field.1))"
        }.joined(separator: "&")
        let body = Data(form.utf8).base64EncodedString()
        return "{\"body\":\"\(body)\",\"queryString\":\"e_r=true\"}"
    }

    private static func encodeForm(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: ".-*_")
        let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return encoded.replacingOccurrences(of: "%20", with: "+")
    }

    private static func deriveAESKey(sharedSecret: Data, ephemeralPublicRaw: Data) -> Data {
        let zeroKey = Data(repeating: 0, count: 32)
        let message = sharedSecret.isEmpty ? Data(repeating: 0, count: 32) : sharedSecret
        let prk = hmac(key: zeroKey, message: message)
        let okm = hmac(key: prk, message: ephemeralPublicRaw + Data([1]))
        return okm.prefix(16)
    }

    private static func hmac(key: Data, message: Data) -> Data {
        let authentication = HMAC<SHA256>.authenticationCode(
            for: message,
            using: SymmetricKey(data: key)
        )
        return Data(authentication)
    }

    private static func midTransform(_ ciphertext: Data, mask: Data) -> Data {
        let maskBytes = [UInt8](mask)
        let bytes = ciphertext.enumerated().map { index, byte in
            byte ^ maskBytes[index & 0x0F]
        }
        let encoded = Data(bytes).base64EncodedString()
        let encodedBytes = [UInt8](encoded.utf8)
        guard !encodedBytes.isEmpty else { return mask }
        let rotate = Int(maskBytes[0] & 0x0F) % encodedBytes.count
        var rotated = Array(encodedBytes[rotate...])
        rotated.append(contentsOf: encodedBytes[..<rotate])
        return mask + Data(rotated)
    }

    private static func randomBytes(_ count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        var data = Data(count: count)
        for index in 0..<count {
            data[index] = UInt8.random(in: 0...255, using: &generator)
        }
        return data
    }

    private static func hexData(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return Data() }
            data.append(byte)
            index = next
        }
        return data
    }

    private static func gunzip(_ data: Data) -> Data? {
        guard data.count > 18 else { return nil }
        var stream = z_stream()
        let initResult = inflateInit2_(
            &stream,
            15 + 16,
            zlibVersion(),
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initResult == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        var output = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        var status = Z_OK

        data.withUnsafeBytes { rawBuffer in
            guard let input = rawBuffer.bindMemory(to: Bytef.self).baseAddress else { return }
            stream.next_in = UnsafeMutablePointer(mutating: input)
            stream.avail_in = uInt(data.count)

            while status == Z_OK {
                var produced = 0
                chunk.withUnsafeMutableBytes { outputBuffer in
                    stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(chunk.count)
                    status = inflate(&stream, Z_NO_FLUSH)
                    produced = chunk.count - Int(stream.avail_out)
                }
                if produced > 0 {
                    output.append(contentsOf: chunk.prefix(produced))
                }
                if produced == 0 && status == Z_BUF_ERROR {
                    break
                }
            }
        }

        return status == Z_STREAM_END ? output : nil
    }
}