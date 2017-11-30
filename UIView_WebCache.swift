//
//  UIView_WebCache.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/30.
//

import Foundation

struct RuntimeKey {
    static let operation = UnsafeRawPointer.init(bitPattern: "operationDictionary".hashValue)
    static let imageURLStorageKey = UnsafeRawPointer.init(bitPattern: "buttonImageURLStorageKey".hashValue)

}

typealias XMSetImageBlock = (UIImage?, NSData?) -> Void

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
extension UIView {
    var xm_imageURLStr: String? {
        return nil
    }
    var xm_imageURL: String? {
        return nil
    }
    func xm_internalSetImage(url: URLConvertible?, placeholder: UIImage?, options: XMWebImageOptions = [], operationKey: String?, setImageBlock: XMSetImageBlock?, progressBlock: XMWebImageDownloaderProgress?, completedBlock:XMExternalCompletion?, context: Dictionary<String,String>?) {

    }
    func xm_cancelCurrentImageLoad() {

    }
    func xm_showActivityIndicatorView(show: Bool) {

    }
    func xm_setIndicatorStyle(style: UIActivityIndicatorViewStyle) {

    }
    func xm_showActivityIndicatorView() -> Bool {
        return false

    }
    func xm_addActivityIndicator() {

    }
    func xm_removeActivityIndicator() {

    }
    func xm_setImageLoad(operation: Any?, forKey key: String?) {

    }
    func xm_cancelImageLoadOperation(withKey key: String?) {

    }
    func xm_removeImageLoadOperation(withKey key: String?) {

    }
    private var operationDictionary: Dictionary<String, Any> {
        var dict = objc_getAssociatedObject(self, RuntimeKey.operation!) as? Dictionary<String, Any>
        if dict == nil {
            dict = [:]
            objc_setAssociatedObject(self, RuntimeKey.operation!, dict!, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return dict!
    }





}













