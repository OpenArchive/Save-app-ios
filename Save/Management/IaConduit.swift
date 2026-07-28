//
//  IaConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

class IaConduit: Conduit {

    private static let mainFileProgressUnits: Int64 = 90
    private static let metadataProgressUnits: Int64 = 10

    /// Meta sidecar waiting to run after the main media PUT succeeds.
    private struct PendingMeta {
        let uploadId: String
        let progress: Progress
        let mediaUrl: URL
        let metaHeaders: [String: String]
        let backgroundSession: URLSession
        let asset: Asset
    }

    /// Survives process kill so we can enqueue meta after main already succeeded.
    private struct DurablePendingMeta: Codable {
        let uploadId: String
        let mediaUrl: String
        let metaHeaders: [String: String]
        let metaTempPath: String
        let assetId: String
        var mainSucceeded: Bool
    }

    private static let durableDefaultsKey = "IaConduit.durablePendingMetas"
    private static let pendingLock = NSLock()
    private static var pendingMetas: [String: PendingMeta] = [:]
    /// Main media URL held until meta finishes so `done` can report it.
    private static var completedMainUrls: [String: URL] = [:]
    private static var metaTempPaths: [String: String] = [:]
    /// Upload IDs whose meta PUT has been handed to the background session.
    private static var metaEnqueuedIds = Set<String>()

    // MARK: - taskDescription
    // "ia-meta|<uploadId>|<tempPath>" / "ia-main|<uploadId>|<tempPath>"

    static func encodeTaskDescription(kind: String, uploadId: String, tempPath: String) -> String {
        "\(kind)|\(uploadId)|\(tempPath)"
    }

    static func tempPath(fromTaskDescription description: String?) -> String? {
        guard let description, !description.isEmpty else { return nil }
        let parts = description.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        if parts.count == 3 {
            return String(parts[2])
        }
        return description
    }

    static func parseTaskDescription(_ description: String?) -> (kind: String, uploadId: String, tempPath: String)? {
        guard let description, !description.isEmpty else { return nil }
        let parts = description.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        return (String(parts[0]), String(parts[1]), String(parts[2]))
    }

    static func cancelPendingMeta(uploadId: String) {
        pendingLock.lock()
        if let path = metaTempPaths.removeValue(forKey: uploadId) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
        pendingMetas.removeValue(forKey: uploadId)
        completedMainUrls.removeValue(forKey: uploadId)
        metaEnqueuedIds.remove(uploadId)
        pendingLock.unlock()
        removeDurable(uploadId: uploadId)
    }

    /// True after main succeeded and before meta `done` — used to hold BG wake.
    static func isAwaitingMeta(_ uploadId: String) -> Bool {
        pendingLock.lock()
        let inMemory = completedMainUrls[uploadId] != nil
            && !metaEnqueuedIds.contains(uploadId)
        pendingLock.unlock()
        if inMemory { return true }
        return loadDurable()[uploadId]?.mainSucceeded == true
            && !hasMetaEnqueued(uploadId)
    }

    static func hasMetaEnqueued(_ uploadId: String) -> Bool {
        pendingLock.lock()
        defer { pendingLock.unlock() }
        return metaEnqueuedIds.contains(uploadId)
    }

    /// After kill / BG wake: enqueue meta for any durable state where main already OK.
    static func resumePendingMetasIfNeeded(on session: URLSession) {
        let durable = loadDurable().values.filter(\.mainSucceeded)
        guard !durable.isEmpty else { return }

        let sem = DispatchSemaphore(value: 0)
        var snapshot: [URLSessionTask] = []
        session.getAllTasks { tasks in
            snapshot = tasks
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)

        let activeMetaIds = Set(snapshot.compactMap { task -> String? in
            guard let parsed = parseTaskDescription(task.taskDescription),
                  parsed.kind == "ia-meta",
                  task.state != .canceling
            else {
                return nil
            }
            // In-flight or completed-but-not-yet-delivered — don't start another.
            return parsed.uploadId
        })

        for state in durable {
            if let mediaUrl = URL(string: state.mediaUrl) {
                pendingLock.lock()
                completedMainUrls[state.uploadId] = mediaUrl
                if activeMetaIds.contains(state.uploadId) {
                    metaEnqueuedIds.insert(state.uploadId)
                }
                pendingLock.unlock()
            }

            if activeMetaIds.contains(state.uploadId) { continue }

            pendingLock.lock()
            let alreadyEnqueued = metaEnqueuedIds.contains(state.uploadId)
            let hasPending = pendingMetas[state.uploadId] != nil
            pendingLock.unlock()
            if alreadyEnqueued || hasPending { continue }

            guard let pending = reconstructPendingMeta(from: state, session: session) else {
                removeDurable(uploadId: state.uploadId)
                continue
            }
#if DEBUG
            print("[IaConduit] resuming meta after kill/wake uploadId=\(state.uploadId)")
#endif
            startMetaFile(pending)
        }
    }

    /// Main media BG PUT finished — on success, enqueue `meta.json` on the same session.
    /// Returns `true` when the job should wait for meta (UploadManager must not call `done` yet).
    @discardableResult
    static func handleMainBackgroundComplete(
        uploadId: String,
        mediaUrl: URL,
        error: Error?,
        backgroundSession: URLSession? = nil
    ) -> Bool {
        if error != nil {
            cancelPendingMeta(uploadId: uploadId)
            return false
        }

        pendingLock.lock()
        var pending = pendingMetas.removeValue(forKey: uploadId)
        completedMainUrls[uploadId] = mediaUrl
        pendingLock.unlock()

        markDurableMainSucceeded(uploadId: uploadId, mediaUrl: mediaUrl)

        if pending == nil {
            let session = backgroundSession ?? IaUploadManager.shared.backgroundSession
            if let durable = loadDurable()[uploadId],
               let reconstructed = reconstructPendingMeta(from: durable, session: session) {
                pending = reconstructed
            }
        }

        guard let pending else {
            // No meta prepared — complete with main URL only.
            removeDurable(uploadId: uploadId)
            return false
        }

        startMetaFile(pending)
        return true
    }

    /// Meta sidecar finished — returns the main media URL for `done`, if any.
    static func handleMetaBackgroundComplete(uploadId: String) -> URL? {
        pendingLock.lock()
        let url = completedMainUrls.removeValue(forKey: uploadId)
        metaEnqueuedIds.remove(uploadId)
        pendingLock.unlock()
        removeDurable(uploadId: uploadId)
        return url
    }

    // MARK: - check_limit

    enum LimitCheckResult {
        case ready
        case overLimit
        case unavailable
    }

    /// Synchronous GET `?check_limit=1&accesskey=&bucket=`.
    /// Returns `.unavailable` on network/parse failure (caller should proceed, not extend cooldown).
    static func checkLimit(
        accessKey: String,
        bucket: String,
        session: URLSession,
        timeout: TimeInterval = 15
    ) -> LimitCheckResult {
        var components = URLComponents(string: IaSpace.baseUrl)
        components?.queryItems = [
            URLQueryItem(name: "check_limit", value: "1"),
            URLQueryItem(name: "accesskey", value: accessKey),
            URLQueryItem(name: "bucket", value: bucket),
        ]

        guard let url = components?.url else {
            return .unavailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        let sem = DispatchSemaphore(value: 0)
        var result: LimitCheckResult = .unavailable

        let task = session.dataTask(with: request) { data, response, error in
            defer { sem.signal() }

            if let error {
#if DEBUG
                print("[IaConduit] check_limit error=\(error.localizedDescription)")
#endif
                return
            }

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
#if DEBUG
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[IaConduit] check_limit bad response HTTP=\(status)")
#endif
                return
            }

            let over: Int
            if let n = json["over_limit"] as? Int {
                over = n
            } else if let n = json["over_limit"] as? NSNumber {
                over = n.intValue
            } else if let s = json["over_limit"] as? String, let n = Int(s) {
                over = n
            } else {
#if DEBUG
                print("[IaConduit] check_limit missing over_limit in \(json)")
#endif
                return
            }

            result = over == 0 ? .ready : .overLimit
#if DEBUG
            print("[IaConduit] check_limit bucket=\(bucket) over_limit=\(over)")
#endif
        }
        task.resume()
        _ = sem.wait(timeout: .now() + timeout + 1)
        return result
    }

    // MARK: Conduit

    /**
     - Metadata reference: https://github.com/vmbrasseur/IAS3API/blob/master/metadata.md

     Order: main media (background) → then `meta.json` sidecar (background).
     Main creates the item first so we never leave a meta-only / split identifier.
     */
    override func upload(uploadId: String) -> Progress {
        let progress = Progress(totalUnitCount: 100)
        UploadManager.shared.attachLiveProgress(progress, for: uploadId)

        guard let accessKey = asset.space?.username,
              let secretKey = asset.space?.password,
              let file = asset.file,
              let filesize = asset.filesize,
              let mediaUrl = url(for: asset)
        else {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: UploadError.invalidConf)
            }
            return progress
        }

        if progress.isCancelled {
            done(uploadId)
            return progress
        }

        guard FileManager.default.fileExists(atPath: file.path) else {
            let error = NSError(
                domain: "org.open-archive.save",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "File not found: \(file.path)"]
            )
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: error)
            }
            return progress
        }

        let mainHeaders = generateHeaders(accessKey, secretKey, forMetadata: false)
        let metaHeaders = generateHeaders(accessKey, secretKey, forMetadata: true)

        do {
            let json = try Conduit.jsonEncoder.encode(asset)
            let tempMeta = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_" + asset.filename + ".meta.json")
            try json.write(to: tempMeta, options: .atomic)

            Self.pendingLock.lock()
            Self.pendingMetas[uploadId] = PendingMeta(
                uploadId: uploadId,
                progress: progress,
                mediaUrl: mediaUrl,
                metaHeaders: metaHeaders,
                backgroundSession: backgroundSession,
                asset: asset
            )
            Self.metaTempPaths[uploadId] = tempMeta.path
            Self.pendingLock.unlock()
            Self.persistDurable(
                DurablePendingMeta(
                    uploadId: uploadId,
                    mediaUrl: mediaUrl.absoluteString,
                    metaHeaders: metaHeaders,
                    metaTempPath: tempMeta.path,
                    assetId: asset.id,
                    mainSucceeded: false
                )
            )
        } catch {
#if DEBUG
            print("[IaConduit] meta.json prepare failed — main only: \(error.localizedDescription)")
#endif
        }

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_" + file.lastPathComponent)

        do {
            do {
                try FileManager.default.linkItem(at: file, to: tempFile)
            } catch {
                if UploadManager.shared.isEffectivelyBackgrounded
                    || IaUploadManager.shared.isEffectivelyBackgrounded
                    || filesize > UploadQueuePolicy.largeFileThreshold {
                    throw NSError(
                        domain: "org.open-archive.save",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(
                            "Large file upload requires the app to stay open.", comment: "")]
                    )
                }
                try FileManager.default.copyItem(at: file, to: tempFile)
            }

            guard FileManager.default.fileExists(atPath: tempFile.path) else {
                throw NSError(
                    domain: "org.open-archive.save",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create temp file"]
                )
            }

            let task = backgroundSession.upload(
                tempFile,
                to: mediaUrl,
                headers: mainHeaders,
                credential: nil
            )
            task.taskDescription = Self.encodeTaskDescription(
                kind: "ia-main",
                uploadId: uploadId,
                tempPath: tempFile.path
            )
            progress.addChild(task.progress, withPendingUnitCount: Self.mainFileProgressUnits)
            IaUploadManager.shared.notifyBackgroundTransferEnqueued(uploadId: uploadId)
        } catch {
            Self.cancelPendingMeta(uploadId: uploadId)
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.done(uploadId, error: error)
            }
        }

        return progress
    }

    override func remove(done: @escaping DoneHandler) {
        if let accessKey = asset.space?.username,
           let secretKey = asset.space?.password,
           let url = asset.publicUrl {

            let headers: [String: String] = [
                "Accept": "*/*",
                "authorization": "LOW \(accessKey):\(secretKey)",
                "x-archive-cascade-delete": "1",
                "x-archive-keep-old-version": "0",
            ]

            foregroundSession.delete(url, headers: headers) { error in
                if error == nil {
                    self.asset.setUploaded(nil)
                }
                done(self.asset)
            }
        } else if !asset.isUploaded {
            done(asset)
        }
    }

    /// Best-effort catalog derive after a successful upload (`x-archive-queue-derive:0` on PUTs).
    static func queueDerive(
        for mediaUrl: URL,
        accessKey: String,
        secretKey: String,
        session: URLSession
    ) {
        let identifier = mediaUrl.deletingLastPathComponent().lastPathComponent
        guard !identifier.isEmpty,
              var components = URLComponents(string: "https://archive.org/services/tasks.php")
        else {
            return
        }

        components.queryItems = [
            URLQueryItem(name: "identifier", value: identifier),
            URLQueryItem(name: "cmd", value: "derive.php"),
            URLQueryItem(name: "args", value: "OP=derive"),
        ]

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("LOW \(accessKey):\(secretKey)", forHTTPHeaderField: "authorization")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { _, response, error in
#if DEBUG
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let error {
                print("[IaConduit] queueDerive failed identifier=\(identifier) error=\(error.localizedDescription)")
            } else {
                print("[IaConduit] queueDerive identifier=\(identifier) HTTP=\(status)")
            }
#endif
        }.resume()
    }

    // MARK: Private

    private static func startMetaFile(_ pending: PendingMeta) {
        if pending.progress.isCancelled {
            cancelPendingMeta(uploadId: pending.uploadId)
            NotificationCenter.default.post(
                name: .uploadManagerDone,
                object: pending.uploadId,
                userInfo: [AnyHashable.url: pending.mediaUrl]
            )
            return
        }

        pendingLock.lock()
        let existingPath = metaTempPaths.removeValue(forKey: pending.uploadId)
        pendingLock.unlock()

        do {
            let tempMeta: URL
            if let existingPath, FileManager.default.fileExists(atPath: existingPath) {
                tempMeta = URL(fileURLWithPath: existingPath)
            } else {
                let json = try Conduit.jsonEncoder.encode(pending.asset)
                tempMeta = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "_" + pending.asset.filename + ".meta.json")
                try json.write(to: tempMeta, options: .atomic)
            }

            let metaUrl = pending.mediaUrl.deletingLastPathComponent()
                .appendingPathComponent(pending.asset.filename + ".meta.json")

            let task = pending.backgroundSession.upload(
                tempMeta,
                to: metaUrl,
                headers: pending.metaHeaders,
                credential: nil
            )
            task.taskDescription = encodeTaskDescription(
                kind: "ia-meta",
                uploadId: pending.uploadId,
                tempPath: tempMeta.path
            )
            pending.progress.addChild(task.progress, withPendingUnitCount: metadataProgressUnits)
            pendingLock.lock()
            metaEnqueuedIds.insert(pending.uploadId)
            pendingLock.unlock()
            IaUploadManager.shared.notifyBackgroundTransferEnqueued(uploadId: pending.uploadId)
#if DEBUG
            print("[IaConduit] meta.json enqueued after main uploadId=\(pending.uploadId)")
#endif
        } catch {
#if DEBUG
            print("[IaConduit] meta.json start failed: \(error.localizedDescription)")
#endif
            pendingLock.lock()
            let mainUrl = completedMainUrls.removeValue(forKey: pending.uploadId) ?? pending.mediaUrl
            metaEnqueuedIds.remove(pending.uploadId)
            pendingLock.unlock()
            removeDurable(uploadId: pending.uploadId)
            NotificationCenter.default.post(
                name: .uploadManagerDone,
                object: pending.uploadId,
                userInfo: [AnyHashable.url: mainUrl]
            )
        }
    }

    // MARK: - Durable pending meta

    private static func persistDurable(_ state: DurablePendingMeta) {
        pendingLock.lock()
        var all = loadDurableUnlocked()
        all[state.uploadId] = state
        saveDurableUnlocked(all)
        pendingLock.unlock()
    }

    private static func markDurableMainSucceeded(uploadId: String, mediaUrl: URL) {
        pendingLock.lock()
        var all = loadDurableUnlocked()
        if var state = all[uploadId] {
            state.mainSucceeded = true
            // Prefer the URL from the completed main PUT (authoritative).
            all[uploadId] = DurablePendingMeta(
                uploadId: state.uploadId,
                mediaUrl: mediaUrl.absoluteString,
                metaHeaders: state.metaHeaders,
                metaTempPath: state.metaTempPath,
                assetId: state.assetId,
                mainSucceeded: true
            )
            saveDurableUnlocked(all)
        }
        pendingLock.unlock()
    }

    private static func removeDurable(uploadId: String) {
        pendingLock.lock()
        var all = loadDurableUnlocked()
        all.removeValue(forKey: uploadId)
        saveDurableUnlocked(all)
        pendingLock.unlock()
    }

    private static func loadDurable() -> [String: DurablePendingMeta] {
        pendingLock.lock()
        defer { pendingLock.unlock() }
        return loadDurableUnlocked()
    }

    private static func loadDurableUnlocked() -> [String: DurablePendingMeta] {
        guard let data = UserDefaults.standard.data(forKey: durableDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: DurablePendingMeta].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private static func saveDurableUnlocked(_ all: [String: DurablePendingMeta]) {
        if all.isEmpty {
            UserDefaults.standard.removeObject(forKey: durableDefaultsKey)
            return
        }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: durableDefaultsKey)
        }
    }

    private static func reconstructPendingMeta(
        from state: DurablePendingMeta,
        session: URLSession
    ) -> PendingMeta? {
        guard let mediaUrl = URL(string: state.mediaUrl) else { return nil }

        var asset: Asset?
        Db.bgRwConn?.read { tx in
            asset = tx.object(for: state.assetId)
        }
        guard let asset else { return nil }

        pendingLock.lock()
        metaTempPaths[state.uploadId] = state.metaTempPath
        completedMainUrls[state.uploadId] = mediaUrl
        pendingLock.unlock()

        let progress = Progress(totalUnitCount: 100)
        UploadManager.shared.attachLiveProgress(progress, for: state.uploadId)

        return PendingMeta(
            uploadId: state.uploadId,
            progress: progress,
            mediaUrl: mediaUrl,
            metaHeaders: state.metaHeaders,
            backgroundSession: session,
            asset: asset
        )
    }

    private func generateHeaders(_ accessKey: String, _ secretKey: String, forMetadata: Bool) -> [String: String] {
        var headers: [String: String] = [
            "Accept": "*/*",
            "authorization": "LOW \(accessKey):\(secretKey)",
            "x-amz-auto-make-bucket": "1",
            "x-archive-auto-make-bucket": "1",
            "x-archive-queue-derive": "0",
        ]

#if DEBUG
        headers["x-archive-meta-collection"] = "test_collection"
#else
        headers["x-archive-meta-collection"] = "opensource_media"
#endif

        if forMetadata {
            // Sidecar file carries Asset JSON — no duplicate editorial headers.
            return headers
        }

        headers["x-archive-interactive-priority"] = "1"
        headers["x-archive-meta-mediatype"] = mediatype(for: asset)

        if let title = asset.title, !title.isEmpty {
            headers["x-archive-meta-title"] = title
        }
        if let desc = asset.desc, !desc.isEmpty {
            headers["x-archive-meta-description"] = desc
        }
        if let author = asset.author, !author.isEmpty {
            headers["x-archive-meta-author"] = author
        }
        if let location = asset.location, !location.isEmpty {
            headers["x-archive-meta-location"] = location
        }
        if let notes = asset.notes, !notes.isEmpty {
            headers["x-archive-meta-notes"] = notes
        }

        var subject = [String]()
        if let projectName = asset.project?.name, !projectName.isEmpty {
            subject.append(projectName)
        }
        if let tags = asset.tags, !tags.isEmpty {
            subject.append(contentsOf: tags)
        }
        if !subject.isEmpty {
            headers["x-archive-meta-subject"] = subject.joined(separator: ";")
        }
        if let license = asset.license, !license.isEmpty {
            headers["x-archive-meta-licenseurl"] = license
        }

        return headers
    }

    private func url(for asset: Asset) -> URL? {
        if let url = asset.publicUrl {
            return url
        }

        var slug = StringUtils.slug(asset.title != nil
                                    ? asset.title!
                                    : StringUtils.stripSuffix(from: asset.filename))
        slug = slug + "-" + StringUtils.random(4)
        return construct(url: IaSpace.baseUrl, slug, asset.filename)
    }

    private func mediatype(for asset: Asset) -> String {
        if asset.uti.conforms(to: UTType.image) {
            return "image"
        }
        if asset.uti.conforms(to: UTType.movie) {
            return "movies"
        }
        if asset.uti.conforms(to: UTType.audio) {
            return "audio"
        }
        return "data"
    }
}
