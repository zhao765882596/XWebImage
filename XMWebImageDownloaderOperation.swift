//
//  XMWebImageDownloaderOperation.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/28.
//

import Foundation

public protocol XMWebImageDownloaderOperationInterface: NSObjectProtocol {
    init?(request: URLRequest?, session: URLSession?, options: XMWebImageDownloaderOptions)
    func addHandlers(forURL url: URL?, progressBlock:XMWebImageDownloaderProgress?, completed: XMWebImageDownloaderCompleted?) -> XMWebImageDownloadToken?

    var shouldDecompressImages: Bool {set get}
    var credential: URLCredential? {set get}
}
extension XMWebImageDownloaderOperationInterface {

}
let ProgressCallbackKey = "progress"
let CompletedCallbackKey = "completed"

public class XMWebImageDownloaderOperation:Operation, XMWebImageDownloaderOperationInterface,URLSessionDataDelegate  {
    private var _shouldDecompressImages = true
    public var shouldDecompressImages: Bool {
        set {
            _shouldDecompressImages = newValue
        }
        get {
            return _shouldDecompressImages
        }
    }
    private var _credential: URLCredential?

    public var credential: URLCredential? {
        set {
            _credential = newValue
        }
        get {
            return _credential
        }
    }
    private var _dataTask: URLSessionTask?

    public var dataTask: URLSessionTask?{
        return _dataTask
    }
    private var _request: URLRequest?

    public var request: URLRequest?{
        return _request
    }
    private var _optionst: XMWebImageDownloaderOptions = .lowPriority

    public var options: XMWebImageDownloaderOptions{
        return _optionst
    }
    public var expectedSize = 0
    public var response:URLResponse?
    private var tokens: Array<XMWebImageDownloadToken> = []
    private var imageData: Data?
    private var cachedData: Data?
    private var _executing = false
    private var _finished = false

    private weak var unownedSession: URLSession?
    private var ownedSession: URLSession?
    private var barrierQueue = DispatchQueue.init(label: "com.ming.XMWebImageDownloaderOperationBarrierQueue")
    private var backgroundTaskId =  UIBackgroundTaskInvalid
    private var progressiveCoder: XMWebImageProgressiveCoder?



    required public init?(request: URLRequest?, session: URLSession?, options: XMWebImageDownloaderOptions) {
        _request = request
        _optionst = options
        unownedSession = session
    }


    public func addHandlers(forURL url: URL?,progressBlock:XMWebImageDownloaderProgress?, completed: XMWebImageDownloaderCompleted?) -> XMWebImageDownloadToken? {
        guard let loadUrl = url else { return nil }
        let token = XMWebImageDownloadToken()
        token.url = loadUrl
        var callbacks: Dictionary<String, Any> = [:]
        if progressBlock != nil {
            callbacks[ProgressCallbackKey] = progressBlock!
        }
        if completed != nil {
            callbacks[CompletedCallbackKey] = completed!
        }
        token.downloadOperationCancelToken = callbacks
        barrierQueue.sync(flags: .barrier) {
            self.tokens.append(token)
        }
        return token
    }
    func callbacks(forKey key: String) -> Array<Any> {
        var callbacks: Array<Any> = []
        barrierQueue.sync {
            for callbackBlock in self.tokens {
                guard let callback = callbackBlock.downloadOperationCancelToken?[key] else {
                    continue
                }
                callbacks.append(callback)
            }
        }
        return callbacks
    }
    public func cancel(token: XMWebImageDownloadToken?) -> Bool {
        guard let cancelToken = token else { return false }
        var shouldCancel = false
        barrierQueue.sync(flags: .barrier) {
            for i in 0 ..< self.tokens.count {
                if self.tokens[i].url == cancelToken.url {
                    self.tokens.remove(at: i)
                }
            }
            if self.tokens.count == 0 {
                shouldCancel = true
            }
        }
        if shouldCancel {
            cancel()
        }
        return shouldCancel
    }
    public override func start() {
        if isCancelled {
            _finished = true
            reset()
            return
        }
        if options == .continueInBackground {
            backgroundTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: {[weak self] in

                self?.cancel()
                UIApplication.shared.endBackgroundTask(self?.backgroundTaskId ?? UIBackgroundTaskInvalid)
                self?.backgroundTaskId = UIBackgroundTaskInvalid
            })
        }
        if options == .ignoreCachedResponse && self.request != nil {
            let cachedResponse = URLCache.shared.cachedResponse(for: self.request!)
            if cachedResponse != nil {
                self.cachedData = cachedResponse?.data
            }
        }
        var session = self.unownedSession

        if session == nil {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 15
            unownedSession = URLSession.init(configuration: sessionConfig, delegate: self, delegateQueue: nil)
            session = unownedSession
        }
        if request != nil {
            _dataTask = session?.dataTask(with: request!)
            _executing = true
        }
        dataTask?.resume()
        if dataTask != nil {
            for callback in callbacks(forKey: ProgressCallbackKey) {
                (callback as? XMWebImageDownloaderProgress)?(0, Int.max, request?.url)
            }
        } else {
            callCompletionBlocks(image: nil, imageData: nil, error: NSError.init(domain: NSURLErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Connection can't be initialized"]),isFinished: true)
        }
        if backgroundTaskId != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = UIBackgroundTaskInvalid
        }
    }

    public override func cancel() {
        if _finished {
            return
        }
        super.cancel()
        if dataTask != nil {
            dataTask?.cancel()
        }
        if _executing {
            _executing = false
        }
        if _finished == false {
            _finished = true
        }
        reset()
    }
    func done() {
        _executing = false
        _finished = true
        reset()
    }
    func reset() {
        barrierQueue.sync(flags: .barrier) {
            self.tokens.removeAll()
        }
        _dataTask = nil
        var delegateQueue: OperationQueue?
        if unownedSession != nil {
            delegateQueue = unownedSession?.delegateQueue
        } else {
            delegateQueue = ownedSession?.delegateQueue
        }
        if delegateQueue != nil {
            assert(delegateQueue?.maxConcurrentOperationCount == 1, "NSURLSession delegate queue should be a serial queue")
            delegateQueue?.addOperation {[weak self] in
                self?.imageData = nil
            }
        }
        if ownedSession != nil {
            ownedSession?.invalidateAndCancel()
            ownedSession = nil
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode < 400 && httpResponse.statusCode != 304) else {
            let expected = response.expectedContentLength > 0 ? response.expectedContentLength : 0
            expectedSize = Int(expected)
            self.imageData = Data.init(count: expectedSize)

            for callback in callbacks(forKey: ProgressCallbackKey) {
                (callback as? XMWebImageDownloaderProgress)?(0, expectedSize, request?.url)
            }
            self.response = response
            completionHandler(.allow)
            return
        }
        if httpResponse.statusCode == 304 {
            cancel()
        } else {
            dataTask.cancel()
        }
        callCompletionBlocks(image: nil, imageData: nil, error: NSError.init(domain: NSURLErrorDomain, code: httpResponse.statusCode, userInfo: nil),isFinished: true)
        done()
        completionHandler(.allow)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if imageData == nil {
            imageData = Data()
        }
        imageData?.append(data)
        if options == .progressiveDownload && expectedSize > 0 {
            if progressiveCoder == nil {
                for coder in XMWebImageCodersManager.shared.coders {
                    if coder is XMWebImageProgressiveCoder && (coder as? XMWebImageProgressiveCoder)?.canIncrementallyDecode(data: imageData) == true {
                        self.progressiveCoder = coder as? XMWebImageProgressiveCoder
                        break
                    }
                }
            }
            var image = self.progressiveCoder?.incrementallyDecodedImage(data: imageData, isFinished: imageData!.count >= expectedSize)
            if image != nil {
                let key = XMWebImageManager.shared.cacheKey(url: request?.url)
                image = XMImageCache.shared.scaled(image: image, forKey: key ?? "")
                if shouldDecompressImages {
                    var imageData = data
                    image = XMWebImageCodersManager.shared.decompressed(image: image, data: &imageData, options: [XMWebImageCoderScaleDownLargeImagesKey: false])
                }
                callCompletionBlocks(image: image, imageData: nil, error: nil, isFinished: false)
            }
        }

        for callback in callbacks(forKey: ProgressCallbackKey) {
            (callback as? XMWebImageDownloaderProgress)?(imageData?.count ?? 0, expectedSize, request?.url)
        }
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {

        var cachedResponse: CachedURLResponse? = proposedResponse

        if request?.cachePolicy == NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData {
            cachedResponse = nil
        }
        completionHandler(cachedResponse)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            callCompletionBlocks(image: nil, imageData: nil, error: error, isFinished: true)
        } else {
            if callbacks(forKey: CompletedCallbackKey).count > 0 {
                if imageData != nil {
                    if options == .ignoreCachedResponse && cachedData == imageData {
                        callCompletionBlocks(image: nil, imageData: nil, error: nil, isFinished: true)
                    } else {
                        var image = XMWebImageCodersManager.shared.decodedImage(data: imageData)
                        let key = XMWebImageManager.shared.cacheKey(url: request?.url)
                        image = XMImageCache.shared.scaled(image: image, forKey: key ?? "")
                        let shouldDecode = image?.images != nil ? false : true
                        if shouldDecode {
                            if shouldDecompressImages {
                                image = XMWebImageCodersManager.shared.decompressed(image: image, data: &imageData!, options: [XMWebImageCoderScaleDownLargeImagesKey: options == .scaleDownLargeImages])
                            }
                        }
                        if image?.size == CGSize.zero {
                            callCompletionBlocks(image: nil, imageData: nil, error: NSError.init(domain: "XMWebImageErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey : "Image data is nil"]), isFinished: true)
                        } else {
                            callCompletionBlocks(image: image, imageData: imageData, error: nil, isFinished: true)
                        }
                    }
                } else {
                    callCompletionBlocks(image: nil, imageData: nil, error: NSError.init(domain: "XMWebImageErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey : "Image data is nil"]), isFinished: true)
                }
            }

        }
        done()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var disposition = URLSession.AuthChallengeDisposition.performDefaultHandling
        var credential: URLCredential?
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if options != .allowInvalidSSLCertificates {
                disposition = .performDefaultHandling
            } else {
                if challenge.protectionSpace.serverTrust != nil {
                    credential = URLCredential.init(trust: challenge.protectionSpace.serverTrust!)
                }
                disposition = .useCredential
            }
        } else {
            if challenge.previousFailureCount == 0 {
                if self.credential != nil {
                    credential = self.credential
                    disposition = .useCredential
                } else {
                    disposition = .cancelAuthenticationChallenge
                }
            } else {
                disposition = .cancelAuthenticationChallenge
            }
        }
        completionHandler(disposition, credential)
    }
    func callCompletionBlocks(image: UIImage?, imageData: Data?, error: Error?, isFinished: Bool) {
        DispatchQueue.main.async {
            for callback in self.callbacks(forKey: CompletedCallbackKey) {
                (callback as? XMWebImageDownloaderCompleted)?(image, imageData, error, isFinished)
            }
        }
    }


}
