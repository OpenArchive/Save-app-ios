//
//  IaCooldownManager.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation

final class IaCooldownManager {

    static let shared = IaCooldownManager()

    private enum Keys {
        static let cooldownUntil = "iaCooldownUntil"
        static let cooldownMinutes = "iaCooldownMinutes"
        static let hadSuccessSinceCooldown = "iaHadSuccessSinceCooldown"
        static let expiryGeneration = "iaExpiryGeneration"
    }

    private let defaults = UserDefaults.standard
    private var wakeTimer: DispatchSourceTimer?
    private var lastWokenGeneration = 0
    private var onWake: (() -> Void)?
    private var onCooldownStarted: (() -> Void)?
    private var lastBlockingLogDate: Date?

    private init() {}

    var isActive: Bool {
        guard let until = cooldownUntil else {
            return false
        }

        return Date() < until
    }

    /// Seconds left until cooldown expires; `nil` when no cooldown is scheduled.
    var remainingSeconds: Int? {
        guard let until = cooldownUntil else { return nil }
        return max(0, Int(until.timeIntervalSinceNow.rounded()))
    }

    var scheduledMinutes: Int { cooldownMinutes }

    private var cooldownUntil: Date? {
        get { defaults.object(forKey: Keys.cooldownUntil) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.cooldownUntil)
            } else {
                defaults.removeObject(forKey: Keys.cooldownUntil)
            }
        }
    }

    private var cooldownMinutes: Int {
        get {
            let stored = defaults.integer(forKey: Keys.cooldownMinutes)
            return stored > 0 ? stored : UploadQueuePolicy.iaCooldownInitialMinutes
        }
        set { defaults.set(newValue, forKey: Keys.cooldownMinutes) }
    }

    private var hadSuccessSinceCooldown: Bool {
        get { defaults.bool(forKey: Keys.hadSuccessSinceCooldown) }
        set { defaults.set(newValue, forKey: Keys.hadSuccessSinceCooldown) }
    }

    private var expiryGeneration: Int {
        get { defaults.integer(forKey: Keys.expiryGeneration) }
        set { defaults.set(newValue, forKey: Keys.expiryGeneration) }
    }

    func configure(onWake: @escaping () -> Void, onCooldownStarted: (() -> Void)? = nil, queue: DispatchQueue) {
        self.onWake = onWake
        self.onCooldownStarted = onCooldownStarted
        if isActive {
            IaCooldownLog.log(
                "cooldown_restored",
                minutes: scheduledMinutes,
                remainingSec: remainingSeconds
            )
        }
        scheduleWakeTimer(on: queue)
    }

    func startCooldown(on queue: DispatchQueue, reason: String = "ia503") {
        // Only one cooldown timer at a time — keep the existing deadline if still active.
        if isActive {
            IaCooldownLog.log(
                "cooldown_already_active",
                minutes: cooldownMinutes,
                remainingSec: remainingSeconds,
                reason: reason
            )
            return
        }

        // Fresh park must use the current policy duration — ignore stale UserDefaults
        // leftovers from older 10‑minute cooldowns.
        if reason != "retry_still_503" {
            cooldownMinutes = UploadQueuePolicy.iaCooldownInitialMinutes
        }

        expiryGeneration += 1
        hadSuccessSinceCooldown = false
        cooldownUntil = Date().addingTimeInterval(TimeInterval(cooldownMinutes * 60))
        lastBlockingLogDate = nil
        IaCooldownLog.log(
            "cooldown_started",
            minutes: cooldownMinutes,
            remainingSec: remainingSeconds,
            reason: reason
        )
        scheduleWakeTimer(on: queue)
        onCooldownStarted?()
    }

    func onRetryFailedWith503(on queue: DispatchQueue) {
        guard !isActive, !hadSuccessSinceCooldown else {
            return
        }

        cooldownMinutes = min(
            cooldownMinutes + UploadQueuePolicy.iaCooldownIncrementMinutes,
            UploadQueuePolicy.iaCooldownMaxMinutes
        )
        IaCooldownLog.log(
            "cooldown_extended",
            minutes: cooldownMinutes,
            reason: "retry_still_503"
        )
        startCooldown(on: queue, reason: "retry_still_503")
    }

    func recordIaSuccess(on queue: DispatchQueue) {
        // Any IA success means the server accepted work — drop the single cooldown timer immediately.
        _ = queue
        let hadCooldown = cooldownUntil != nil || wakeTimer != nil
        cancelWakeTimer()
        cooldownUntil = nil
        cooldownMinutes = UploadQueuePolicy.iaCooldownInitialMinutes
        hadSuccessSinceCooldown = true
        lastBlockingLogDate = nil
        defaults.removeObject(forKey: "iaConsecutive503Count")
        if hadCooldown {
            IaCooldownLog.log("cooldown_cleared", reason: "ia_upload_success")
        }
    }

    func reset(on queue: DispatchQueue, reason: String = "manual") {
        _ = queue
        let hadCooldown = cooldownUntil != nil || wakeTimer != nil
        cancelWakeTimer()
        cooldownUntil = nil
        cooldownMinutes = UploadQueuePolicy.iaCooldownInitialMinutes
        hadSuccessSinceCooldown = false
        lastBlockingLogDate = nil
        defaults.removeObject(forKey: "iaConsecutive503Count")
        if hadCooldown {
            IaCooldownLog.log("cooldown_cleared", reason: reason)
        }
    }

    /// Throttled log while IA 503 retries are waiting for cooldown to finish.
    func logBlockingIfNeeded(pendingIa503: Int) {
        guard isActive, pendingIa503 > 0 else { return }

        let now = Date()
        if let last = lastBlockingLogDate, now.timeIntervalSince(last) < 60 {
            return
        }
        lastBlockingLogDate = now
        IaCooldownLog.log(
            "cooldown_active",
            minutes: scheduledMinutes,
            remainingSec: remainingSeconds,
            pendingIa503: pendingIa503
        )
    }

    func shouldWakeForExpiredCooldown(pendingIa503: Bool) -> Bool {
        !isActive && pendingIa503 && expiryGeneration > lastWokenGeneration
    }

    func markWokenForCurrentExpiry() {
        lastWokenGeneration = expiryGeneration
    }

    func hadExpiredCooldownBefore503() -> Bool {
        cooldownUntil != nil && !isActive
    }

    private func scheduleWakeTimer(on queue: DispatchQueue) {
        cancelWakeTimer()

        guard let until = cooldownUntil else {
            return
        }

        let interval = until.timeIntervalSinceNow
        guard interval > 0 else {
            return
        }

        IaCooldownLog.log(
            "cooldown_timer_scheduled",
            minutes: cooldownMinutes,
            remainingSec: Int(interval.rounded())
        )

        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        // One-shot wake only — never a repeating cooldown timer.
        timer.schedule(deadline: .now() + interval, repeating: .never)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.cancelWakeTimer()
            IaCooldownLog.log("cooldown_expired", reason: "timer")
            self.onWake?()
        }
        timer.resume()
        wakeTimer = timer
    }

    private func cancelWakeTimer() {
        wakeTimer?.cancel()
        wakeTimer = nil
    }
}
