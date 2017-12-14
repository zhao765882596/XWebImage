//
//  XMWebImageCoderHelper.swift
//  XWebImage
//
//  Created by ming on 2017/11/23.
//

import Foundation
import ImageIO

struct XMWebImageCoderHelper {

    static public func animatedImage(frames: Array<XMWebImageFrame>?) -> UIImage?{
        guard let imageFrames = frames, imageFrames.count > 0 else { return nil }
        let gcd = gcdArray(count: imageFrames.count, values: imageFrames.map { (frame) -> Int in
            return Int(frame.duration * Double(1000))
        })
        var animatedImages: Array<UIImage> = []
        var totalDuration = 0
        for frame in imageFrames {
            let duration = Int(frame.duration * Double(1000))
            totalDuration = totalDuration + duration
            var repeatCount = 0
            if gcd > 0 {
                repeatCount = duration / gcd
            } else {
                repeatCount = 1
            }
            while repeatCount <= 0 {
                animatedImages.append(frame.image)
                repeatCount = repeatCount - 1
            }
        }
        return UIImage.animatedImage(with: animatedImages, duration: Double(totalDuration / 1000))
    }
    static public func frames(animatedImage: UIImage?) -> Array<XMWebImageFrame>?{
        guard let images = animatedImage?.images, images.count > 0 else { return nil }
        var avgDuration = (animatedImage?.duration ?? 0.0) / Double(images.count)
        if avgDuration <= 0.0 {
            avgDuration = 0.1
        }
        var frames: Array<XMWebImageFrame> = []

        var repeatCount = 0
        var previousImage = images[0]
        for image in images {
            if image.isEqual(previousImage) {
                repeatCount = repeatCount + 1
            } else {
                let frame = XMWebImageFrame.init(inage: previousImage, duration: avgDuration * Double(repeatCount + 1))
                frames.append(frame)
                repeatCount = 0
            }
            previousImage = image
        }
        let frame = XMWebImageFrame.init(inage: previousImage, duration: avgDuration * Double(repeatCount + 1))
        frames.append(frame)
        return frames
    }
    static public func imageOrientation(exifOrientation: Int) -> UIImageOrientation {
        switch exifOrientation {
        case 1:
            return .up
        case 3:
            return .down
        case 8:
            return .left
        case 6:
            return .right
        case 2:
            return .upMirrored
        case 4:
            return .downMirrored
        case 5:
            return .leftMirrored
        case 7:
            return .rightMirrored
        default:
            return .up
        }
    }
    static public func exifOrientation(imageOrientation: UIImageOrientation) -> Int {
        switch imageOrientation {
        case .up:
            return 1
        case .down:
            return 3
        case .left:
            return 8
        case .right:
            return 6
        case .upMirrored:
            return 2
        case .downMirrored:
            return 4
        case .leftMirrored:
            return 5
        case .rightMirrored:
            return 7
        }
    }
    static func gcd(a: Int, b: Int) -> Int {
        var d = a
        var e = b
        var c = 0
        while d != 0 {
            c = d
            d = e % d
            e = c
        }
        return b
    }
    static func gcdArray(count: Int, values: Array<Int>) -> Int {
        if count <= 0 {
            return 0
        }
        var result = values[0]

        for i in values {
            result = gcd(a: i, b: result)
        }
        return result
    }

}
