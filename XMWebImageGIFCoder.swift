//
//  XMWebImageGIFCoder.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/22.
//

import Foundation
class XMWebImageGIFCoder: XMWebImageCoder {
    static let shared = XMWebImageGIFCoder()
    func canDecode(data: Data?) -> Bool {
       return (data?.xm_imageFormat == .GIF) == true
    }
    func decodedImage(data: Data?) -> UIImage? {
        guard let imageData = data else { return nil }
        return UIImage.init(data: imageData)
    }

}
