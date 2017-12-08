//
//  UIImageView_WebCache.swift
//  XWebImage
//
//  Created by ming on 2017/11/30.
//

import Foundation
extension UIImageView {
    func xm_setImage(url: URLConvertible?, placeholder: UIImage? = nil, options: XMWebImageOptions = [], progressBlock: XMWebImageDownloaderProgress? = nil, completedBlock: XMExternalCompletion? = nil) {
        xm_internalSetImage(url: url, placeholder: placeholder, operationKey: nil, setImageBlock: nil, progressBlock: progressBlock, completedBlock: completedBlock)
    }
    func xm_setImageWithPreviousCachedImage(url: URLConvertible?, placeholder: UIImage? = nil, options: XMWebImageOptions = [], progressBlock: XMWebImageDownloaderProgress? = nil, completedBlock: XMExternalCompletion? = nil) {
        let key = XMWebImageManager.shared.cacheKey(url: url?.asURL())
        let lastPreviousCachedImage = XMImageCache.shared.imageFromCache(forKey: key ?? "")

        xm_internalSetImage(url: url, placeholder: lastPreviousCachedImage ?? placeholder, operationKey: nil, setImageBlock: nil, progressBlock: progressBlock, completedBlock: completedBlock)
    }
    func xm_setAnimationImages(urls: Array<URL>) {
        xm_cancelCurrentAnimationImagesLoad()
        var operationsArray: Array<XMWebImageOperation> = []

        for i in 0 ..< urls.count {
            let operation = XMWebImageManager.shared.loadImage(url: urls[i], options: [], progress: nil, completed: {[weak self] (image, data, error, cacheType, isFinished, imageUrl) in
                guard let sself = self else { return }
                DispatchQueue.main.async {
                    sself.stopAnimating()
                    if image != nil {
                        if sself.animationImages == nil {
                            sself.animationImages = []
                        }
                        while sself.animationImages!.count < i {
                            sself.animationImages?.append(image!)
                        }
                        sself.animationImages?[i] = image!
                        sself.setNeedsLayout()
                    }
                    sself.stopAnimating()
                }


            })
            operationsArray.append(operation)
        }
        xm_setImageLoad(operation: operationsArray, forKey: "UIImageViewAnimationImages")
    }
    func xm_cancelCurrentAnimationImagesLoad() {
        xm_cancelImageLoadOperation(withKey: "UIImageViewAnimationImages")
    }
    func xm_setHighlightedImage(url: URLConvertible?, options: XMWebImageOptions = [], progressBlock: XMWebImageDownloaderProgress? = nil, completedBlock: XMExternalCompletion? = nil) {
        xm_internalSetImage(url: url, placeholder: nil, options: options, operationKey: "UIImageViewImageOperationHighlighted", setImageBlock: {[weak self] (image, imageData) in
            self?.highlightedImage = image
        }, progressBlock: progressBlock, completedBlock: completedBlock)
    }



}
