//
//  XMWebImageImageIOCoder.swift
//  XWebImage
//
//  Created by ming on 2017/11/23.
//

import Foundation
public class XMWebImageImageIOCoder: NSObject, XMWebImageProgressiveCoder {
    func canIncrementallyDecode(data: Data?) -> Bool {
        if data?.xm_imageFormat != .webP {
            return false
        } else {
            return true
        }
    }
    
    func incrementallyDecodedImage(data: Data?, isFinished: Bool) -> UIImage? {
        return nil
    }
    
    static let shared = XMWebImageImageIOCoder()


}
