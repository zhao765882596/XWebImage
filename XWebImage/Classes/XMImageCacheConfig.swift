//
//  XMImageCacheConfig.swift
//  Pods
//
//  Created by ming on 2017/11/21.
//

import Foundation
public struct XMImageCacheConfig {

    /// Decompressing images that are downloaded and cached can improve performance but can consume lot of memory.Defaults to YES. Set this to NO if you are experiencing a crash due to excessive memory consumption.
    var shouldDecompressImages = true

    /// disable iCloud backup [defaults to YES]
    var shouldDisableiCloud = true

    /// use memory cache [defaults to YES]
    var shouldCacheImagesInMemory = true

    /// The reading options while reading cache from disk.  Defaults to 0. You can set this to mapped file to improve performance
    var diskCacheReadingOptions = Data.ReadingOptions.init(rawValue: 0)

    /// The maximum length of time to keep an image in the cache, in seconds. Defaults to a weak
    var maxCacheAge: TimeInterval = TimeInterval(60 * 60 * 24 * 7)

    /// The maximum size of the cache, in bytes.
    var maxCacheSize = 0
}
