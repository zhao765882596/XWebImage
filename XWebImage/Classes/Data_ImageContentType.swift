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
}















