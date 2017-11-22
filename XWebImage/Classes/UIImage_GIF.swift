//
//  UIImage_GIF.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/21.
//
import Foundation

struct XWebImageRuntimeKey {
    static let imageLoopCount = UnsafeRawPointer.init(bitPattern: "xm_imageLoopCount".hashValue)
}

public extension UIImage {

    public var xm_imageLoopCount: Int {
        set {
            willChangeValue(forKey: "xm_imageLoopCount")
            objc_setAssociatedObject(self, XWebImageRuntimeKey.imageLoopCount!, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            didChangeValue(forKey: "xm_imageLoopCount")
        }
        get {
            return objc_getAssociatedObject(self, XWebImageRuntimeKey.imageLoopCount!) as? Int ?? 0
        }
    }
    public var isGIF: Bool {
        return images != nil
    }
    public static func xm_animatedGIF(data: Data?) -> UIImage? {
        guard let gifData = data else { return nil }
        return XMWebImageGIFCoder.shared.decodedImage(data: gifData)
    }

    public static func xm_image(data: Data?) -> UIImage? {
        guard let gifData = data else { return nil }
        return XMWebImageCodersManager.shared.decodedImage(data: gifData)
    }
    public func xm_imageData(imageFormat: XMImageFormat = .undefined) -> Data? {
        return XMWebImageCodersManager.shared.encodedData(image: self, format: imageFormat)
    }
    static func decodedImage(image: UIImage?) -> UIImage? {
        guard let tmpImage = image else { return nil }
        var data = Data()
        return XMWebImageCodersManager.shared.decompressed(image: tmpImage, data: &data, options: [XMWebImageCoderScaleDownLargeImagesKey: false])
    }
    static func decodedAndScaledDownImage(image: UIImage?) -> UIImage? {
        guard let tmpImage = image else { return nil }
        var data = Data()
        return XMWebImageCodersManager.shared.decompressed(image: tmpImage, data: &data, options: [XMWebImageCoderScaleDownLargeImagesKey: false])
    }

    
}
