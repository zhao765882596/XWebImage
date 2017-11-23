//
//  XMWebImageCodersManager.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/22.
//

import Foundation
import UIKit

public class XMWebImageCodersManager: NSObject, XMWebImageCoder {
    public static let shared = XMWebImageCodersManager()
    private var _coders: Array<XMWebImageCoder> = [XMWebImageImageIOCoder.shared]
    private var mutableCodersAccessQueue = DispatchQueue.init(label: "com.XMWebImageCodersManager")

    override init() {

    }

    public var coders: Array<XMWebImageCoder> {
        set {
            mutableCodersAccessQueue.sync {
                self._coders = newValue
            }
        }
        get {
            var sortedCoders: Array<XMWebImageCoder> = []
            mutableCodersAccessQueue.sync {
                sortedCoders = self._coders.reversed()
            }
            return sortedCoders
        }
    }
    public func add(coder: XMWebImageCoder) {
        mutableCodersAccessQueue.sync {
            self._coders.append(coder)
        }
    }
    public func removed(coder: XMWebImageCoder) {
        mutableCodersAccessQueue.sync {
            for i in 0 ..< self.coders.count {
                if self.coders[i].isEqual(coder)  {
                    self._coders.remove(at: i)
                }

            }
        }
    }
    public func canDecode(data: Data?) -> Bool {
        for coder in _coders {
            if coder.canDecode(data: data) {
                return true
            }
        }
        return false
    }
    public func decodedImage(data: Data?) -> UIImage? {
        if data == nil {
            return nil
        }
        for coder in _coders {
            if coder.canDecode(data: data) {
                return coder.decodedImage(data: data)
            }
        }
        return nil
    }
    public func decompressed(image: UIImage?, data: inout Data, options: Dictionary<String, Any>?) -> UIImage? {
        if image == nil {
            return nil
        }
        for coder in _coders {
            if coder.canDecode(data: data) {
                return coder.decompressed(image:image, data: &data, options:options)
            }
        }
        return nil
    }
    public func canEncode(format: XMImageFormat) -> Bool {
        for coder in _coders {
            if coder.canEncode(format: format) {
                return true
            }
        }
        return false
    }
    public func encodedData(image: UIImage?, format: XMImageFormat) -> Data? {
        if image == nil {
            return nil
        }
        for coder in _coders {
            if coder.canEncode(format: format) {
                return coder.encodedData(image:image, format:format)
            }
        }
        return nil
    }

}
