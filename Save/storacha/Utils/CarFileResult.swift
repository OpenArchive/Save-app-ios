//
//  CarFileResult.swift
//  Save
//
//  Created by navoda on 2025-09-17.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import Foundation
import CryptoKit
import OSLog

struct CarFileResult {
    let carData: Data
    let carCid: String
    let rootCid: String
}

struct IpldBlock {
    let cid: Data
    let data: Data
}

class CarFileCreator {
    private static let chunkSize = 1_048_576 // 1MB chunks
    private static let logger = Logger(subsystem: "CarFileCreator", category: "FileProcessing")
    
    static func createCarFile(from file: URL) throws -> CarFileResult {
        let mimeType = detectMimeType(for: file)
        let fileData = try Data(contentsOf: file)
        
        // Use embedded approach for files < 1MB, chunked for larger files
        if fileData.count < chunkSize {
            return try createEmbeddedCarWithCids(fileData: fileData, fileName: file.lastPathComponent, mimeType: mimeType)
        } else {
            return try createChunkedCarWithCids(fileData: fileData, fileName: file.lastPathComponent, mimeType: mimeType)
        }
    }
    
    // MARK: - Embedded approach for small files
    private static func createEmbeddedCarWithCids(fileData: Data, fileName: String, mimeType: String) throws -> CarFileResult {
        var blocks: [IpldBlock] = []
        
        // Create raw block for file data
        let rawBlock = createRawBlock(data: fileData)
        blocks.append(rawBlock)
        
        // Create single DAG-PB block that directly links to raw block with filename
        let rootDagPbBlock = try createEmbeddedDagPbBlock(rawCid: rawBlock.cid, fileName: fileName, fileSize: fileData.count)
        blocks.append(rootDagPbBlock)
        
        // Create CAR with both blocks
        let carData = try createCar(rootCid: rootDagPbBlock.cid, blocks: blocks)
        
        // Create CIDs in proper format
        let rootCid = cidBytesToString(cidBytes: rootDagPbBlock.cid, prefix: "b")
        let carCid = createCarCid(carData: carData)
        
        return CarFileResult(carData: carData, carCid: carCid, rootCid: rootCid)
    }
    
    // MARK: - Chunked approach for large files
    private static func createChunkedCarWithCids(fileData: Data, fileName: String, mimeType: String) throws -> CarFileResult {
        var blocks: [IpldBlock] = []
        var chunkCids: [Data] = []
        
        // Create raw blocks for each chunk
        var offset = 0
        while offset < fileData.count {
            let chunkSize = min(Self.chunkSize, fileData.count - offset)
            let chunkData = fileData.subdata(in: offset..<(offset + chunkSize))
            
            let rawBlock = createRawBlock(data: chunkData)
            blocks.append(rawBlock)
            chunkCids.append(rawBlock.cid)
            
            offset += chunkSize
        }
        
        // Create intermediate DAG-PB block that links to raw chunks
        let intermediateDagPbBlock = try createIntermediateDagPbBlock(chunkCids: chunkCids, fileSize: fileData.count, mimeType: mimeType)
        blocks.append(intermediateDagPbBlock)
        
        // Create root DAG-PB block that links to intermediate block with filename
        let rootDagPbBlock = try createRootDagPbBlock(intermediateCid: intermediateDagPbBlock.cid, fileName: fileName, fileSize: fileData.count)
        blocks.append(rootDagPbBlock)
        
        // Create CAR with all blocks
        let carData = try createCar(rootCid: rootDagPbBlock.cid, blocks: blocks)
        
        // Create CIDs in proper format
        let rootCid = cidBytesToString(cidBytes: rootDagPbBlock.cid, prefix: "b")
        let carCid = createCarCid(carData: carData)
        
        return CarFileResult(carData: carData, carCid: carCid, rootCid: rootCid)
    }
    
    // MARK: - Block creation methods
    private static func createRawBlock(data: Data) -> IpldBlock {
        let hash = SHA256.hash(data: data)
        
        // Create multihash: 0x12 (SHA-256) + 0x20 (32 bytes) + hash
        var multiHash = Data([0x12, 0x20])
        multiHash.append(Data(hash))
        
        // Create CID v1: version(1) + codec(0x55 raw) + multihash
        var cidBytes = Data([0x01, 0x55])
        cidBytes.append(multiHash)
        
        return IpldBlock(cid: cidBytes, data: data)
    }
    
    private static func createEmbeddedDagPbBlock(rawCid: Data, fileName: String, fileSize: Int) throws -> IpldBlock {
        // Create minimal UnixFS root node (directory-like)
        let unixfsData = Data([0x08, 0x01]) // type = directory (1)
        
        // Create link to raw block with filename
        let linkData = try createPbLink(cid: rawCid, name: fileName, size: fileSize)
        
        // Create DAG-PB protobuf structure: Link first, then Data
        var pbData = Data()
        
        // Field 2: Link to raw block first
        pbData.append(0x12) // field 2, wire type 2
        pbData.append(contentsOf: encodeVarInt(linkData.count))
        pbData.append(linkData)
        
        // Field 1: Data (UnixFS metadata)
        pbData.append(0x0A) // field 1, wire type 2
        pbData.append(contentsOf: encodeVarInt(unixfsData.count))
        pbData.append(unixfsData)
        
        // Create CID for the DAG-PB block
        let hash = SHA256.hash(data: pbData)
        var multiHash = Data([0x12, 0x20])
        multiHash.append(Data(hash))
        var cidBytes = Data([0x01, 0x70])
        cidBytes.append(multiHash)
        
        return IpldBlock(cid: cidBytes, data: pbData)
    }
    
    private static func createIntermediateDagPbBlock(chunkCids: [Data], fileSize: Int, mimeType: String) throws -> IpldBlock {
        let unixfsData = createIntermediateUnixFsData(fileSize: fileSize, chunkCount: chunkCids.count)
        
        var pbData = Data()
        
        // Field 2: Links to all chunks first
        for (index, chunkCid) in chunkCids.enumerated() {
            pbData.append(0x12) // field 2, wire type 2
            let chunkSize = (index == chunkCids.count - 1) ? 
                (fileSize % chunkSize == 0 ? chunkSize : fileSize % chunkSize) : 
                chunkSize
            let linkData = try createPbLink(cid: chunkCid, name: "", size: chunkSize)
            pbData.append(contentsOf: encodeVarInt(linkData.count))
            pbData.append(linkData)
        }
        
        // Field 1: Data (UnixFS metadata)
        pbData.append(0x0A) // field 1, wire type 2
        pbData.append(contentsOf: encodeVarInt(unixfsData.count))
        pbData.append(unixfsData)
        
        // Create CID for the intermediate DAG-PB block
        let hash = SHA256.hash(data: pbData)
        var multiHash = Data([0x12, 0x20])
        multiHash.append(Data(hash))
        var cidBytes = Data([0x01, 0x70])
        cidBytes.append(multiHash)
        
        return IpldBlock(cid: cidBytes, data: pbData)
    }
    
    private static func createRootDagPbBlock(intermediateCid: Data, fileName: String, fileSize: Int) throws -> IpldBlock {
        // Create minimal UnixFS root node (directory-like)
        let unixfsData = Data([0x08, 0x01]) // type = directory (1)
        
        // Add intermediate block overhead (108 bytes like ipfs-car)
        let totalSize = fileSize + 108
        
        // Create link to intermediate block with filename
        let linkData = try createPbLink(cid: intermediateCid, name: fileName, size: totalSize)
        
        var pbData = Data()
        
        // Field 2: Link to intermediate block first
        pbData.append(0x12) // field 2, wire type 2
        pbData.append(contentsOf: encodeVarInt(linkData.count))
        pbData.append(linkData)
        
        // Field 1: Data (UnixFS directory metadata)
        pbData.append(0x0A) // field 1, wire type 2
        pbData.append(contentsOf: encodeVarInt(unixfsData.count))
        pbData.append(unixfsData)
        
        // Create CID for the root DAG-PB block
        let hash = SHA256.hash(data: pbData)
        var multiHash = Data([0x12, 0x20])
        multiHash.append(Data(hash))
        var cidBytes = Data([0x01, 0x70])
        cidBytes.append(multiHash)
        
        return IpldBlock(cid: cidBytes, data: pbData)
    }
    
    // MARK: - Helper methods
    private static func createIntermediateUnixFsData(fileSize: Int, chunkCount: Int) -> Data {
        var output = Data()
        
        // Field 1: Type (file = 2)
        output.append(0x08) // field 1, varint
        output.append(0x02) // file type = 2
        
        // Field 3: Total file size
        output.append(0x18) // field 3, varint
        output.append(contentsOf: encodeVarInt(fileSize))
        
        // Field 4: Block sizes
        for i in 0..<chunkCount {
            output.append(0x20) // field 4, varint
            if i == chunkCount - 1 {
                let lastChunkSize = fileSize % chunkSize
                output.append(contentsOf: encodeVarInt(lastChunkSize > 0 ? lastChunkSize : chunkSize))
            } else {
                output.append(contentsOf: encodeVarInt(chunkSize))
            }
        }
        
        return output
    }
    
    private static func createPbLink(cid: Data, name: String, size: Int) throws -> Data {
        var output = Data()
        
        // Field 1: CID (Hash field)
        output.append(0x0A) // field 1, wire type 2
        output.append(contentsOf: encodeVarInt(cid.count))
        output.append(cid)
        
        // Field 2: Name
        output.append(0x12) // field 2, wire type 2
        let nameData = name.data(using: .utf8) ?? Data()
        output.append(contentsOf: encodeVarInt(nameData.count))
        output.append(nameData)
        
        // Field 3: Size
        output.append(0x18) // field 3, wire type 0 (varint)
        output.append(contentsOf: encodeVarInt(size))
        
        return output
    }
    
    private static func createCar(rootCid: Data, blocks: [IpldBlock]) throws -> Data {
        var output = Data()
        
        // Create header pointing to root CID
        let headerData = createCborHeader(rootCid: rootCid)
        
        // Write header with varint length prefix
        output.append(contentsOf: encodeVarInt(headerData.count))
        output.append(headerData)
        
        // Write all blocks with varint length prefixes
        for block in blocks {
            let blockSize = block.cid.count + block.data.count
            output.append(contentsOf: encodeVarInt(blockSize))
            output.append(block.cid)
            output.append(block.data)
        }
        
        return output
    }
    
    private static func createCborHeader(rootCid: Data) -> Data {
        var output = Data()
        
        // CBOR map with 2 items
        output.append(0xA2)
        
        // "roots" key
        output.append(0x65)
        output.append("roots".data(using: .utf8)!)
        
        // Roots array with 1 element
        output.append(0x81) // CBOR array of length 1
        output.append(0xD8) // CBOR tag
        output.append(0x2A) // Tag 42 for CID
        
        // Byte string with (1 + rootCid.count) length
        output.append(0x58)
        output.append(UInt8(rootCid.count + 1))
        
        // Write the 0x00 prefix and CID bytes
        output.append(0x00)
        output.append(rootCid)
        
        // "version" key
        output.append(0x67)
        output.append("version".data(using: .utf8)!)
        
        // Version 1
        output.append(0x01)
        
        return output
    }
    
    private static func encodeVarInt(_ value: Int) -> Data {
        var result = Data()
        var v = value
        
        while v >= 0x80 {
            result.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        result.append(UInt8(v))
        
        return result
    }
    
    private static func cidBytesToString(cidBytes: Data, prefix: String) -> String {
        return "\(prefix)\(encodeBase32(cidBytes))"
    }
    
    private static func createCarCid(carData: Data) -> String {
        let hash = SHA256.hash(data: carData)
        
        // Create multihash: 0x12 (SHA-256) + 0x20 (32 bytes) + hash
        var multiHash = Data([0x12, 0x20])
        multiHash.append(Data(hash))
        
        // Create CID v1: version(1) + codec(CAR multicodec 0x0202) + multihash
        let carCodecVarint = encodeVarInt(0x0202)
        var cidBytes = Data([0x01])
        cidBytes.append(carCodecVarint)
        cidBytes.append(multiHash)
        
        return cidBytesToString(cidBytes: cidBytes, prefix: "b")
    }
    
    private static func encodeBase32(_ data: Data) -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyz234567"
        var result = ""
        
        var buffer: UInt64 = 0
        var bitsLeft = 0
        
        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsLeft += 8
            
            while bitsLeft >= 5 {
                let index = Int((buffer >> (bitsLeft - 5)) & 0x1F)
                result += String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
                bitsLeft -= 5
            }
        }
        
        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1F)
            result += String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }
        
        return result
    }
    
    private static func detectMimeType(for file: URL) -> String {
        let pathExtension = file.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "avi":
            return "video/x-msvideo"
        case "webm":
            return "video/webm"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "m4a":
            return "audio/mp4"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "json":
            return "application/json"
        case "xml":
            return "application/xml"
        default:
            return "application/octet-stream"
        }
    }
}