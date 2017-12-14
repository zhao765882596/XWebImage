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
    private var _orientation: UIImageOrientation = .up


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
        guard let imageData = data else { return nil }
        var image: UIImage? = nil

        if _imageSource == nil {
            _imageSource = CGImageSourceCreateIncremental(nil)
        }
        CGImageSourceUpdateData(_imageSource!, imageData as CFData, isFinished)
        if _width + _height == 0.0 {
            let properties = CGImageSourceCopyPropertiesAtIndex(_imageSource!, 0, nil) as? Dictionary<String, Any>
            if properties != nil {

                var val = properties?[kCGImagePropertyPixelHeight as String] as? CGFloat
                if val != nil {
                    _height = val!
                }
                val = properties?[kCGImagePropertyPixelWidth as String] as? CGFloat

                if val != nil {
                    _width = val!
                }
                let orientationValue = properties?[kCGImagePropertyOrientation as String] as? Int ?? 1
                _orientation = XMWebImageCoderHelper.imageOrientation(exifOrientation: orientationValue)
            }
        }
        if _width + _height > 0.0 {
            var partialImageRef = CGImageSourceCreateImageAtIndex(_imageSource!, 0, nil)
            if partialImageRef != nil {
                let partialHeight = partialImageRef?.height ?? 0
                let colorSpace = XMCGColorSpaceGetDeviceRGB
                let bmContext = CGContext(data: nil, width: Int(_width), height: Int(_height), bitsPerComponent: 8, bytesPerRow: Int(_width * 4), space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                if bmContext != nil {
                    bmContext?.draw(partialImageRef!, in: CGRect.init(x: 0, y: 0, width: Int(_width), height: partialHeight))
                    partialImageRef = bmContext?.makeImage()
                } else {
                    partialImageRef = nil
                }
            }
            if partialImageRef != nil {
                image = UIImage.init(cgImage: partialImageRef!)
            }
        }
        if isFinished {
            if _imageSource != nil {
                _imageSource = nil
            }
        }
        return image
    }
    public func decompressed(image: UIImage?) -> UIImage? {
        return xm_decompressedImage(image: image)
    }
    public func decompressed(image: UIImage?, data: inout Data) -> UIImage? {
        let scaledDownImage = xm_decompressedAndScaledDownImage(image: image)
        if scaledDownImage != nil && scaledDownImage?.size != image?.size {
            let imageData = self.encodedData(image: scaledDownImage, format: data.xm_imageFormat)
            if imageData != nil {
                    data = imageData!
            }
        }
        return scaledDownImage
    }
    func xm_decompressedAndScaledDownImage(image: UIImage?) -> UIImage? {
        if shouldDecode(image: image) == false {
            return image
        }
        if shouldScale(image: image) == false {
            return xm_decompressedImage(image: image)
        }
        var destContext: CGContext? = nil

        return autoreleasepool(invoking: { [weak self]() -> UIImage? in
            guard let cgImage = image?.cgImage else { return nil }
            let sourceTotalPixels = cgImage.width * cgImage.height
            let imageScale = destTotalPixels / CGFloat(sourceTotalPixels)
            let destResolution = CGSize.init(width: imageScale * CGFloat(cgImage.width), height: imageScale * CGFloat(cgImage.height))
            let colorspace = self?.colorSpace(imageRef: cgImage)
            let bytesPerRow = bytesPerPixel * destResolution.width
            destContext = CGContext(data: nil, width: Int(destResolution.width), height: Int(destResolution.height), bitsPerComponent: 8, bytesPerRow: Int(bytesPerRow), space: colorspace!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
            if destContext == nil {
                return nil
            }
            destContext?.interpolationQuality = .high
            var sourceTile = CGRect.zero
            sourceTile.size.width = CGFloat(cgImage.width)
            sourceTile.size.height = tileTotalPixels / CGFloat(cgImage.height)
            var destTile = CGRect.zero
            destTile.size.width = destResolution.width
            destTile.size.height = sourceTile.size.height * imageScale
            let sourceSeemOverlap = ((destSeemOverlap / destResolution.height) * CGFloat(cgImage.height))
            var sourceTileImageRef: CGImage? = nil
            var iterations = cgImage.height / Int( sourceTile.size.height)
            let remainder = cgImage.height % Int(sourceTile.size.height)
            if remainder == 0 {
                iterations = iterations + 1
            }
            let sourceTileHeightMinusOverlap = sourceTile.size.height;
            sourceTile.size.height = sourceTile.size.height + sourceSeemOverlap
            destTile.size.height = destTile.size.height + destSeemOverlap
            for y in 0 ..< iterations {
                sourceTile.origin.y = CGFloat(y) * sourceTileHeightMinusOverlap + sourceSeemOverlap
                destTile.origin.y = destResolution.height - (CGFloat( y + 1 ) * sourceTileHeightMinusOverlap * imageScale + destSeemOverlap)
                sourceTileImageRef = cgImage.cropping(to: sourceTile)
                if( y == iterations - 1 && remainder != 0 ) {
                    var dify = destTile.size.height;
                    destTile.size.height = CGFloat(cgImage.height) * imageScale;
                    dify = dify - destTile.size.height;
                    destTile.origin.y = destTile.origin.y + dify;
                }
                if sourceTileImageRef != nil {
                    destContext?.draw(sourceTileImageRef!, in: destTile)
                }
            }

            let destcgImage = destContext?.makeImage();
            if destcgImage  == nil {
                return image
            }
            let destImage = UIImage.init(cgImage: destcgImage!, scale: image?.scale ?? 1.0, orientation: image?.imageOrientation ?? .up)
            return destImage
        })

    }
    func xm_decompressedImage(image: UIImage?) -> UIImage? {
        if shouldDecode(image: image) == false {
            return image
        }

        guard let cgImage = image?.cgImage else { return nil }
        return autoreleasepool {[weak self]() -> UIImage? in
            let colorspace = self?.colorSpace(imageRef: cgImage)
            let bmContext = CGContext(data: nil, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: Int(bytesPerPixel) * cgImage.width, space: colorspace!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            if bmContext == nil {
                return image
            }
            bmContext?.draw(cgImage, in: CGRect.init(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

            if let imageRefWithoutAlpha = bmContext?.makeImage() {
                return UIImage.init(cgImage: imageRefWithoutAlpha, scale: image?.scale ?? 1.0, orientation: image?.imageOrientation ?? .up)
            }
            return nil
        }
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
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource!, 0, nil) as? Dictionary<String, Any>
            if properties != nil {
                result = XMWebImageCoderHelper.imageOrientation(exifOrientation: properties?[kCGImagePropertyOrientation as String] as? Int ?? 1)
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
