// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
func checkQueensGesturePolicy() {
    func chord(_ q: inout BCDQueensGesturePolicy, _ start:Double, _ end:Double) -> [BCDQueensGesturePolicy.Event] {
        assert(q.begin(at:.zero,time:start,possibleChord:true).isEmpty)
        assert(q.canClaimChord(time:start+0.05))
        assert(q.claimChord(time:start+0.05))
        return q.twoFingerTap(time:end)
    }
    var q=BCDQueensGesturePolicy()
    assert(q.begin(at:.zero,time:0).isEmpty)
    assert(!q.canClaimChord(time:0.05))
    assert(q.end(at:.zero,time:0.1) == [.attackDown,.attackUp])
    _=q.begin(at:.zero,time:1,possibleChord:true)
    assert(q.move(to:CGPoint(x:13,y:0)).isEmpty)
    assert(!q.canClaimChord(time:1.05));assert(q.end(at:.zero,time:1.1).isEmpty)
    _=q.begin(at:.zero,time:2,possibleChord:true)
    assert(q.advance(time:2.29) == [.attackDown] && q.hasCommittedAttack)
    assert(!q.canClaimChord(time:2.3) && !q.claimChord(time:2.3))
    assert(q.move(to:CGPoint(x:50,y:0)).isEmpty && q.hasCommittedAttack)
    assert(q.end(at:CGPoint(x:50,y:0),time:2.4) == [.attackUp])
    assert(!q.hasCommittedAttack)
    _=q.begin(at:.zero,time:3);assert(q.advance(time:3.3) == [.attackDown])
    assert(q.cancel() == [.attackUp]);assert(q.cancel().isEmpty)
    // No bare recognizer callback can synthesize a utility without ownership.
    assert(q.twoFingerTap(time:4).isEmpty);assert(q.advance(time:5).isEmpty)
    assert(chord(&q,6,6.1).isEmpty)
    assert(q.advance(time:6.3).isEmpty);assert(q.advance(time:6.401) == [.equipment])
    // A valid second chord can straddle the pending single's deadline.
    q.journalEnabled=true
    assert(chord(&q,7,7.1).isEmpty)
    _=q.begin(at:.zero,time:7.35,possibleChord:true);assert(q.claimChord(time:7.4))
    assert(q.advance(time:7.45).isEmpty)
    assert(q.twoFingerTap(time:7.55) == [.journal]);assert(q.advance(time:8).isEmpty)
    // Replicated regressions: any confirmed new combat input cancels equipment.
    assert(chord(&q,9,9.1).isEmpty)
    _=q.begin(at:.zero,time:9.2);assert(q.advance(time:9.41).isEmpty)
    assert(q.end(at:.zero,time:9.42) == [.attackDown,.attackUp])
    assert(chord(&q,10,10.1).isEmpty);_=q.cancelAttack();assert(q.advance(time:10.5).isEmpty)
    assert(chord(&q,11,11.1).isEmpty)
    _=q.begin(at:.zero,time:11.2,possibleChord:true)
    assert(q.advance(time:11.321).isEmpty);assert(!q.canClaimChord(time:11.322))
    assert(q.advance(time:11.41).isEmpty);_=q.cancel()
    assert(chord(&q,12,12.1).isEmpty)
    _=q.begin(at:.zero,time:12.2,possibleChord:true);_=q.move(to:CGPoint(x:12,y:0))
    assert(!q.claimChord(time:12.25));assert(q.advance(time:12.5).isEmpty)
    // Invalid/replaced/overlong chords are canceled, never rearmed by release.
    assert(chord(&q,13,13.1).isEmpty)
    _=q.begin(at:.zero,time:13.2,possibleChord:true);assert(q.claimChord(time:13.25))
    q.cancelPendingUtility();assert(q.twoFingerTap(time:13.3).isEmpty);assert(q.advance(time:14).isEmpty)
    _=q.begin(at:.zero,time:15,possibleChord:true);assert(!q.canClaimChord(time:15.121))
    _=q.cancel();_=q.begin(at:.zero,time:16,possibleChord:true);assert(q.claimChord(time:16.05))
    assert(q.advance(time:16.351).isEmpty);assert(q.twoFingerTap(time:16.36).isEmpty)
    assert(q.advance(time:17).isEmpty)
    for bad in [Double.nan,Double.infinity,-Double.infinity] {
        _=q.begin(at:.zero,time:18,possibleChord:true);assert(!q.canClaimChord(time:bad))
        assert(q.advance(time:bad).isEmpty);assert(q.end(at:.zero,time:18.1).isEmpty)
        assert(q.begin(at:CGPoint(x:bad,y:0),time:19).isEmpty)
        assert(q.end(at:.zero,time:19.1).isEmpty)
    }
    _=q.begin(at:.zero,time:20);assert(q.advance(time:19).isEmpty)
    assert(q.end(at:.zero,time:20.1).isEmpty)
    // Disabled/unverified journal never emits a guessed action.
    q.journalEnabled=false
    assert(chord(&q,21,21.1).isEmpty);assert(chord(&q,21.2,21.3) == [.equipment])
    print("PASS: Queen committed-charge ownership, provisional chord arbitration, delayed utility cancellation, double timing and invalid input guards")
}
