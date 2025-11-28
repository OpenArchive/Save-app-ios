//
//  FileMetadata.swift
//  Save
//
//  Created by navoda on 2025-09-17.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import UIKit

// MARK: - File Metadata Models
struct FileMetadata {
    let fileName: String
    let fileSize: String
    let fileType: FileType
    let directUrl: String
}

enum FileType: CaseIterable {
    case image
    case video
    case audio
    case pdf
    case zip
    case text
    case document
    case unknown
    
    var systemIconName: String {
        switch self {
        case .image:
            return "img_default"
        case .video:
            return "video_file"
        case .audio:
            return "music_file"
        case .pdf:
            return "pdf_default"
        case .zip:
            return "zip_file"
        case .text:
            return "text_file"
        case .document:
            return "text_file"
        case .unknown:
            return "unknown"
        }
    }
}

// MARK: - File Metadata Fetcher
class FileMetadataFetcher {
    static let shared = FileMetadataFetcher()
    
    private let session: URLSession
    private let cache = NSCache<NSString, CachedMetadata>()
    
    private init(session: URLSession = URLSession.shared) {
        self.session = session
        
        // Configure cache with reasonable limits
        cache.countLimit = 200 // Maximum 200 items
        cache.totalCostLimit = 1024 * 1024 * 10 // 10 MB for metadata only
    }
    
    // Wrapper class for NSCache (NSCache requires class types)
    private class CachedMetadata {
        let metadata: FileMetadata
        
        init(metadata: FileMetadata) {
            self.metadata = metadata
        }
    }
    
    func fetchFileMetadata(from gatewayUrl: String) async -> FileMetadata? {
        let normalizedUrl = gatewayUrl.replacingOccurrences(of: "w3s.link", with: "dweb.link")
        let cacheKey = NSString(string: normalizedUrl)
        
        // Check cache
        if let cached = cache.object(forKey: cacheKey) {
            return cached.metadata
        }
        
        guard let url = URL(string: normalizedUrl) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let metadata = parseFileMetadata(from: html, baseUrl: normalizedUrl)
            
            // Cache the result
            if let metadata = metadata {
                cache.setObject(CachedMetadata(metadata: metadata), forKey: cacheKey)
            }
            
            return metadata
        } catch {
            return nil
        }
    }
    
    // Check if metadata is cached
    func getCachedMetadata(for gatewayUrl: String) -> FileMetadata? {
        let normalizedUrl = gatewayUrl.replacingOccurrences(of: "w3s.link", with: "dweb.link")
        let cacheKey = NSString(string: normalizedUrl)
        return cache.object(forKey: cacheKey)?.metadata
    }
    
    // Clear cache when needed (e.g., logout, space change)
    func clearCache() {
        cache.removeAllObjects()
    }
    
    // Clear specific item from cache
    func clearCache(for gatewayUrl: String) {
        let normalizedUrl = gatewayUrl.replacingOccurrences(of: "w3s.link", with: "dweb.link")
        let cacheKey = NSString(string: normalizedUrl)
        cache.removeObject(forKey: cacheKey)
    }
    
    private func parseFileMetadata(from html: String, baseUrl: String) -> FileMetadata? {
        if html.contains("Content-Type:") || html.contains("content-type:") ||
           html.contains("<img") || html.contains("<video") || html.contains("<audio") ||
           html.lowercased().contains("content-disposition") {
            return extractFileFromDirectURL(baseUrl: baseUrl)
        }
        
        let patterns = [
            #"<a\s+href="(?:/ipfs/[^/]+/)?([^"]+)">([^<]+)</a>"#,
            #"<a[^>]*href="\.?/?([^"./][^"]*)"[^>]*>([^<]+)</a>"#,
            #"<a[^>]*href="([^"]*)"[^>]*>([^<]+)</a>"#,
            #"href\s*=\s*"([^"]*)"[^>]*>([^<]+)"#
        ]
        
        for pattern in patterns {
            if let metadata = tryParseWithPattern(pattern, html: html, baseUrl: baseUrl) {
                return metadata
            }
        }
        
        return nil
    }
    
    private func extractFileFromDirectURL(baseUrl: String) -> FileMetadata? {
        guard let url = URL(string: baseUrl) else { return nil }
        
        let fileName = url.lastPathComponent
        if fileName.isEmpty || fileName.hasPrefix("bafy") || fileName.hasPrefix("Qm") {
            let pathComponents = url.pathComponents
            if let hash = pathComponents.last, hash.hasPrefix("bafy") || hash.hasPrefix("Qm") {
                return FileMetadata(
                    fileName: "File (\(String(hash.prefix(8)))...)",
                    fileSize: "Unknown size",
                    fileType: .unknown,
                    directUrl: baseUrl
                )
            }
            return nil
        }
        
        let fileType = determineFileType(from: fileName)
        
        return FileMetadata(
            fileName: fileName,
            fileSize: "Unknown size",
            fileType: fileType,
            directUrl: baseUrl
        )
    }
    
    private func tryParseWithPattern(_ pattern: String, html: String, baseUrl: String) -> FileMetadata? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        
        for match in matches {
            guard match.numberOfRanges >= 3 else {
                continue
            }
            
            let hrefRange = match.range(at: 1)
            let linkTextRange = match.range(at: 2)
            
            guard let hrefSubstring = Range(hrefRange, in: html),
                  let linkTextSubstring = Range(linkTextRange, in: html) else {
                continue
            }
            
            let href = String(html[hrefSubstring]).trimmingCharacters(in: .whitespacesAndNewlines)
            let linkText = String(html[linkTextSubstring]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if href == "../" || linkText == ".." || href.isEmpty || linkText.isEmpty {
                continue
            }
            
            if (linkText.hasPrefix("bafy") || linkText.hasPrefix("Qm")) && !linkText.contains(".") {
                continue
            }

            if linkText.count > 100 && !linkText.contains(".") {
                continue
            }
            
            if linkText.lowercased().contains("parent") ||
               linkText.lowercased().contains("back") ||
               linkText.lowercased().contains("index") ||
               href.contains("..") {
                continue
            }
            
            let fileName = linkText
            
            var directUrl: String
            if href.hasPrefix("http") {
                directUrl = href
            } else if href.hasPrefix("/") {
                if let urlComponents = URLComponents(string: baseUrl) {
                    directUrl = "\(urlComponents.scheme!)://\(urlComponents.host!)\(href)"
                } else {
                    directUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + href
                }
            } else {
                directUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + href
            }
            
            let fileType = determineFileType(from: fileName)
            
            let contextStart = max(0, match.range.location - 100)
            let contextEnd = min(html.count, match.range.location + match.range.length + 200)
            let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)
            
            let context = (html as NSString).substring(with: contextRange)
            let fileSize = extractFileSize(from: context)
            
            return FileMetadata(
                fileName: fileName,
                fileSize: fileSize,
                fileType: fileType,
                directUrl: directUrl
            )
        }
        
        return nil
    }
    
    private func extractFileSize(from context: String) -> String {
        let sizePattern = #"([0-9]+(?:\.[0-9]+)?\s*[KMGT]?B)"#
        
        guard let regex = try? NSRegularExpression(pattern: sizePattern, options: [.caseInsensitive]) else {
            return "Unknown size"
        }
        
        let range = NSRange(context.startIndex..<context.endIndex, in: context)
        if let match = regex.firstMatch(in: context, options: [], range: range),
           let sizeRange = Range(match.range(at: 1), in: context) {
            return String(context[sizeRange])
        }
        
        return "Unknown size"
    }
    
    private func determineFileType(from fileName: String) -> FileType {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        let fileTypes: [FileType: [String]] = [
            .audio: ["mp3", "m4a", "wav", "aac", "flac", "aiff", "wma", "ogg", "opus", "amr"],
            .video: ["mp4", "mov", "avi", "mkv", "flv", "wmv", "webm", "m4v", "3gp", "mpeg", "mpg"],
            .pdf: ["pdf"],
            .zip: ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"],
            .text: ["txt", "log", "md", "rtf", "csv", "json", "xml", "html", "htm"],
            .image: ["jpg", "jpeg", "png", "gif", "bmp", "svg", "webp", "heic", "tiff", "ico", "avif", "heif"],
            .document: ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp"]
        ]
        
        for (type, extensions) in fileTypes {
            if extensions.contains(ext) {
                return type
            }
        }
        
        return .unknown
    }
}
