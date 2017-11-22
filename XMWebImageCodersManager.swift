//
//  XMWebImageCodersManager.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/22.
//

import Foundation
import UIKit

class XMWebImageCodersManager: XMWebImageCoder {
    static let shared = XMWebImageCodersManager()
    func encodedData(image: UIImage?, format: XMImageFormat) -> Data? {
        return nil
    }
    func decodedImage(data: Data?) -> UIImage? {
        return nil
    }
    @discardableResult
    func decompressed(image: UIImage?, data: inout Data, options: Dictionary<String, Any>?) -> UIImage? {
        return image

    }
}
