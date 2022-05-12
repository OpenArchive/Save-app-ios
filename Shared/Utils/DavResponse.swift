//
//  WebDAVFileProvider.swift
//  FileProvider
//
//  Created by Amir Abbas Mousavian.
//  Copyright © 2016 Mousavian. Distributed under MIT license.
//

import Foundation

struct DavResponse {
    let href: URL
    let hrefString: String
    let status: Int?
    let prop: [String: String]

    static let urlAllowed = CharacterSet(charactersIn: " ").inverted

    init? (_ node: AEXMLElement, baseURL: URL?) {

        func standardizePath(_ str: String) -> String {
            let trimmedStr = str.hasPrefix("/") ? String(str[str.index(after: str.startIndex)...]) : str
            return trimmedStr.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: ":"))) ?? str
        }

        // find node names with namespace
        var hreftag = "href"
        var statustag = "status"
        var propstattag = "propstat"
        for node in node.children {
            if node.name.lowercased().hasSuffix("href") {
                hreftag = node.name
            }
            if node.name.lowercased().hasSuffix("status") {
                statustag = node.name
            }
            if node.name.lowercased().hasSuffix("propstat") {
                propstattag = node.name
            }
        }

        guard let hrefString = node[hreftag].value else { return nil }

        // Percent-encoding space, some servers return invalid urls which space is not encoded to %20
        let hrefStrPercented = hrefString.addingPercentEncoding(withAllowedCharacters: DavResponse.urlAllowed) ?? hrefString
        // trying to figure out relative path out of href
        let hrefAbsolute = URL(string: hrefStrPercented, relativeTo: baseURL)?.absoluteURL
        let relativePath: String
        if hrefAbsolute?.host?.replacingOccurrences(of: "www.", with: "", options: .anchored) == baseURL?.host?.replacingOccurrences(of: "www.", with: "", options: .anchored) {
            relativePath = hrefAbsolute?.path.replacingOccurrences(of: baseURL?.absoluteURL.path ?? "", with: "", options: .anchored, range: nil) ?? hrefString
        } else {
            relativePath = hrefAbsolute?.absoluteString.replacingOccurrences(of: baseURL?.absoluteString ?? "", with: "", options: .anchored, range: nil) ?? hrefString
        }
        let hrefURL = URL(string: standardizePath(relativePath), relativeTo: baseURL) ?? baseURL

        guard let href = hrefURL?.standardized else { return nil }

        // reading status and properties
        var status: Int?
        let statusDesc = (node[statustag].string).components(separatedBy: " ")
        if statusDesc.count > 2 {
            status = Int(statusDesc[1])
        }
        var propDic = [String: String]()
        let propStatNode = node[propstattag]
        for node in propStatNode.children where node.name.lowercased().hasSuffix("status"){
            statustag = node.name
            break
        }
        let statusDesc2 = (propStatNode[statustag].string).components(separatedBy: " ")
        if statusDesc2.count > 2 {
            status = Int(statusDesc2[1])
        }
        var proptag = "prop"
        for tnode in propStatNode.children where tnode.name.lowercased().hasSuffix("prop") {
            proptag = tnode.name
            break
        }
        for propItemNode in propStatNode[proptag].children {
            let key = propItemNode.name.components(separatedBy: ":").last!.lowercased()
            guard propDic.index(forKey: key) == nil else { continue }
            propDic[key] = propItemNode.value
            if key == "resourcetype" && propItemNode.xml.contains("collection") {
                propDic["getcontenttype"] = "httpd/unix-directory"
            }
        }
        self.href = href
        self.hrefString = hrefString
        self.status = status
        self.prop = propDic
    }

    static func parse(xmlResponse: Data, baseURL: URL?) -> [DavResponse] {
        guard let xml = try? AEXMLDocument(xml: xmlResponse) else { return [] }
        var result = [DavResponse]()
        var rootnode = xml.root
        var responsetag = "response"
        for node in rootnode.all ?? [] where node.name.lowercased().hasSuffix("multistatus") {
            rootnode = node
        }
        for node in rootnode.children where node.name.lowercased().hasSuffix("response") {
            responsetag = node.name
            break
        }
        for responseNode in rootnode[responsetag].all ?? [] {
            if let davResponse = DavResponse(responseNode, baseURL: baseURL) {
                result.append(davResponse)
            }
        }
        return result
    }
}
