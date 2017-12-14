//
//  UIView_WebCache.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/30.
//

import Foundation

struct RuntimeKey {
    static let operation = UnsafeRawPointer.init(bitPattern: "operationDictionary".hashValue)
    static let buttonImageURLStorageKey = UnsafeRawPointer.init(bitPattern: "buttonImageURLStorageKey".hashValue)
    static let imageURLKey = UnsafeRawPointer.init(bitPattern: "imageURLKey".hashValue)
    static let activityIndicator = UnsafeRawPointer.init(bitPattern: "activityIndicator".hashValue)
    static let showActivityIndicatorView = UnsafeRawPointer.init(bitPattern: "showActivityIndicatorView".hashValue)
    static let indicatorStyle = UnsafeRawPointer.init(bitPattern: "IndicatorStyle".hashValue)
}

public typealias XMSetImageBlock = (UIImage?, Data?) -> Void

public protocol URLConvertible {

    func asURL() -> URL?
}
extension String: URLConvertible {
    public func asURL() -> URL? {
        if isEmpty {
            return nil
        } else {
            return URL.init(string: self)
        }
    }
}
extension URL: URLConvertible {
    public func asURL() -> URL? {
        return self
    }
}
public  extension UIView {
    public var xm_imageURLStr: String? {
        return xm_imageURL?.absoluteString
    }
    public var xm_imageURL: URL? {
        return objc_getAssociatedObject(self, RuntimeKey.imageURLKey!) as? URL

    }
    public func xm_internalSetImage(url: URLConvertible?, placeholder: UIImage?, options: XMWebImageOptions = [], operationKey: String?, setImageBlock: XMSetImageBlock?, progressBlock: XMWebImageDownloaderProgress?, completedBlock:XMExternalCompletion?, isShouldUseGlobalQueue: Bool = false) {
        let validOperationKey = operationKey ?? "\(self.classForCoder)"

        xm_cancelImageLoadOperation(withKey: validOperationKey)
        objc_setAssociatedObject(self, RuntimeKey.imageURLKey!, validOperationKey, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if !options.contains(.delayPlaceholder) {
            DispatchQueue.main.async {
                self.set(image: placeholder, imageData: nil, setImageBlock: setImageBlock)
            }
        }
        guard let loadUrl = url?.asURL() else {
            DispatchQueue.main.async {
                self.xm_removeActivityIndicator()
                if completedBlock != nil {
                    completedBlock?(nil, NSError.init(domain: XMWebImageErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey : "Trying to load a nil url"]), .none, url?.asURL())
                }
            }
            return
        }
        if xm_showActivityIndicatorView {
            xm_addActivityIndicator()
        }
        let operation = XMWebImageManager.shared.loadImage(url: loadUrl, options: options, progress: progressBlock) {[weak self] (image, imageData, error, cacheType, isFinished, imageURL) in
            self?.xm_removeActivityIndicator()
            guard let sself = self else { return }
            let shouldCallCompletedBlock = isFinished || options.contains(.avoidAutoSetImage)
            let shouldNotSetImage = (image != nil && options.contains(.avoidAutoSetImage)) || (image == nil && !options.contains(.delayPlaceholder))
            let callCompletedBlockClojure = {[weak sself] in
                if sself == nil {
                    return
                }
                if shouldNotSetImage == false {
                    sself?.setNeedsLayout()
                }
                if completedBlock != nil && shouldCallCompletedBlock {
                    completedBlock?(image, error, cacheType, imageURL)
                }
            }
            if shouldNotSetImage {
                DispatchQueue.main.async {
                    callCompletedBlockClojure()
                }
            }
            var targetImage: UIImage? = nil
            var targetData: Data? = nil
            if image != nil {
                targetImage = image
                targetData = imageData
            } else if options.contains(.delayPlaceholder) {
                targetImage = placeholder
                targetData = nil
            }
            let queue = isShouldUseGlobalQueue ? DispatchQueue.global() : DispatchQueue.main
            queue.async {
                sself.set(image: targetImage, imageData: targetData, setImageBlock: setImageBlock)
                DispatchQueue.main.async {
                    callCompletedBlockClojure()
                }
            }
        }
        xm_setImageLoad(operation: operation, forKey: validOperationKey)
    }
    public func xm_cancelCurrentImageLoad() {
        xm_cancelImageLoadOperation(withKey: "\(self.classForCoder)")
    }
    func set(image: UIImage?, imageData: Data?, setImageBlock: XMSetImageBlock?) {
        if setImageBlock != nil {
            setImageBlock?(image, imageData)
            return
        }
        if self is UIImageView {
            (self as? UIImageView)?.image = image
        }
        if self is UIButton {
            (self as? UIButton)?.setImage(image, for: .normal)
        }
    }
    public var xm_activityIndicator: UIActivityIndicatorView? {
        set {
            if newValue != nil {
                objc_setAssociatedObject(self, RuntimeKey.activityIndicator!, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        get {
            return objc_getAssociatedObject(self, RuntimeKey.activityIndicator!) as? UIActivityIndicatorView
        }
    }
    public var xm_showActivityIndicatorView: Bool {
        set {
            objc_setAssociatedObject(self, RuntimeKey.showActivityIndicatorView!, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        get {
            return objc_getAssociatedObject(self, RuntimeKey.showActivityIndicatorView!) as? Bool ?? false
        }
    }
    public var xm_IndicatorStyle: UIActivityIndicatorViewStyle {
        set {
            objc_setAssociatedObject(self, RuntimeKey.indicatorStyle!, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
        get {
            return objc_getAssociatedObject(self, RuntimeKey.indicatorStyle!) as? UIActivityIndicatorViewStyle ?? .whiteLarge
        }
    }

    public func xm_addActivityIndicator() {
        DispatchQueue.main.async {
            if self.xm_activityIndicator == nil {
                self.xm_activityIndicator = UIActivityIndicatorView.init(activityIndicatorStyle: self.xm_IndicatorStyle)
                self.xm_activityIndicator?.translatesAutoresizingMaskIntoConstraints = false
                self.addSubview(self.xm_activityIndicator!)
                self.addConstraint(NSLayoutConstraint.init(item: self.xm_activityIndicator!, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0.0))
                self.addConstraint(NSLayoutConstraint.init(item: self.xm_activityIndicator!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0.0))
                self.xm_activityIndicator?.startAnimating()
            }
        }
    }
    public func xm_removeActivityIndicator() {
        DispatchQueue.main.async {
            self.xm_activityIndicator?.removeFromSuperview()
            self.xm_activityIndicator = nil
        }
    }
    public func xm_setImageLoad(operation: Any?, forKey key: String?) {
        if key != nil {
            xm_cancelImageLoadOperation(withKey: key)
            if operation != nil {
                operationDictionary[key!] = operation!
            }
        }

    }
    public func xm_cancelImageLoadOperation(withKey key: String?) {
        if key != nil {
            let operations = operationDictionary[key!]
            if operations is Array<XMWebImageOperation> {
                for operation in (operations as? Array<XMWebImageOperation>) ?? [] {
                    operation.cancel()
                }
            } else if operations is XMWebImageOperation {
                (operations as? XMWebImageOperation)?.cancel()
            }
        }


    }
    public func xm_removeImageLoadOperation(withKey key: String?) {
        if key != nil {
            operationDictionary.removeValue(forKey: key!)
        }
    }
    private var operationDictionary: Dictionary<String, Any> {
        set {}
        get {
            var dict = objc_getAssociatedObject(self, RuntimeKey.operation!) as? Dictionary<String, Any>
            if dict == nil {
                dict = [:]
                objc_setAssociatedObject(self, RuntimeKey.operation!, dict!, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            return dict!
        }

    }





}













