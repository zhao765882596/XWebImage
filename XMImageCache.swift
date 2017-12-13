
//
//  XMImageCache.swift
//  Pods
//
//  Created by ming on 2017/11/21.
//

import Foundation

public enum XMImageCacheType: Int {

    /// The image wasn't available the SDWebImage caches, but was downloaded from the web.
    case none = 0
    /// The image was obtained from the disk cache.
    case disk = 1
    /// The image was obtained from the memory cache.
    case memory = 2

}
public typealias XMCacheQueryCompleted = ((UIImage?, Data?, XMImageCacheType) -> Void)
public typealias XMWebImageCheckCacheCompletion = ((Bool) -> Void)
public typealias XMWebImageCalculateSize = ((Int, Int) -> Void)
public typealias XMWebImageNoParams = (() -> Void)


class AutoPurgeCache: NSCache<AnyObject, AnyObject> {

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeAllObjects), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }
}

/// XMImageCache maintains a memory cache and an optional disk cache. Disk cache write operations are performed asynchronous so it doesn’t add unnecessary latency to the UI.
public class XMImageCache {
    public static var shared = XMImageCache("default")
    private var _config = XMImageCacheConfig()
    /// Cache Config object - storing all kind of settings
    public var config: XMImageCacheConfig {
        return _config
    }
    /// The maximum "total cost" of the in-memory image cache. The cost function is the number of pixels held in memory.
    public var maxMemoryCost: Int {
        set {
            memCache.totalCostLimit = newValue
        }
        get {
            return memCache.totalCostLimit
        }
    }
    /// The maximum number of objects the cache should hold
    public var maxMemoryCountLimit: Int {
        set {
            memCache.countLimit = newValue
        }
        get {
            return memCache.countLimit
        }
    }
    private var customPaths: Array<String> = []
    private var memCache: NSCache<AnyObject, AnyObject> = AutoPurgeCache()
    private var diskCachePath = ""
    private var ioQueue: DispatchQueue = DispatchQueue.init(label: "com.hackemist.SDWebImageCache")
    private var fileManager = FileManager()


    public init(_ namespace: String, directory: String = "") {
        let fullNamespace = "com.hackemist.SDWebImageCache." + namespace
        memCache.name = fullNamespace
        if directory.isEmpty {
            diskCachePath = makeDiskCache(fullNamespace: fullNamespace)
        } else {
            diskCachePath = directory + "/\(fullNamespace)"
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.clearMemory), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.deleteOldFiles(_:)), name: NSNotification.Name.UIApplicationWillTerminate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.backgroundDeleteOldFiles), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
// MARK: - Cache paths
    public func addReadOnlyCache(path: String) {
        if path.isEmpty {
            return
        }
        if !customPaths.contains(path) {
            customPaths.append(path)
        }
    }
    public func cachePath(forKey key: String, inPath path: String? = nil) -> String {
        var filePath = ""
        if path == nil || path?.isEmpty == true {
            filePath = diskCachePath
        } else {
            filePath = path!
        }
        return filePath + "/\(key.md5)"
    }
    public func defaultCachePath(forKey key: String) -> String {
        return cachePath(forKey: key, inPath: diskCachePath)
    }
    public func makeDiskCache(fullNamespace: String) -> String {
       return  NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] + "/\(fullNamespace)"
    }
// MARK: - Store Ops

    public func store(image: UIImage? = nil,imageData:Data? = nil, forKey key: String, toDisk:Bool = true, completion: XMWebImageNoParams?) {
        func callHandlerInMainQueue() {
            if let handler = completion {
                DispatchQueue.main.async {
                    handler()
                }
            }
        }
        guard let storeImage = image else {
            callHandlerInMainQueue()
            return
        }
        if key.isEmpty {
            callHandlerInMainQueue()
            return
        }
        if config.shouldCacheImagesInMemory {
            memCache.setObject(storeImage, forKey: key as AnyObject, cost: cacheCostForImage(image: storeImage))
        }
        if toDisk {
            ioQueue.async {
                autoreleasepool(invoking: { () -> Void in
                    var data = imageData
                    if data == nil {
                        data = XMWebImageCodersManager.shared.encodedData(image: storeImage, format: .PNG)
                    }
                    self.storeDisk(imageData: data, forKey: key)
                    callHandlerInMainQueue()
                })
            }
        } else {
            callHandlerInMainQueue()
        }
    }
    func cacheCostForImage(image: UIImage) -> Int {
        return Int(image.size.width * image.size.height * image.scale * image.scale)

    }
    public func storeDisk(imageData: Data?, forKey key: String) {
        guard let data = imageData else {
            return
        }
        if key.isEmpty {
            return
        }

        if !fileManager.fileExists(atPath: diskCachePath) {
            try? fileManager.createDirectory(atPath: diskCachePath, withIntermediateDirectories: true, attributes: nil)
        }
        let cachePath = defaultCachePath(forKey: key)
        fileManager.createFile(atPath: cachePath, contents: data, attributes: nil)

        if config.shouldDisableiCloud {
            var fileURL = URL.init(fileURLWithPath: cachePath)
            fileURL.setTemporaryResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        }
    }

    public func diskImageExists(forKey key: String, completion: XMWebImageCheckCacheCompletion? = nil) {

        ioQueue.async {
            var exists = self.fileManager.fileExists(atPath: self.defaultCachePath(forKey: key))
            if !exists {
                exists = self.fileManager.fileExists(atPath: (self.defaultCachePath(forKey: key) as NSString).deletingPathExtension)
            }
            if completion != nil {
                completion!(exists)
            }
        }

    }
    public func imageFromMemoryCache(forKey key: String) -> UIImage? {
        return memCache.object(forKey: key as AnyObject) as? UIImage
    }
    public func imageFromDiskCache(forKey key: String) -> UIImage? {
        let image = diskImage(forKey: key)
        if image != nil && config.shouldCacheImagesInMemory {
            self.memCache.setObject(image!, forKey: key as AnyObject, cost: self.cacheCostForImage(image: image!))
        }
        return image
    }

    public func imageFromCache(forKey key: String) -> UIImage? {
        var image = imageFromMemoryCache(forKey: key)
        if image != nil {
            return image
        }
        image = imageFromDiskCache(forKey: key)
        return image
    }
    func diskImageDataBySearchingAllPaths(forKey key: String) -> Data? {
        let defaultPath = defaultCachePath(forKey: key)
        var data: Data? = nil
        data = try? Data.init(contentsOf: URL.init(fileURLWithPath: defaultPath), options: config.diskCacheReadingOptions)
        if data != nil {
            return data
        }
        data = try? Data.init(contentsOf: URL.init(fileURLWithPath: (defaultPath as NSString).deletingPathExtension), options: config.diskCacheReadingOptions)

        if data != nil {
            return data
        }
        for path in customPaths {
            let filePath = cachePath(forKey: key, inPath: path)
            data = try? Data.init(contentsOf: URL.init(fileURLWithPath: filePath), options: config.diskCacheReadingOptions)
            if data != nil {
                return data
            }
            data = try? Data.init(contentsOf: URL.init(fileURLWithPath: (filePath as NSString).deletingPathExtension), options: config.diskCacheReadingOptions)
            if data != nil {
                return data
            }
        }
        return data;
    }

    func diskImage(forKey key: String) -> UIImage? {
        guard let data = diskImageDataBySearchingAllPaths(forKey: key) else { return nil }
        var image = XMWebImageCodersManager.shared.decodedImage(data: data)
        image = scaled(image: image, forKey: key)
        if config.shouldDecompressImages {
            image = XMWebImageCodersManager.shared.decompressed(image: image)
        }
        return image
    }

    func scaled(image: UIImage?,forKey key: String) -> UIImage? {
        guard let scaledImage = image else { return nil }
        if scaledImage.images != nil && scaledImage.images!.count > 0 {
            var scaledImages = [UIImage]()

            for tempImage in scaledImage.images! {
                guard let image1 = self.scaled(image: tempImage, forKey: key) else { continue }
                scaledImages.append(image1)
            }
            let animatedImage = UIImage.animatedImage(with: scaledImages, duration: scaledImage.duration)
            if animatedImage != nil {
                animatedImage?.xm_imageLoopCount = scaledImage.xm_imageLoopCount
            }
            return animatedImage
        } else {
            var scale: CGFloat = 1.0
            if key.count >= 8 {
                if key.range(of: "@2x.") != nil {
                    scale = 2.0
                }
                if key.range(of: "@3x.") != nil {
                    scale = 3.0
                }
            }
            if scaledImage.cgImage == nil {
                return nil
            }
            return UIImage.init(cgImage: scaledImage.cgImage!, scale: scale, orientation: scaledImage.imageOrientation)
        }
    }

    @discardableResult
    public func queryCacheOperation(forKey key: String, done: XMCacheQueryCompleted?) -> Operation? {
        if key.isEmpty {
            if done != nil {
                done!(nil, nil, .none)
            }
            return nil
        }
        let image = imageFromMemoryCache(forKey: key)
        if image != nil {
            var diskData: Data? = nil
            if image?.images != nil && image!.images!.count != 0 {
                diskData = diskImageDataBySearchingAllPaths(forKey: key)
            }
            if done != nil {
                done!(image, diskData, .memory)
            }
            return nil
        }
        let option = Operation()
        ioQueue.async {
            if option.isCancelled {
                return
            }
            autoreleasepool(invoking: { () -> Void in
                let data = self.diskImageDataBySearchingAllPaths(forKey: key)
                let image = self.diskImage(forKey: key)
                if image != nil && self.config.shouldCacheImagesInMemory {
                    self.memCache.setObject(image!, forKey: key as AnyObject, cost: self.cacheCostForImage(image: image!))
                }
                if done != nil {
                    DispatchQueue.main.async {
                        done!(image, data, .disk)
                    }
                }
            })
        }
        return option
    }

    public func removeImage(key: String, fromDisk: Bool = true, completion: XMWebImageNoParams?) {
        if key.isEmpty {
            return
        }
        if config.shouldCacheImagesInMemory {
            memCache.removeObject(forKey: key as AnyObject)
        }

        if fromDisk {
            ioQueue.async {
                try? self.fileManager.removeItem(atPath: self.defaultCachePath(forKey: key))

                DispatchQueue.main.async {
                    if completion != nil {
                        completion!()
                    }
                }
            }
        } else {
            if completion != nil {
                completion!()
            }
        }

    }
    @objc public func clearMemory() {
        memCache.removeAllObjects()
    }
    public func clearDisk(_ completion: XMWebImageNoParams?) {
        ioQueue.async {
            try? self.fileManager.removeItem(atPath: self.diskCachePath)
            try? self.fileManager.createDirectory(atPath: self.diskCachePath, withIntermediateDirectories: true, attributes: nil)

            if completion != nil {
                DispatchQueue.main.async {
                    completion!()
                }
            }
        }
    }
    @objc public func deleteOldFiles(_ completion: XMWebImageNoParams? = nil) {
        ioQueue.async {
            let diskCacheURL = URL.init(fileURLWithPath: self.diskCachePath, isDirectory: true)
            let resourceKeys = [URLResourceKey.isDirectoryKey, URLResourceKey.contentModificationDateKey, URLResourceKey.totalFileAllocatedSizeKey]

            let expirationDate = Date.init(timeIntervalSinceNow: -self.config.maxCacheAge)
            var cacheFiles = [URL: URLResourceValues]()
            var currentCacheSize = 0

            var urlsToDelete = [URL]()
            for fileURL in (try? self.fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: resourceKeys, options: .skipsHiddenFiles)) ?? [] {
                let resourceValues = try? fileURL.resourceValues(forKeys:  [.isDirectoryKey, .contentModificationDateKey, .totalFileAllocatedSizeKey])
                if resourceValues?.isDirectory == true {
                    continue
                }
                if resourceValues?.contentModificationDate?.timeIntervalSince(expirationDate) ?? 0.0 < 0 {
                    urlsToDelete.append(fileURL)
                }
                currentCacheSize = currentCacheSize + (resourceValues?.totalFileAllocatedSize ?? 0)
                cacheFiles[fileURL] = resourceValues
            }
            for deleteURL in urlsToDelete {
                try? self.fileManager.removeItem(at: deleteURL)
            }
            if self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize {
                let desiredCacheSize = self.config.maxCacheSize / 2
                let sortedFiles = cacheFiles.sorted(by: { (dict1, dict2) -> Bool in
                    if let date1 = dict1.value.contentAccessDate,
                        let date2 = dict2.value.contentAccessDate
                    {
                        return date1.compare(date2) == .orderedAscending
                    }
                    return true
                })
                for tuple in sortedFiles {
                    try? self.fileManager.removeItem(at: tuple.key)
                    currentCacheSize = currentCacheSize - (tuple.value.totalFileAllocatedSize ?? 0)
                    if currentCacheSize < desiredCacheSize {
                        break
                    }
                }
            }

            if completion != nil {
                DispatchQueue.main.async {
                    completion!()
                }
            }
        }
    }
    @objc private func backgroundDeleteOldFiles() {
        var bgTask = UIBackgroundTaskInvalid
        bgTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        }
        deleteOldFiles {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        }
    }

    public var size: Int {
        var size = 0
        ioQueue.async {
            for fileName in (try? self.fileManager.contentsOfDirectory(atPath: self.diskCachePath)) ?? [] {
                let filePath = self.diskCachePath + "/\(fileName)"
                let attrs = try? self.fileManager.attributesOfItem(atPath: filePath)
                size = size + ((attrs?[FileAttributeKey.size] as? Int) ?? 0)
            }
        }
        return size
    }
    public var diskCount: Int {
        var count = 0

        ioQueue.async {
            let fileEnumerator = self.fileManager.enumerator(atPath: self.diskCachePath)
            count = fileEnumerator?.allObjects.count ?? 0
        }
        return count
    }
    public func calculateSize(completion: XMWebImageCalculateSize?) {
        let diskCacheURL = URL.init(fileURLWithPath: diskCachePath, isDirectory: true)
        ioQueue.async {
            var fileCount = 0
            var totalSize = 0
            for fileURL in (try? self.fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: .skipsHiddenFiles)) ?? [] {
                let resourceValues = try? fileURL.resourceValues(forKeys:  [.fileSizeKey])
                fileCount = fileCount + 1
                totalSize = totalSize + (resourceValues?.fileSize ?? 0)
            }
            if completion != nil {
                DispatchQueue.main.async {
                    completion!(fileCount, totalSize)
                }
            }
        }
    }
}

