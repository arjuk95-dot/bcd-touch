// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Single unobstructed aim-surface owner only. Observe the full move path before
/// advancing time. The adapter separately verifies both chord contacts, controls,
/// maximum excursion, focus and context. Utility state is not guest game state.
struct BCDQueensGesturePolicy {
    enum Event: Equatable { case attackDown, attackUp, equipment, journal }
    var swipeThreshold: Double = 12
    var holdDelay: Double = 0.28
    var doubleTapWindow: Double = 0.30
    var journalEnabled = false
    private let chordOnsetWindow = 0.12
    private let chordMaximumDuration = 0.35
    private var began: Double?
    private var start = CGPoint.zero
    private var travel: Double = 0
    private var attacking = false
    private var possibleChord = false
    private var claimedChordBegan: Double?
    private var pendingTwoFingerTap: Double?

    var hasCommittedAttack: Bool { attacking }
    func canClaimChord(time: Double) -> Bool {
        guard possibleChord, !attacking, claimedChordBegan == nil, let began,
              time.isFinite, time >= began else { return false }
        return time-began <= chordOnsetWindow && travel < swipeThreshold
    }
    /// Only an otherwise empty, eligible surface may request possibleChord.
    /// Confirmed single actions must not preserve an earlier delayed utility.
    mutating func begin(at point: CGPoint, time: Double, possibleChord: Bool = false) -> [Event] {
        let releases=stopAttack()
        claimedChordBegan=nil
        guard point.x.isFinite, point.y.isFinite, time.isFinite else {
            cancelPendingUtility(); return releases
        }
        if !possibleChord { cancelPendingUtility() }
        if let pending=pendingTwoFingerTap, time < pending || time-pending > doubleTapWindow {
            cancelPendingUtility()
        }
        start=point; began=time; travel=0; self.possibleChord=possibleChord
        return releases
    }
    /// Atomic ownership transfer: a committed charge is NEVER released/reclaimed
    /// as a utility gesture. The prior delayed utility remains suspended until the
    /// adapter reports a valid twoFingerTap or explicitly cancels the chord.
    @discardableResult mutating func claimChord(time: Double) -> Bool {
        guard canClaimChord(time:time), let began else { return false }
        _=stopAttack()
        claimedChordBegan=began
        return true
    }
    mutating func cancelPendingUtility() {
        pendingTwoFingerTap=nil; claimedChordBegan=nil; possibleChord=false
    }
    mutating func confirmSingleAction() { cancelPendingUtility() }

    mutating func move(to point: CGPoint) -> [Event] {
        guard began != nil else { return [] }
        guard point.x.isFinite, point.y.isFinite else { return cancel() }
        travel=max(travel,Double(hypot(point.x-start.x,point.y-start.y)))
        if travel >= swipeThreshold {
            confirmSingleAction()
            if !attacking { return stopAttack() }
        }
        return []
    }
    mutating func advance(time: Double) -> [Event] {
        guard time.isFinite else { return cancel() }
        if let began, time < began { return cancel() }
        if let chord=claimedChordBegan {
            if time < chord || time-chord > chordMaximumDuration { cancelPendingUtility() }
            return [] // Never emit equipment while a second chord is held.
        }
        var result:[Event]=[]
        if let began {
            if possibleChord && time-began > chordOnsetWindow { confirmSingleAction() }
            if time >= began+holdDelay, !attacking {
                confirmSingleAction(); attacking=true; result.append(.attackDown)
            }
        } else if let pending=pendingTwoFingerTap {
            if time < pending { cancelPendingUtility() }
            else if time-pending > doubleTapWindow {
                pendingTwoFingerTap=nil; result.append(.equipment)
            }
        }
        return result
    }
    mutating func end(at point: CGPoint, time: Double) -> [Event] {
        let moves=move(to:point)
        guard let began, time.isFinite, time >= began else { return moves + cancelAttack() }
        confirmSingleAction()
        let committed=attacking
        _=stopAttack()
        return moves + (committed ? [.attackUp] : [.attackDown,.attackUp])
    }
    /// Required: successful claimChord, then independent validation of BOTH
    /// releases by the adapter. Double timing uses the second chord's FIRST touch,
    /// allowing its valid held duration without firing the pending single early.
    mutating func twoFingerTap(time: Double) -> [Event] {
        guard let chord=claimedChordBegan else { cancelPendingUtility(); return [] }
        guard time.isFinite, time >= chord, time-chord <= chordMaximumDuration else {
            cancelPendingUtility(); return []
        }
        claimedChordBegan=nil
        if let pending=pendingTwoFingerTap {
            pendingTwoFingerTap=nil
            if chord >= pending && chord-pending <= doubleTapWindow {
                return [journalEnabled ? .journal : .equipment]
            }
        }
        pendingTwoFingerTap=time
        return []
    }
    /// Button, extra finger, focus or context cancellation must also discard any
    /// delayed utility. Use claimChord, not this method, to preserve a valid pair.
    mutating func cancelAttack() -> [Event] {
        cancelPendingUtility()
        return stopAttack()
    }
    mutating func cancel() -> [Event] { cancelAttack() }
    private mutating func stopAttack() -> [Event] {
        began=nil; travel=0; possibleChord=false
        defer { attacking=false }
        return attacking ? [.attackUp] : []
    }
}
