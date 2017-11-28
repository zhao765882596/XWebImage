//
//  XMWebImagePrefetcher.swift
//  Pods
//
//  Created by ming on 2017/11/23.
//

import Foundation

public protocol XMWebImagePrefetcherDelegate {
    func image(Prefetcher: XMWebImagePrefetcher, didPrefetchURL url: URL, finishedCount: Int, totalCount: Int)
    func image(Prefetcher: XMWebImagePrefetcher,  didFinishWithTotalCount count: Int, skippedCount: Int)
}
extension XMWebImagePrefetcherDelegate {
    public func image(Prefetcher: XMWebImagePrefetcher, didPrefetchURL url: URL, finishedCount: Int, totalCount: Int) {}
    public func image(Prefetcher: XMWebImagePrefetcher,  didFinishWithTotalCount count: Int, skippedCount: Int) {}
}

public typealias SDWebImagePrefetcherCompletion = ((Int, Int) -> Void)
public typealias SDWebImagePrefetcherProgress = ((Int, Int) -> Void)

public class XMWebImagePrefetcher {
    public static let shared = XMWebImagePrefetcher.init(manager: XMWebImageManager())

    public var manager:XMWebImageManager {
        return _manager
    }
    private var _manager:XMWebImageManager!

    public var maxConcurrentDownloads: Int {
        set {
            manager.imageDownloader.maxConcurrentDownloads = newValue
        }
        get {
            return manager.imageDownloader.maxConcurrentDownloads

        }
    }
    public var options:XMWebImageOptions = .lowPriority
    public var prefetcherQueue = DispatchQueue.main
    public var delegate: XMWebImagePrefetcherDelegate?

    private var prefetchURLs: Array<URL> = []
    private var requestedCount = 0
    private var skippedCount = 0
    private var finishedCount = 0
    private var startedTime: TimeInterval = 0
    private var completion: SDWebImagePrefetcherCompletion?
    private var progress: SDWebImagePrefetcherProgress?



    public init(manager: XMWebImageManager) {
        _manager = manager
        maxConcurrentDownloads = 3
    }

    public func prefetch(URLs: Array<URL>?, progress: SDWebImagePrefetcherProgress? = nil, completed: SDWebImagePrefetcherCompletion? = nil) {
        cancelPrefetching()
        startedTime = CFAbsoluteTimeGetCurrent()
        prefetchURLs = URLs ?? []
        self.completion = completed
        self.progress = progress
        guard let urls = URLs, urls.count > 0 else {
            if completed != nil {
                completed!(0, 0)
            }
            return
        }
        for i in 0 ..< urls.count {
            if i < maxConcurrentDownloads && requestedCount < urls.count {
                startPrefetching(index: i)
            }
        }
    }
    public func cancelPrefetching() {
        prefetchURLs.removeAll()
        skippedCount = 0
        requestedCount = 0
        finishedCount = 0
        manager.cancelAll()
    }

    func startPrefetching(index: Int) {
        if index >= prefetchURLs.count {
            return
        }
        requestedCount = requestedCount + 1
        manager.loadImage(url: prefetchURLs[index], options: options, progress: nil) { (image, imageData, error, cacheType, isFinished, imageURL) in
            if !isFinished { return }
            self.finishedCount = self.finishedCount + 1
            if self.progress != nil {
                self.progress!(self.finishedCount, self.prefetchURLs.count)
            }
            if image == nil {
                self.skippedCount = self.skippedCount + 1
            }
            self.delegate?.image(Prefetcher: self, didPrefetchURL: self.prefetchURLs[index], finishedCount: self.finishedCount, totalCount: self.prefetchURLs.count)
            if self.prefetchURLs.count > self.requestedCount {
                self.prefetcherQueue.async {
                    self.startPrefetching(index: self.requestedCount)
                }
            } else if self.finishedCount == self.requestedCount{
                self.delegate?.image(Prefetcher: self, didFinishWithTotalCount: self.prefetchURLs.count - self.skippedCount, skippedCount: self.skippedCount)
                if self.completion != nil {
                    self.completion!(self.finishedCount, self.skippedCount)
                    self.completion = nil
                }
                self.progress = nil
            }
        }
    }
}
