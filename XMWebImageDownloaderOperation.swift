//
//  XMWebImageDownloaderOperation.swift
//  Pods-XWebImage_Example
//
//  Created by ming on 2017/11/28.
//

import Foundation

protocol XMWebImageDownloaderOperationInterface: XMWebImageOperation {
    init?(request: URLRequest?, session: URLSession?, options: XMWebImageDownloaderOptions)
    var shouldDecompressImages: Bool {set get}
    var credential: URLCredential? {set get}
}
extension XMWebImageDownloaderOperationInterface {

}
protocol XMWebImageOperation: NSObjectProtocol {
    func cancel()
}
class XMWebImageDownloaderOperation:Operation, XMWebImageDownloaderOperationInterface,URLSessionDataDelegate  {
    var shouldDecompressImages: Bool {
        set {}
        get {
            return true
        }
    }
    var credential: URLCredential? {
        set {}
        get {
            return nil
        }
    }
    var dataTask: URLSessionTask?



    required init?(request: URLRequest?, session: URLSession?, options: XMWebImageDownloaderOptions) {
        
    }
    func cancel(token:XMWebImageDownloadToken?) -> Bool {
        return false
    }
    func addHandlers(progressBlock:XMWebImageDownloaderProgress?, completed: SDWebImageDownloaderCompleted?) -> Dictionary<String, Any> {
        return [:]
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {

    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

    }

     public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    }


}
