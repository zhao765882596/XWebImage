//
//  XMWebImageGIFCoder.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/22.
//

import Foundation
class XMWebImageGIFCoder: NSObject,XMWebImageCoder {
    static let shared = XMWebImageGIFCoder()
    func canDecode(data: Data?) -> Bool {
       return (data?.xm_imageFormat == .GIF) == true
    }

    func decompressed(image: UIImage?, data: inout Data, options: Dictionary<String, Any>?) -> UIImage? {
        return image
    }
    func decodedImage(data: Data?) -> UIImage? {
        guard let sourceData = data else { return nil }
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil) else {
            return nil
        }
        let count = CGImageSourceGetCount(source)
        if count <= 1 {
            return UIImage.init(data: sourceData)
        } else {
            var imageFrames: Array<XMWebImageFrame> = []
            var duration: TimeInterval = 0.0;

            for i in 0 ..< count {
                guard let cgimage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                    continue
                }
                var subDuration = xm_frameDurationAtIndex(index: i, source: source)

                if subDuration < 0.011 {
                    subDuration = 0.1
                }
                duration = duration + subDuration
                let image = UIImage.init(cgImage: cgimage, scale: UIScreen.main.scale, orientation: .up)

                imageFrames.append(XMWebImageFrame.init(inage: image, duration: duration))
            }
            if duration == 0.0 {
                duration = 1.0 / 10.0 * Double(count)
            }
            var loopCount = 0
            let imageProperties = CGImageSourceCopyProperties(source, nil) as? Dictionary<AnyHashable, Any>
            let gifProperties = imageProperties?[kCGImagePropertyGIFDictionary] as? Dictionary<AnyHashable, Any>
            if let gifLoopCount = gifProperties?[kCGImagePropertyGIFLoopCount] as? Int {
                loopCount = gifLoopCount
            }
            let animated = XMWebImageCoderHelper.animatedImage(frames: imageFrames)
            animated?.xm_imageLoopCount = loopCount
            return animated
        }
    }
    func xm_frameDurationAtIndex(index: Int, source: CGImageSource)  -> TimeInterval {
        guard let dict = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? Dictionary<AnyHashable, Any> else {
            return 0.1
        }
        guard let gifProperties = dict[kCGImagePropertyGIFDictionary] as? Dictionary<AnyHashable, Any> else {
            return 0.1
        }
        guard let delayTimeUnclampedProp = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval else {
            guard let delayTimeProp = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval else {
                return 0.1
            }
            return delayTimeProp
        }
        return delayTimeUnclampedProp

    }
    func encodedData(image: UIImage?, format: XMImageFormat) -> Data? {
        guard let encodedImage = image, format != .GIF else { return nil }
        var imageData: Data? = Data()

        let imageUTType = format.UTType
        guard let frames = XMWebImageCoderHelper.frames(animatedImage: encodedImage) else { return nil }
        guard let imageDestination = CGImageDestinationCreateWithData(imageData as! CFMutableData, imageUTType, frames.count, nil) else{ return nil }
        if let cgImage = encodedImage.cgImage, frames.count == 0 {
            CGImageDestinationAddImage(imageDestination, cgImage, nil);
        } else {
            let loopCount = encodedImage.xm_imageLoopCount
            let gifProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]]
            CGImageDestinationSetProperties(imageDestination, gifProperties as CFDictionary)
            for frame in frames {
                let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: frame.duration]]
                CGImageDestinationAddImage(imageDestination, frame.image.cgImage!, frameProperties as CFDictionary);
            }
        }
        if CGImageDestinationFinalize(imageDestination) {
            imageData = nil
        }
        return imageData
    }
}

