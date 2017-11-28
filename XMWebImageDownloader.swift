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

public typealias XMWebImageDownloaderProgress = ((Int, Int, URL?) -> Void)
public typealias SDWebImageDownloaderCompleted = ((UIImage?, Data?, Error?, Bool) -> Void)
public typealias XMHTTPHeadersDictionary = Dictionary<String, String>
public typealias XMWebImageDownloaderHeadersFilter = ((URL?, XMHTTPHeadersDictionary?) -> XMHTTPHeadersDictionary?)

public class XMWebImageDownloadToken {
    var url: URL?
    var downloadOperationCancelToken: Any?
}

public class XMWebImageDownloader: NSObject, URLSessionDataDelegate {
    static public var shared = XMWebImageDownloader()
    public var maxConcurrentDownloads = 6 {
        didSet {
            if maxConcurrentDownloads != oldValue {
                downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads
            }
        }
    }
    public var currentDownloadCount: Int {
        return downloadQueue.operationCount
    }
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
    private var downloadQueue: OperationQueue = OperationQueue()
    private var lastAddedOperation: Operation?
    private var operationClass: AnyClass = XMWebImageDownloaderOperation.classForCoder()
    private var URLOperations: Dictionary<URL, XMWebImageDownloaderOperation> = [:]
    private var HTTPHeaders: XMHTTPHeadersDictionary = ["Accept": "image/*;q=0.8"]
    lazy private var barrierQueue: DispatchQueue = DispatchQueue.init(label: "com.ming.XMWebImageDownloaderBarrierQueue")
    private var session: URLSession?


    public init(sessionConfiguration: URLSessionConfiguration = .default) {
        super.init()
        _sessionConfiguration = sessionConfiguration
        downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads
        downloadQueue.name = "com.ming.XMWebImageDownloader"
        createNewSession(sessionConfiguration: sessionConfiguration)
    }
    deinit {
        session?.invalidateAndCancel()
        session = nil
        downloadQueue.cancelAllOperations()
    }
    public func createNewSession(sessionConfiguration: URLSessionConfiguration) {
        self.cancelAllDownloads()
        if session != nil {
            session?.invalidateAndCancel()
        }
        sessionConfiguration.timeoutIntervalForRequest = downloadTimeout
        session = URLSession.init(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }

    public func set(value: String?, forHTTPHeaderField field: String?) {
        guard let key = field, key.count > 0 else { return }
        if value != nil {
            HTTPHeaders[key] = value!
        } else {
            HTTPHeaders.removeValue(forKey: key)
        }
    }
    public func value(forHTTPHeaderField field: String?) -> String? {
        guard let key = field, key.count > 0 else { return nil }
        return HTTPHeaders[key]
    }
    public func set(operationClass: AnyClass?) {
        guard let operation = operationClass else { return }
        if operation.isSubclass(of: Operation.self) && (operation is XMWebImageDownloaderOperationInterface.Type) {
            self.operationClass = operation
        } else {
            self.operationClass = XMWebImageDownloaderOperation.classForCoder()
        }
    }

    public func cancel(token: XMWebImageDownloadToken?) {
        guard let cancelToken = token, cancelToken.url != nil else { return }
        barrierQueue.async {
            let operation = self.URLOperations[cancelToken.url!]
            if operation?.cancel(token: cancelToken) == true {
                self.URLOperations.removeValue(forKey: cancelToken.url!)
            }
        }
    }
    public func set(isSuspended: Bool) {
        downloadQueue.isSuspended = isSuspended
    }
    public func cancelAllDownloads() {
        downloadQueue.cancelAllOperations()
    }
    public func loadImage(url: URL?, options: XMWebImageDownloaderOptions, progress:XMWebImageDownloaderProgress?, completed: SDWebImageDownloaderCompleted?) -> XMWebImageDownloadToken? {
        guard let loadUrl = url else { return  nil}

        return addProgressCallback(progress: progress, completed: completed, forURL: loadUrl, createCallback: {[weak self] () -> XMWebImageDownloaderOperationInterface? in
            var timeoutInterval = self?.downloadTimeout ?? 0.0
            if timeoutInterval <= 0.0 {
                timeoutInterval = 15.0
            }
            let cachePolicy = options == .useNSURLCache ? NSURLRequest.CachePolicy.useProtocolCachePolicy : NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
            var request = URLRequest.init(url: loadUrl, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
            request.httpShouldHandleCookies = (options == .handleCookies)
            request.httpShouldUsePipelining = true
            if self?.headersFilter != nil {
                request.allHTTPHeaderFields = self?.headersFilter!(loadUrl, self?.HTTPHeaders)
            } else {
                request.allHTTPHeaderFields = self?.HTTPHeaders
            }
            let operation = (self?.operationClass as! XMWebImageDownloaderOperationInterface.Type).init(request: request, session: self?.session, options: options)
            operation?.shouldDecompressImages = self?.shouldDecompressImages ?? false
            if self?.urlCredential != nil {
                operation?.credential = self?.urlCredential
            } else if self?.username != nil && self?.password != nil && self!.username.count > 0 && self!.password.count > 0 {
                operation?.credential = URLCredential.init(user: self!.username, password: self!.password, persistence: URLCredential.Persistence.forSession)
            }
            if operation is Operation {
                let operation1 = operation as! Operation

                if options == .highPriority {
                    operation1.queuePriority = .high
                } else if options == .lowPriority  {
                    operation1.queuePriority = .low
                }
                self?.downloadQueue.addOperation(operation1)
                if self?.executionOrder == .LIFO {
                    self?.lastAddedOperation?.addDependency(operation1)
                    self?.lastAddedOperation = operation1
                }
            }
            return operation
        })
    }
    private func addProgressCallback(progress:XMWebImageDownloaderProgress?, completed: SDWebImageDownloaderCompleted?, forURL url: URL?, createCallback: (() -> XMWebImageDownloaderOperationInterface?)?) -> XMWebImageDownloadToken?{
        guard let loadUrl = url else {
            if completed != nil {
                completed!(nil, nil, nil, false)
            }
            return nil
        }
        var token: XMWebImageDownloadToken?

        barrierQueue.sync(flags: .barrier) {
            var operation = self.URLOperations[loadUrl]
            if operation == nil {
                operation = createCallback?() as? XMWebImageDownloaderOperation
                if operation != nil {
                    self.URLOperations[loadUrl] = operation!
                    weak var weakOperation = operation
                    operation?.completionBlock = { [weak self] in
                        self?.barrierQueue.sync(flags: .barrier) {
                            let strongOperation = weakOperation
                            if strongOperation == nil {
                                return
                            }
                            if self?.URLOperations[loadUrl] == strongOperation {
                                self?.URLOperations.removeValue(forKey: loadUrl)
                            }
                        }
                    }
                }
            }
            token = XMWebImageDownloadToken()
            token?.url = loadUrl
            token?.downloadOperationCancelToken =  operation?.addHandlers(progressBlock: progress, completed: completed)
        }
        return token
    }
    func operation(task: URLSessionTask) -> XMWebImageDownloaderOperation? {
        for operation in self.downloadQueue.operations {
            let downloaderOperation = operation as? XMWebImageDownloaderOperation
            if downloaderOperation?.dataTask?.taskIdentifier == task.taskIdentifier {
                return downloaderOperation
            }
        }
        return nil
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        operation(task: dataTask)?.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        operation(task: dataTask)?.urlSession(session, dataTask: dataTask, didReceive: data)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        operation(task: dataTask)?.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        operation(task: task)?.urlSession(session, task: task, didCompleteWithError: error)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        operation(task: task)?.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }










}
