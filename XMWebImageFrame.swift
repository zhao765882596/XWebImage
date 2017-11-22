//
//  XMWebImageFrame.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/22.
//

import Foundation
public struct XMWebImageFrame {
    var _image: UIImage!
    var _duration: TimeInterval = 0.0

    public var image: UIImage {
        return _image
    }
    public var duration: TimeInterval {
        return _duration
    }
    init(inage: UIImage, duration: TimeInterval) {
        _image = image
        _duration = duration
    }

}
