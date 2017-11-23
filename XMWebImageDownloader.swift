//
//  XMWebImageDownloader.swift
//  Pods
//
//  Created by ming on 2017/11/23.
//

import Foundation
public enum XMWebImageDownloaderOptions: Int {
    case lowPriority = 0
    case progressiveDownload = 1
    case useNSURLCache = 2
    case ignoreCachedResponse = 3
    case continueInBackground = 4
    case handleCookies = 5
    case allowInvalidSSLCertificates = 6
    case highPriority = 7
    case scaleDownLargeImages = 8

}
public enum XMWebImageDownloaderExecutionOrder: Int {
    case FIFO = 0
    case LIFO = 1
}

public typealias XMWebImageDownloaderProgress = ((Int, Int, URL?) -> Void)?
public typealias XMInternalCompletion = ((UIImage?, Data?, Error?, XMImageCacheType, Bool, URL?) -> Void)?
public typealias XMHTTPHeadersDictionary = Dictionary<String, String>
public typealias XMWebImageDownloaderHeadersFilter = ((URL?, XMHTTPHeadersDictionary?) -> Void)?

public class XMWebImageDownloadToken {
    var url: URL?
    var downloadOperationCancelToken: Any?
}

public class XMWebImageDownloader {
    static public var shared = XMWebImageDownloader()
    public var maxConcurrentDownloads = 0
    public var currentDownloadCount = 0
    public var shouldDecompressImages = true
    public var downloadTimeout: TimeInterval = 15.0
    private var _sessionConfiguration = URLSessionConfiguration.default

    public var sessionConfiguration: URLSessionConfiguration {
        return _sessionConfiguration
    }
    public var executionOrder:XMWebImageDownloaderExecutionOrder = .FIFO

    public var urlCredential: URLCredential?

    public var username = ""
    public var password = ""
    public var headersFilter: XMWebImageDownloaderHeadersFilter?
    public init(sessionConfiguration: URLSessionConfiguration = .default) {
        _sessionConfiguration = sessionConfiguration
    }
    public func set(value: String?, forHTTPHeaderField field: String?) {


    }
    public func value(forHTTPHeaderField field: String?) -> String? {
        return nil

    }
    public func set(operation: String?) {


    }
    public func loadImage(url: URL?, options: XMWebImageOptions, progress:XMWebImageDownloaderProgress, completed: XMInternalCompletion)-> XMWebImageDownloadToken? {
        return nil
    }
    public func cancel(token: XMWebImageDownloadToken?) {

    }
    public func set(suspended: Bool) {

    }
    public func cancelAllDownloads() {

    }
    public func createNewSession(sessionConfiguration: URLSessionConfiguration?) {

    }










}
