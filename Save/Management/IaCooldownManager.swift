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

        cooldownMinutes += UploadQueuePolicy.iaCooldownIncrementMinutes
        IaCooldownLog.log(
            "cooldown_extended",
            minutes: cooldownMinutes,
            reason: "retry_still_503"
        )
        startCooldown(on: queue, reason: "retry_still_503")
    }

    func recordIaSuccess(on queue: DispatchQueue) {
        reset(on: queue, reason: "ia_upload_success")
    }

    func reset(on queue: DispatchQueue, reason: String = "manual") {
        let wasScheduled = cooldownUntil != nil
        cancelWakeTimer()
        cooldownUntil = nil
        cooldownMinutes = UploadQueuePolicy.iaCooldownInitialMinutes
        hadSuccessSinceCooldown = false
        lastBlockingLogDate = nil
        if wasScheduled {
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
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
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
