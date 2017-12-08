//
//  UIButton_WebCache.swift
//  XWebImage
//
//  Created by ming on 2017/11/30.
//

import Foundation
fileprivate func imageURLKey(state: UIControlState) -> String {
    return String.init(format: "image_%lu", state.rawValue)


}
fileprivate func backgroundImageURLKey(state: UIControlState) -> String {
    return String.init(format: "backgroundImage_%lu", state.rawValue)
}

public extension UIButton {
    public func xm_currentImageURL() -> URL? {
        var url = imageURLStorage[imageURLKey(state: self.state)]
        if url == nil {
            url = imageURLStorage[imageURLKey(state: .normal)]
        }
        return url
    }
    public func xm_currentBackgroundImageURL() -> URL? {
        var url = imageURLStorage[backgroundImageURLKey(state: self.state)]
        if url == nil {
            url = imageURLStorage[backgroundImageURLKey(state: .normal)]
        }
        return url
    }
    public func xm_imageURL(state: UIControlState) -> URL? {
        return imageURLStorage[imageURLKey(state: state)]
    }
    public func xm_backgroundImageURL(state: UIControlState) -> URL? {
        return imageURLStorage[backgroundImageURLKey(state: state)]
    }

    public func xm_setImage(url: URLConvertible? = nil, forState state: UIControlState = [], placeholder: UIImage? = nil, options: XMWebImageOptions = [], completedBlock: XMExternalCompletion? = nil) {
        var imageUrl = url?.asURL()

        if imageUrl == nil {
            imageUrl = imageURLStorage[imageURLKey(state: state)]
        } else {
            imageURLStorage.removeValue(forKey: imageURLKey(state: state))
        }
        xm_internalSetImage(url: url, placeholder: placeholder, operationKey: String.init(format: "UIButtonImageOperation%@", state.rawValue), setImageBlock: { [weak self](image, imageData) in
            self?.setImage(image, for: state)
        }, progressBlock: nil, completedBlock: completedBlock)
    }
    public func xm_setBackgroundImage(url: URLConvertible? = nil, forState state: UIControlState = .normal, placeholder: UIImage? = nil, options: XMWebImageOptions = [], completedBlock: XMExternalCompletion? = nil) {
        var imageUrl = url?.asURL()

        if imageUrl == nil {
            imageUrl = imageURLStorage[backgroundImageURLKey(state: state)]
        } else {
            imageURLStorage.removeValue(forKey: backgroundImageURLKey(state: state))
        }
        xm_internalSetImage(url: url, placeholder: placeholder, operationKey: String.init(format: "UIButtonBackgroundImageOperation%@", state.rawValue), setImageBlock: { [weak self](image, imageData) in
            self?.setBackgroundImage(image, for: state)
            }, progressBlock: nil, completedBlock: completedBlock)
    }
    func xm_setImageLoadOperation(operation: XMWebImageOperation? = nil, forState state:UIControlState = .normal) {
        xm_setImageLoad(operation: operation, forKey: String.init(format: "UIButtonImageOperation%@", state.rawValue))
    }
    func xm_setBackgroundImageLoadOperation(operation: XMWebImageOperation? = nil, forState state:UIControlState = .normal) {
        xm_setImageLoad(operation: operation, forKey: String.init(format: "UIButtonBackgroundImageOperation%@", state.rawValue))
    }
    public func xm_cancelImageLoad(forState state:UIControlState = .normal) {
        xm_cancelImageLoadOperation(withKey: String.init(format: "UIButtonImageOperation%@", state.rawValue))

    }
    public func xm_cancelBackgroundImageLoad(forState state:UIControlState = .normal) {
        xm_cancelImageLoadOperation(withKey: String.init(format: "UIButtonBackgroundImageOperation%@", state.rawValue))
    }





}
fileprivate extension UIButton {
    var imageURLStorage: Dictionary<String, URL> {
        set {

        }
        get {
            var dict = objc_getAssociatedObject(self, RuntimeKey.buttonImageURLStorageKey!) as? Dictionary<String, URL>
            if dict == nil {
                dict = [:]
                objc_setAssociatedObject(self, RuntimeKey.buttonImageURLStorageKey!, dict!, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            return dict!
        }

    }


}
