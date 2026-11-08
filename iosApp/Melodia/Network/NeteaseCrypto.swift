import Foundation

enum NeteaseCrypto {
    static let iv = "0102030405060708"
    static let presetKey = "0CoJUm6Qyw8W8jud"
    static let publicKey = "010001"
    static let modulus = "e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7"
    static let eapiKey = "e82ckenh8dichen8"

    private static let randomCharset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    static func weapi(json: String) -> [String: String] {
        let secretKey = String((0..<16).compactMap { _ in randomCharset.randomElement() })
        let firstPass = aesCBCBase64(text: json, key: presetKey)
        let params = aesCBCBase64(text: firstPass, key: secretKey)
        return [
            "params": params,
            "encSecKey": rsaEncrypt(secretKey)
        ]
    }

    static func eapi(apiPath: String, json: String) -> String {
        let digest = md5("nobody\(apiPath)use\(json)md5forencrypt")
        let payload = "\(apiPath)-36cd479b6b5-\(json)-36cd479b6b5-\(digest)"
        return aesECBHex(text: payload, key: eapiKey).uppercased()
    }

    static func md5(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            CC_MD5(base, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func rsaEncrypt(_ text: String) -> String {
        let reversedBytes = Array(String(text.reversed()).utf8)
        let message = BigUInt(reversedBytes)
        guard
            let exponent = UInt64(publicKey, radix: 16),
            let modulusValue = BigUInt(hex: modulus)
        else {
            return String(repeating: "0", count: 256)
        }
        let encrypted = message.modPow(exponent, modulus: modulusValue)
        return encrypted.hexPadded(to: 256)
    }

    private static func aesCBCBase64(text: String, key: String) -> String {
        let data = Data(text.utf8)
        let keyData = Data(key.utf8)
        let ivData = Data(iv.utf8)
        guard let encrypted = crypt(
            data: data,
            key: keyData,
            iv: ivData,
            options: CCOptions(kCCOptionPKCS7Padding)
        ) else {
            return ""
        }
        return encrypted.base64EncodedString()
    }

    private static func aesECBHex(text: String, key: String) -> String {
        let data = Data(text.utf8)
        let keyData = Data(key.utf8)
        let options = CCOptions(kCCOptionPKCS7Padding) | CCOptions(kCCOptionECBMode)
        guard let encrypted = crypt(data: data, key: keyData, iv: nil, options: options) else {
            return ""
        }
        return encrypted.map { String(format: "%02x", $0) }.joined()
    }

    private static func crypt(data: Data, key: Data, iv: Data?, options: CCOptions) -> Data? {
        var output = Data(count: data.count + 32)
        var outputLength = 0
        let status: CCCryptorStatus = output.withUnsafeMutableBytes { outputRaw in
            data.withUnsafeBytes { dataRaw in
                key.withUnsafeBytes { keyRaw in
                    if let iv {
                        return iv.withUnsafeBytes { ivRaw in
                            CCCrypt(
                                CCOperation(kCCEncrypt),
                                CCAlgorithm(kCCAlgorithmAES),
                                options,
                                keyRaw.baseAddress,
                                key.count,
                                ivRaw.baseAddress,
                                dataRaw.baseAddress,
                                data.count,
                                outputRaw.baseAddress,
                                outputRaw.count,
                                &outputLength
                            )
                        }
                    }
                    return CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        options,
                        keyRaw.baseAddress,
                        key.count,
                        nil,
                        dataRaw.baseAddress,
                        data.count,
                        outputRaw.baseAddress,
                        outputRaw.count,
                        &outputLength
                    )
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        output.removeSubrange(outputLength..<output.count)
        return output
    }
}
