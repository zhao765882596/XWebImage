//
//  XMWebImageManager.swift
//  Pods
//
//  Created by ming on 2017/11/23.
//

import Foundation
fileprivate class XMWebImageCombinedOperation: NSObject, XMWebImageOperation {
    var isCancelled = false
    private var _cancelBlock: XMWebImageNoParams?
    var cancelBlock: XMWebImageNoParams? {
        set {
            if isCancelled {
                _cancelBlock?()
                _cancelBlock = nil
            } else {
                _cancelBlock = newValue
            }
        }
        get {
            return _cancelBlock
        }
    }

    var cacheOperation: Operation?
    func cancel() {
        isCancelled = true
        if cacheOperation != nil {
            cacheOperation?.cancel()
            cacheOperation = nil
        } else {
            _cancelBlock?()
            cancelBlock = nil
        }

    }
}


public enum XMWebImageOption: Int {
    case retryFailed = 0
    case lowPriority = 1
    case cacheMemoryOnly = 2
    case progressiveDownload = 3
    case refreshCached = 4
    case continueInBackground = 5
    case handleCookies = 6
    case allowInvalidSSLCertificates = 7
    case highPriority  = 8
    case delayPlaceholder = 9
    case transformAnimatedImage = 10
    case avoidAutoSetImage = 11
    case scaleDownLargeImages = 12
}
public typealias XMWebImageOptions = Set<XMWebImageOption>
public typealias XMInternalCompletion = ((UIImage?, Data?, Error?, XMImageCacheType, Bool, URL?) -> Void)
public typealias XMExternalCompletion = ((UIImage?, Error?, XMImageCacheType, URL?) -> Void)
public typealias XMWebImageCacheKeyFilter = ((URL?) -> String?)

public protocol XMWebImageManagerDelegate: NSObjectProtocol {
    func shouldDownloadImage(_ manager: XMWebImageManager, forURL imageUrl: URL?) -> Bool
    func transformDownloaded(_ manager: XMWebImageManager, image: UIImage?, forURL imageUrl: URL?) -> UIImage?
}
extension XMWebImageManagerDelegate {
    func shouldDownloadImage(_ manager: XMWebImageManager, forURL imageUrl: URL?) -> Bool {
        return false

    }
    func transformDownloaded(_ manager: XMWebImageManager, image: UIImage?, forURL imageUrl: URL?) -> UIImage? {
        return nil
    }

}

public class XMWebImageManager {
    public static var shared = XMWebImageManager()
    public weak var delegate: XMWebImageManagerDelegate?
    private var _imageCache: XMImageCache!
    public var imageCache: XMImageCache {
        return _imageCache!
    }
    private var _imageDownloader: XMWebImageDownloader!
    public var imageDownloader: XMWebImageDownloader {
        return _imageDownloader!
    }
    public var cacheKeyFilter: XMWebImageCacheKeyFilter?

    private var failedURLs: Set<URL> = []
    private var runningOperations: Array<XMWebImageCombinedOperation> = []

    public init(cache: XMImageCache = XMImageCache.shared, downloader: XMWebImageDownloader = XMWebImageDownloader.shared) {
        _imageCache = cache
        _imageDownloader = downloader

    }
    public func cacheKey(url: URL?) -> String? {
        guard let cacheUrl = url else { return nil }
        if cacheKeyFilter != nil {
            return cacheKeyFilter?(cacheUrl)
        } else {
            return cacheUrl.absoluteString
        }
    }

    public func cachedImageExists(forURL url: URL?, completion: XMWebImageCheckCacheCompletion?) {
        let key = cacheKey(url: url) ?? ""
        if imageCache.imageFromCache(forKey: key) != nil {
            DispatchQueue.main.async {
                completion?(true)
            }
            return
        }
        imageCache.diskImageExists(forKey: key) { (isInDiskCache) in
            DispatchQueue.main.async {
                completion?(isInDiskCache)
            }
        }
    }
    public func diskImageExists(forURL url: URL?, completion: XMWebImageCheckCacheCompletion?) {
        let key = cacheKey(url: url) ?? ""
        imageCache.diskImageExists(forKey: key) { (isInDiskCache) in
            DispatchQueue.main.async {
                completion?(isInDiskCache)
            }
        }

    }
    @discardableResult
    public func loadImage(url: URL?, options: XMWebImageOptions, progress:XMWebImageDownloaderProgress?, completed: @escaping XMInternalCompletion) -> XMWebImageOperation {
        let operation = XMWebImageCombinedOperation()
        var isFailedUrl = false
        if url != nil {
            objc_sync_enter(failedURLs)
            isFailedUrl = failedURLs.contains(url!)
            objc_sync_exit(failedURLs)
        }

        if url == nil || url?.absoluteString.count == 0 || ( !options.contains(.retryFailed) && isFailedUrl) {
            callCompletion(operation: operation, completionBlock: completed, error: NSError.init(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: nil), url: url)
            return operation
        }
        objc_sync_enter(runningOperations)
        runningOperations.append(operation)
        objc_sync_exit(runningOperations)

        let key = cacheKey(url: url)
        weak var weakOperation = operation
        operation.cacheOperation = imageCache.queryCacheOperation(forKey: key ?? "", done: { [weak self](cachedImage, cachedData, cacheType) in
            guard let strongSelf = self else { return }

            if operation.isCancelled {
                self?.safelyRemoveOperationFromRunning(operation: operation)
                return
            }
            if (cachedImage == nil || options.contains(.refreshCached)) && (strongSelf.delegate == nil || strongSelf.delegate!.shouldDownloadImage(strongSelf, forURL: url)) {
                if cachedImage != nil && options.contains(.refreshCached) {
                    strongSelf.callCompletion(operation: weakOperation, completionBlock: completed, image: cachedImage, data: cachedData
                        , error: nil, cacheType: cacheType, finished: true, url: url)
                }
                var downloaderOptions:XMWebImageDownloaderOptions = Set<XMWebImageDownloaderOption>()
                if options.contains(.lowPriority) {
                    downloaderOptions.insert(.lowPriority)
                }
                if options.contains(.progressiveDownload) {
                    downloaderOptions.insert(.progressiveDownload)
                }
                if options.contains(.refreshCached) {
                    downloaderOptions.insert(.useNSURLCache)
                }
                if options.contains(.continueInBackground) {
                    downloaderOptions.insert(.continueInBackground)
                }
                if options.contains(.handleCookies) {
                    downloaderOptions.insert(.handleCookies)
                }
                if options.contains(.allowInvalidSSLCertificates) {
                    downloaderOptions.insert(.allowInvalidSSLCertificates)
                }
                if options.contains(.highPriority) {
                    downloaderOptions.insert(.highPriority)
                }
                if options.contains(.scaleDownLargeImages) {
                    downloaderOptions.insert(.scaleDownLargeImages)
                }
                if cachedImage != nil && options.contains(.refreshCached) {
                    downloaderOptions.remove(.progressiveDownload)
                    downloaderOptions.insert(.ignoreCachedResponse)
                }
                let subOperationToken = strongSelf.imageDownloader.downloadImage(url: url, options: downloaderOptions, progress: progress, completed: { (downloadedImage, downloadedData, error, isFinished) in
                    if weakOperation == nil || weakOperation?.isCancelled == true {

                    } else if error != nil {
                        strongSelf.callCompletion(operation: weakOperation, completionBlock: completed, error: error, url: url)
                        let nsError = error! as NSError
                        if (   nsError.code != NSURLErrorNotConnectedToInternet
                            && nsError.code != NSURLErrorCancelled
                            && nsError.code != NSURLErrorTimedOut
                            && nsError.code != NSURLErrorInternationalRoamingOff
                            && nsError.code != NSURLErrorDataNotAllowed
                            && nsError.code != NSURLErrorCannotFindHost
                            && nsError.code != NSURLErrorCannotConnectToHost
                            && nsError.code != NSURLErrorNetworkConnectionLost) {
                            objc_sync_enter(strongSelf.failedURLs)
                            strongSelf.failedURLs.insert(url!)
                            objc_sync_exit(strongSelf.failedURLs)
                        }

                    } else {
                        if options.contains(.retryFailed) {
                            objc_sync_enter(strongSelf.failedURLs)
                            strongSelf.failedURLs.remove(url!)
                            objc_sync_exit(strongSelf.failedURLs)
                        }
                        let cacheOnDisk = !options.contains(.cacheMemoryOnly)
                        if options.contains(.refreshCached) && cachedImage != nil && downloadedData == nil {

                        } else if downloadedImage != nil && (downloadedImage?.images == nil || options.contains(.transformAnimatedImage)) && strongSelf.delegate != nil {
                            DispatchQueue.global().async {
                                let transformedImage = strongSelf.delegate?.transformDownloaded(strongSelf, image: downloadedImage, forURL: url)
                                if transformedImage != nil && isFinished {
                                    let imageWasTransformed = !transformedImage!.isEqual(downloadedImage)
                                    strongSelf.imageCache.store(image: transformedImage, imageData: imageWasTransformed ? nil : downloadedData , forKey: key ?? "", toDisk: cacheOnDisk, completion: nil)
                                }
                                strongSelf.callCompletion(operation: operation, completionBlock: completed, image: transformedImage, data: downloadedData, error: nil, cacheType: .none, finished: isFinished, url: url)
                            }


                        } else {
                            if downloadedImage != nil && isFinished {
                                strongSelf.imageCache.store(image: downloadedImage, imageData: downloadedData, forKey: key ?? "", toDisk: cacheOnDisk, completion: nil)
                            }
                            strongSelf.callCompletion(operation: weakOperation, completionBlock: completed, image: downloadedImage, data: downloadedData, error: nil, cacheType: .none, finished: isFinished, url: url)
                        }
                    }
                    if isFinished {
                        strongSelf.safelyRemoveOperationFromRunning(operation: weakOperation)
                    }
                })
                objc_sync_enter(operation)
                operation.cancelBlock = {
                    strongSelf.imageDownloader.cancel(token: subOperationToken)
                    strongSelf.safelyRemoveOperationFromRunning(operation: operation)
                }
                objc_sync_exit(operation)
            } else if cachedImage != nil {
                strongSelf.callCompletion(operation: weakOperation, completionBlock: completed, image: cachedImage, data: cachedData, error: nil, cacheType: cacheType, finished: true, url: url)
                strongSelf.safelyRemoveOperationFromRunning(operation: operation)
            } else {
                strongSelf.callCompletion(operation: weakOperation, completionBlock: completed, image: nil, data: nil, error: nil, cacheType: .none, finished: true, url: url)
                strongSelf.safelyRemoveOperationFromRunning(operation: operation)
            }
        })

        return operation



    }
    public func saveImageToCache(image: UIImage?, forUrl url: URL?) {

        if image != nil && url != nil {
            let key = cacheKey(url: url) ?? ""
            imageCache.store(image: image, imageData: nil, forKey: key, toDisk: true, completion: nil)
        }
    }
    public func isRunning() -> Bool {
        var isRunning = false
        objc_sync_enter(runningOperations)
        isRunning = runningOperations.count > 0
        objc_sync_exit(runningOperations)
        return isRunning
    }
    public func cancelAll() {
        objc_sync_enter(runningOperations)
        for operation in runningOperations {
            operation.cancel()
        }
        runningOperations.removeAll()
        objc_sync_exit(runningOperations)
    }
    fileprivate func safelyRemoveOperationFromRunning(operation: XMWebImageCombinedOperation?) {
        if operation == nil {
            return
        }
        objc_sync_enter(runningOperations)
        if let index = runningOperations.index(of: operation!) {
            runningOperations.remove(at: index)
        }
        objc_sync_exit(runningOperations)
    }
    fileprivate func callCompletion(operation: XMWebImageCombinedOperation?, completionBlock: XMInternalCompletion?, error: Error?, url: URL?) {
        callCompletion(operation: operation, completionBlock: completionBlock, image: nil, data: nil, error: error, cacheType: .none, finished: true, url: url)

    }
    fileprivate func callCompletion(operation: XMWebImageCombinedOperation?, completionBlock: XMInternalCompletion?, image: UIImage?, data: Data?, error: Error?, cacheType:XMImageCacheType, finished: Bool, url: URL?) {
        DispatchQueue.main.async {
            if operation != nil && operation?.isCancelled == false && completionBlock != nil {
                completionBlock?(image, data, error, cacheType, finished, url)
            }
        }
    }

}
