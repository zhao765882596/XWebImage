//
//  XMWebImageManager.swift
//  Pods
//
//  Created by ming on 2017/11/23.
//

import Foundation
public enum XMWebImageOptions: Int {
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
    case aAoidAutoSetImage = 11
    case scaleDownLargeImages = 12
}

public typealias XMInternalCompletion = ((UIImage?, Data?, Error?, XMImageCacheType, Bool, URL?) -> Void)



public class XMWebImageManager {
    static var shared = XMWebImageManager()
    public var imageDownloader = XMWebImageDownloader()
    public func cancelAll() {

    }
    public func loadImage(url: URL?, options: XMWebImageOptions, progress:XMWebImageDownloaderProgress?, completed: XMInternalCompletion?) {

    }
    public func cacheKey(url: URL?) -> String? {
        return ""
    }

    
}
