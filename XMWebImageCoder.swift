//
//  XMWebImageCoder.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/22.
//

import Foundation

public protocol XMWebImageCoder: NSObjectProtocol {
    func canDecode(data: Data?) -> Bool
    func decodedImage(data: Data?) -> UIImage?
    func decompressed(image: UIImage?, data: inout Data, options: Dictionary<String, Any>?) -> UIImage?
    func canEncode(format: XMImageFormat) -> Bool
    func encodedData(image: UIImage?, format: XMImageFormat) -> Data?
}
public extension XMWebImageCoder {
    func canDecode(data: Data?) -> Bool {
        return false
    }
    func decodedImage(data: Data?) -> UIImage? {
        return nil
    }
    func decompressed(image: UIImage?, data: inout Data, options: Dictionary<String, Any>?) -> UIImage? {
        return nil
    }
    func canEncode(format: XMImageFormat) -> Bool {
        return false
    }
    func encodedData(image: UIImage?, format: XMImageFormat) -> Data? {
        return nil
    }
}
let XMCGColorSpaceGetDeviceRGB = CGColorSpaceCreateDeviceRGB()
let XMWebImageCoderScaleDownLargeImagesKey = "scaleDownLargeImages"
let XMWebImageErrorDomain = "SDWebImageErrorDomain"

func XMCGImageRefContainsAlpha(cgImage: CGImage?) -> Bool {
    guard let imageRef = cgImage else { return false }
    let alphaInfo = imageRef.alphaInfo
    if alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
        return false
    }
    return true
}

protocol XMWebImageProgressiveCoder: XMWebImageCoder {
    func canIncrementallyDecode(data: Data?) -> Bool
    func incrementallyDecodedImage(data: Data?, isFinished: Bool) -> UIImage?

}
