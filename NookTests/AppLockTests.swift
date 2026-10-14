import Testing
import SwiftUI
@testable import Nook

/// L-02, S-05 and the Private-item lock (PRD F11, §9, D61), on a fake clock and a fake Face ID.
@MainActor
struct AppLockTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_800_000_000) }
    let clock = Clock()
    // Tests run in parallel: each gets its own defaults.
    let defaults = UserDefaults(suiteName: "AppLockTests.\(UUID().uuidString)")!

    func makeLock(enabled: Bool = false, timing: LockTiming = .immediately, passes: Bool = true,
                  method: AppLock.Method = .faceID) -> AppLock {
        defaults.set(enabled, forKey: AppLock.enabledKey)
        defaults.set(timing.rawValue, forKey: AppLock.timingKey)
        let clock = clock
        return AppLock(defaults: defaults, now: { clock.now }, method: { method }, authenticate: { _ in passes })
    }

    @Test func coldLaunchWithTheLockOnStartsLocked() {
        #expect(makeLock(enabled: true).isLocked)
        #expect(!makeLock(enabled: false).isLocked)
    }


    @Test func unlockOpensNookAndPrivateItems() async {
        let lock = makeLock(enabled: true)
        #expect(await lock.unlock())
        #expect(!lock.isLocked && lock.privateUnlocked)
        lock.sceneChanged(to: .background)
        #expect(lock.isLocked && !lock.privateUnlocked)
    }

    @Test(arguments: [LockTiming.oneMinute, .fiveMinutes])
    func timedLockWaitsForItsTimer(_ timing: LockTiming) async {
        let lock = makeLock(enabled: true, timing: timing)
        await lock.unlock()
        lock.sceneChanged(to: .background)
        clock.now += Double(timing.rawValue) - 1
        lock.sceneChanged(to: .active)
        #expect(!lock.isLocked && lock.privateUnlocked)   // D61: Private stays open with the lock's timer

        lock.sceneChanged(to: .background)
        clock.now += Double(timing.rawValue)
        lock.sceneChanged(to: .active)
        #expect(lock.isLocked && !lock.privateUnlocked)
    }

    @Test func withTheLockOffPrivateItemsCloseOnBackground() async {
        let lock = makeLock()
        #expect(await lock.unlockPrivate())
        #expect(lock.privateUnlocked)
        lock.sceneChanged(to: .inactive)
        #expect(lock.privateUnlocked)   // the Face ID sheet itself makes Nook inactive
        lock.sceneChanged(to: .background)
        #expect(!lock.privateUnlocked)
    }

    @Test func aFailedUnlockStaysLocked() async {
        let lock = makeLock(enabled: true, passes: false)
        #expect(!(await lock.unlock()))
        #expect(lock.isLocked && lock.failures == 1)
        #expect(!(await lock.unlockPrivate()))
        #expect(!lock.privateUnlocked)
    }

    @Test func turningTheLockOnAsksFirst() async {
        let failing = makeLock(passes: false)
        await failing.setEnabled(true)
        #expect(!failing.isEnabled)

        let passing = makeLock()
        await passing.setEnabled(true)
        #expect(passing.isEnabled && defaults.bool(forKey: AppLock.enabledKey))

        let noPasscode = makeLock(method: .unavailable)
        await noPasscode.setEnabled(true)
        #expect(!noPasscode.isEnabled)
    }

    @Test func theCoverHidesNookOutOfViewOnlyWhenSomethingIsPrivate() async {
        let off = makeLock()
        #expect(!off.covers(.inactive))
        await off.unlockPrivate()
        #expect(off.covers(.inactive) && !off.covers(.active))

        let on = makeLock(enabled: true)
        #expect(on.covers(.active))   // locked
        await on.unlock()
        #expect(!on.covers(.active) && on.covers(.background))
    }
}
