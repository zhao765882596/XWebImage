//
//  Data_ImageContentType.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/17.
//

import Foundation
import MobileCoreServices

public enum  XMImageFormat: Int {
    case undefined = -1
    case JPEG = 0
    case PNG = 1
    case GIF = 2
    case TIFF = 3
    case webP = 4
    case HEIC = 5
    var UTType: CFString {
        if self == .JPEG {
            return kUTTypeJPEG
        } else if self == .PNG {
            return kUTTypePNG
        } else if self == .GIF {
            return kUTTypeGIF
        } else if self == .TIFF {
            return kUTTypeTIFF
        } else if self == .webP {
            return "public.webp" as CFString
        } else if self == .HEIC {
            return "public.heic" as CFString
        } else {
            return kUTTypePNG
        }
    }

}

public extension Data {
    public var xm_imageFormat: XMImageFormat {
        var buffer = [UInt8](repeating: 0, count: 1)
        (self as NSData).getBytes(&buffer, length: 8)
        switch buffer[0] {
        case 0xFF:
            return .JPEG
        case 0x89:
            return .PNG
        case 0x47:
            return .GIF
        case 0x49:
            return .TIFF
        case 0x4D:
            return .TIFF
        case 0x52:
            if self.count >= 12 {
                let str = String.init(data: subdata(in: startIndex ..< startIndex + 12), encoding: .ascii)
                if str?.hasPrefix("RIFF") == true && str?.hasSuffix("WEBP") == true {
                    return .webP
                }
            }
            break
        case 0x00:
            if count >= 12 {
                let str = String.init(data: subdata(in: startIndex + 4 ..< startIndex + 8), encoding: .ascii)
                if str == "ftypheic" || str == "ftypheix" || str == "ftyphevc" || str == "ftyphevx"{
                    return .HEIC
                }
            }
            break
        default:
            break
        }
        return .undefined
    }
//    var animatedGIF: UIImage? {
//        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else {
//            return nil
//        }
//        let count = CGImageSourceGetCount(source)
//        if count <= 1 {
//            return UIImage.init(data: self)
//        } else {
//            var images: Array<UIImage> = []
//            var duration: TimeInterval = 0.0;
//
//            for i in 0 ..< count {
//                guard let cgimage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
//                    continue
//                }
//                var subDuration = frameDurationAtIndex(index: i, source: source)
//
//                if subDuration < 0.011 {
//                    subDuration = 0.1
//                }
//                duration = duration + subDuration
//                images.append(UIImage.init(cgImage: cgimage, scale: UIScreen.main.scale, orientation: .up))
//            }
//            if duration == 0.0 {
//                duration = 1.0 / 10.0 * Double(count)
//            }
//            return UIImage.animatedImage(with: images, duration: duration)
//        }
//    }
//    func frameDurationAtIndex(index: Int, source: CGImageSource)  -> TimeInterval {
//        guard let dict = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? Dictionary<AnyHashable, Any> else {
//            return 0.1
//        }
//        guard let gifProperties = dict[kCGImagePropertyGIFDictionary] as? Dictionary<AnyHashable, Any> else {
//            return 0.1
//        }
//        guard let delayTimeUnclampedProp = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval else {
//            guard let delayTimeProp = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval else {
//                return 0.1
//            }
//            return delayTimeProp
//        }
//        return delayTimeUnclampedProp
//    }
}















