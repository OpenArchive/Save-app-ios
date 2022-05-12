//
//  WebDAVFileProvider.swift
//  FileProvider
//
//  Created by Amir Abbas Mousavian.
//  Copyright © 2016 Mousavian. Distributed under MIT license.
//

import Foundation

struct FileInfo {

    let href: URL

    let name: String

    let relativePath: String

    let path: String

    let size: Int64

    let creationDate: Date?

    let modifiedDate: Date?

    let contentType: String?

    let isHidden: Bool

    let isReadOnly: Bool

    let type: URLFileResourceType

    let entryTag: String?


    init(_ davResponse: DavResponse) {
        href = davResponse.href

        name = davResponse.prop["displayname"] ?? davResponse.href.lastPathComponent

        relativePath = href.relativePath

        path = relativePath.hasPrefix("/") ? relativePath : ("/" + relativePath)

        size = Int64(davResponse.prop["getcontentlength"] ?? "-1") ?? NSURLSessionTransferSizeUnknown

        creationDate = davResponse.prop["creationdate"].flatMap { Date(rfcString: $0) }

        modifiedDate = davResponse.prop["getlastmodified"].flatMap { Date(rfcString: $0) }

        contentType = davResponse.prop["getcontenttype"]

        isHidden = (Int(davResponse.prop["ishidden"] ?? "0") ?? 0) > 0

        isReadOnly = (Int(davResponse.prop["isreadonly"] ?? "0") ?? 0) > 0

        type = (contentType == "httpd/unix-directory") ? .directory : .regular

        entryTag = davResponse.prop["getetag"]
    }
}
