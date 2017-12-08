//
//  XMWebImageImageIOCoder.swift
//  XWebImage
//
//  Created by ming on 2017/11/23.
//

import Foundation


private let bytesPerPixel: CGFloat = 4
private let bitsPerComponent: CGFloat = 8
private let destImageSizeMB: CGFloat = 60.0
private let sourceImageTileSizeMB: CGFloat = 60.0
private let bytesPerMB: CGFloat = 1024.0 * 1024.0
private let pixelsPerMB: CGFloat = bytesPerMB / bytesPerPixel
private let destTotalPixels: CGFloat = destImageSizeMB * pixelsPerMB
private let tileTotalPixels: CGFloat = sourceImageTileSizeMB * pixelsPerMB
private let destSeemOverlap: CGFloat = 2.0



public class XMWebImageImageIOCoder: NSObject, XMWebImageProgressiveCoder {
    public static let shared = XMWebImageImageIOCoder()
    private var _width: CGFloat = 0
    private var _height: CGFloat = 0
    private var _imageSource: CGImageSource? = nil

    public func canDecode(data: Data?) -> Bool {
        if data != nil {
            return data?.xm_imageFormat != .webP
        } else {
            return false
        }
    }
    public func canIncrementallyDecode(data: Data?) -> Bool {
        if data?.xm_imageFormat != .webP {
            return false
        } else {
            return true
        }
    }

    public func decodedImage(data: Data?) -> UIImage? {
        guard let decodedData = data else { return nil }
        var image = UIImage.init(data: decodedData)
        if image == nil {
            return nil
        }
        if decodedData.xm_imageFormat == .GIF {
            image = UIImage.animatedImage(with: [image!], duration: image!.duration)
            return image
        }
        let orientation = xm_imageOrientation(imageData: decodedData)
        if orientation != .up && image!.cgImage != nil {
            image = UIImage.init(cgImage: image!.cgImage!, scale: image!.scale, orientation: orientation)
        }
        return image;
    }

    public func incrementallyDecodedImage(data: Data?, isFinished: Bool) -> UIImage? {
        return nil
    }
    public func decompressed(image: UIImage? = nil, data: inout Data, isScaleDownLargeImages: Bool) -> UIImage? {
        if isScaleDownLargeImages == false {
            return xm_decompressedImage(image: image)
        } else {
            let scaledDownImage = xm_decompressedAndScaledDownImage(image: image)
            if scaledDownImage != nil && scaledDownImage?.size != image?.size {
                let imageData = self.encodedData(image: scaledDownImage, format: data.xm_imageFormat)
                if imageData != nil {
                    data = imageData!
                }
            }
            return scaledDownImage
        }
    }
    func xm_decompressedAndScaledDownImage(image: UIImage?) -> UIImage? {
        return nil

    }
    func xm_decompressedImage(image: UIImage?) -> UIImage? {
        return nil

    }
    public func canEncode(format: XMImageFormat) -> Bool {
        if format == .webP {
            return false
        } else if format == .HEIC {
            if (CGImageDestinationCreateWithData(Data() as! CFMutableData, format.UTType, 1, nil) != nil) {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
    public func encodedData(image: UIImage?, format: XMImageFormat) -> Data? {
        guard let encodedImage = image else { return nil }
        var encodedFormat = format
        if encodedFormat == .undefined {
            if XMCGImageRefContainsAlpha(cgImage: encodedImage.cgImage) {
                encodedFormat = .PNG
            } else {
                encodedFormat = .JPEG
            }
        }
        var imageData: Data? = Data()
        let imageUTType = encodedFormat.UTType
        let imageDestination = CGImageDestinationCreateWithData(imageData as! CFMutableData, imageUTType, 1, nil)
        if imageDestination == nil {
            return nil
        }
        let exifOrientation = XMWebImageCoderHelper.exifOrientation(imageOrientation: encodedImage.imageOrientation)
        CGImageDestinationAddImage(imageDestination!, encodedImage.cgImage!, [kCGImagePropertyOrientation: exifOrientation] as CFDictionary)
        if CGImageDestinationFinalize(imageDestination!) == false {
            imageData = nil
            return nil
        }
        return imageData
    }
    func shouldDecode(image: UIImage?) -> Bool {
        if image == nil && image?.images == nil {
            return false
        }
        if XMCGImageRefContainsAlpha(cgImage: image?.cgImage){
            return false
        }
        return true
    }
    func xm_imageOrientation(imageData:Data) -> UIImageOrientation {
        var result = UIImageOrientation.up
        let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil)
        if imageSource != nil {
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource!, 0, nil)
            if properties != nil {
                let exifOrientation = CFDictionaryGetValue(properties!, UnsafeRawPointer.init(bitPattern: kCGImagePropertyOrientation.hashValue))
                result = XMWebImageCoderHelper.imageOrientation(exifOrientation: Int.init(bitPattern: exifOrientation))
            }
        }
        return result
    }
    func shouldScale(image: UIImage?) -> Bool {
        guard let sourceImage = image?.cgImage else { return true }
        let sourceTotalPixels = sourceImage.width * sourceImage.height
        if destTotalPixels / CGFloat(sourceTotalPixels) < 1.0 {
            return true
        } else {
            return false
        }
    }
    func colorSpace(imageRef: CGImage) -> CGColorSpace? {
        let imageColorSpaceModel = imageRef.colorSpace?.model
        var colorspaceRef = imageRef.colorSpace
        if imageColorSpaceModel == .unknown || imageColorSpaceModel == .monochrome || imageColorSpaceModel == .cmyk || imageColorSpaceModel == .indexed {
            colorspaceRef = XMCGColorSpaceGetDeviceRGB
        }
        return colorspaceRef
    }

}
