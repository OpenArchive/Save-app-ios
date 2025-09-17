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
class FileMetadata {
    let fileName: String
    let fileSize: String
    let fileType: FileType
    let directUrl: String
    
    init(fileName: String, fileSize: String, fileType: FileType, directUrl: String) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileType = fileType
        self.directUrl = directUrl
    }
}

enum FileType: CaseIterable {
    case image
    case video
    case audio
    case unknown
    
    var systemIconName: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        case .unknown:
            return "doc"
        }
    }
}

// MARK: - File Metadata Fetcher
class FileMetadataFetcher: ObservableObject {
    private let session: URLSession
    private let cache = NSCache<NSString, FileMetadata>()
    
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }
    
    func fetchFileMetadata(from gatewayUrl: String) async -> FileMetadata? {
        // Check cache first
        print("gatewayUrl: \(gatewayUrl)")
        let cacheKey = NSString(string: gatewayUrl)
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        guard let url = URL(string: gatewayUrl) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            // Debug: Print HTML structure for w3s.link URLs
            if gatewayUrl.contains("w3s.link") {
                print("W3S.LINK HTML STRUCTURE:")
                print(String(html.prefix(1000)))
                print("END OF HTML PREVIEW")
            }
            
            let metadata = parseFileMetadata(from: html, baseUrl: gatewayUrl)
            
            // Cache the result
            if let metadata = metadata {
                cache.setObject(metadata, forKey: cacheKey)
            }
            
            return metadata
        } catch {
            print("Error fetching file metadata: \(error)")
            return nil
        }
    }
    
    private func parseFileMetadata(from html: String, baseUrl: String) -> FileMetadata? {
        print("Parsing HTML content, length: \(html.count)")
        
        // Check if this is actually a file (not a directory) by looking for common file indicators
        if html.contains("Content-Type:") || html.contains("content-type:") ||
           html.contains("<img") || html.contains("<video") || html.contains("<audio") ||
           html.lowercased().contains("content-disposition") {
            // This might be a direct file, try to extract filename from URL
            return extractFileFromDirectURL(baseUrl: baseUrl)
        }
        
        // Try multiple patterns for different gateways
        let patterns = [
            // Original pattern for storacha gateway
            #"<a\s+href="(?:/ipfs/[^/]+/)?([^"]+)">([^<]+)</a>"#,
            // w3s.link pattern - they might use relative paths
            #"<a[^>]*href="\.?/?([^"./][^"]*)"[^>]*>([^<]+)</a>"#,
            // More flexible pattern for any gateway
            #"<a[^>]*href="([^"]*)"[^>]*>([^<]+)</a>"#,
            // Even more flexible - just look for href and text
            #"href\s*=\s*"([^"]*)"[^>]*>([^<]+)"#
        ]
        
        for (index, pattern) in patterns.enumerated() {
            print("Trying pattern \(index + 1): \(pattern)")
            if let metadata = tryParseWithPattern(pattern, html: html, baseUrl: baseUrl) {
                print("Successfully parsed with pattern \(index + 1)")
                return metadata
            }
        }
        
        print("No patterns matched, returning nil")
        return nil
    }
    
    private func extractFileFromDirectURL(baseUrl: String) -> FileMetadata? {
        guard let url = URL(string: baseUrl) else { return nil }
        
        let fileName = url.lastPathComponent
        if fileName.isEmpty || fileName.hasPrefix("bafy") || fileName.hasPrefix("Qm") {
            // If no filename in URL, create a generic one based on the hash
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
            print("Failed to create regex for pattern: \(pattern)")
            return nil
        }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        
        print("Found \(matches.count) matches for current pattern")
        
        for (index, match) in matches.enumerated() {
            guard match.numberOfRanges >= 3 else {
                print("Match \(index) has insufficient ranges: \(match.numberOfRanges)")
                continue
            }
            
            let hrefRange = match.range(at: 1)
            let linkTextRange = match.range(at: 2)
            
            guard let hrefSubstring = Range(hrefRange, in: html),
                  let linkTextSubstring = Range(linkTextRange, in: html) else {
                print("Match \(index) has invalid ranges")
                continue
            }
            
            let href = String(html[hrefSubstring]).trimmingCharacters(in: .whitespacesAndNewlines)
            let linkText = String(html[linkTextSubstring]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("Match \(index): href='\(href)', linkText='\(linkText)'")
            
            // Skip parent directory links and empty links
            if href == "../" || linkText == ".." || href.isEmpty || linkText.isEmpty {
                print("Skipping match \(index): parent directory or empty")
                continue
            }
            
            if (linkText.hasPrefix("bafy") || linkText.hasPrefix("Qm")) && !linkText.contains(".") {
                print("Skipping match \(index): looks like a hash")
                continue
            }

            // Skip extremely long names that are likely hashes (but allow reasonable filenames)
            if linkText.count > 100 && !linkText.contains(".") {
                print("Skipping match \(index): too long without extension")
                continue
            }
            
            // Skip common navigation elements
            if linkText.lowercased().contains("parent") ||
               linkText.lowercased().contains("back") ||
               linkText.lowercased().contains("index") ||
               href.contains("..") {
                print("Skipping match \(index): navigation element")
                continue
            }
            
            let fileName = linkText
            
            // Construct direct URL - handle different href formats
            var directUrl: String
            if href.hasPrefix("http") {
                // Absolute URL
                directUrl = href
            } else if href.hasPrefix("/") {
                // Root-relative URL
                if let urlComponents = URLComponents(string: baseUrl) {
                    directUrl = "\(urlComponents.scheme!)://\(urlComponents.host!)\(href)"
                } else {
                    directUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + href
                }
            } else {
                // Relative URL
                directUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + href
            }
            
            let fileType = determineFileType(from: fileName)
            
            // Try to extract file size from the HTML around this link
            let contextStart = max(0, match.range.location - 100)
            let contextEnd = min(html.count, match.range.location + match.range.length + 200)
            let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)
            
            let context = (html as NSString).substring(with: contextRange)
            let fileSize = extractFileSize(from: context)
            
            print("Successfully parsed file: \(fileName), size: \(fileSize), direct URL: \(directUrl)")
            
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
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "avif", "heic", "heif":
            return .image
        case "mp4", "avi", "mkv", "mov", "wmv", "flv", "webm", "m4v":
            return .video
        case "mp3", "wav", "flac", "aac", "ogg", "m4a", "wma":
            return .audio
        default:
            return .unknown
        }
    }
}
