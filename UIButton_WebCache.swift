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

extension UIButton {
    func xm_currentImageURL() -> URL? {
        var url = imageURLStorage[imageURLKey(state: self.state)]
        if url == nil {
            url = imageURLStorage[imageURLKey(state: .normal)]
        }
        return url
    }
    func xm_imageURL(state: UIControlState) -> URL? {
        return imageURLStorage[imageURLKey(state: state)]
    }
    private var imageURLStorage: Dictionary<String, URL> {
        set {

        }
        get {
            var dict = objc_getAssociatedObject(self, RuntimeKey.imageURLStorageKey!) as? Dictionary<String, URL>
            if dict == nil {
                dict = [:]
                objc_setAssociatedObject(self, RuntimeKey.imageURLStorageKey!, dict!, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            return dict!
        }

    }
    func xm_setImage(url: URLConvertible? = nil, forState state: UIControlState = [], placeholder: UIImage? = nil, options: XMWebImageOptions = [], completedBlock: XMExternalCompletion? = nil) {
        var imageUrl = url?.asURL()

        if imageUrl == nil {
            imageUrl = imageURLStorage[imageURLKey(state: state)]
        } else {
            imageURLStorage.removeValue(forKey: imageURLKey(state: state))
        }
        xm_internalSetImage(url: url, placeholder: placeholder, operationKey: String.init(format: "UIButtonImageOperation%@", state.rawValue), setImageBlock: { [weak self](image, imageData) in
            self?.setImage(image, for: state)
        }, progressBlock: nil, completedBlock: completedBlock, context: nil)
    }
    func xm_setBackgroundImage(url: URLConvertible? = nil, forState state: UIControlState = .normal, placeholder: UIImage? = nil, options: XMWebImageOptions = [], completedBlock: XMExternalCompletion? = nil) {
        var imageUrl = url?.asURL()

        if imageUrl == nil {
            imageUrl = imageURLStorage[backgroundImageURLKey(state: state)]
        } else {
            imageURLStorage.removeValue(forKey: backgroundImageURLKey(state: state))
        }
        xm_internalSetImage(url: url, placeholder: placeholder, operationKey: String.init(format: "UIButtonBackgroundImageOperation%@", state.rawValue), setImageBlock: { [weak self](image, imageData) in
            self?.setBackgroundImage(image, for: state)
            }, progressBlock: nil, completedBlock: completedBlock, context: nil)
    }
    func xm_setImageLoadOperation(operation: XMWebImageOption? = nil, forState state:UIControlState = .normal) {
        xm_setImageLoad(operation: operation, forKey: String.init(format: "UIButtonImageOperation%@", state.rawValue))
    }
    func xm_setBackgroundImageLoadOperation(operation: XMWebImageOption? = nil, forState state:UIControlState = .normal) {
        xm_setImageLoad(operation: operation, forKey: String.init(format: "UIButtonBackgroundImageOperation%@", state.rawValue))
    }
    func xm_cancelImageLoad(forState state:UIControlState = .normal) {
        xm_cancelImageLoadOperation(withKey: String.init(format: "UIButtonImageOperation%@", state.rawValue))

    }
    func xm_cancelBackgroundImageLoad(forState state:UIControlState = .normal) {
        xm_cancelImageLoadOperation(withKey: String.init(format: "UIButtonBackgroundImageOperation%@", state.rawValue))
    }





}
