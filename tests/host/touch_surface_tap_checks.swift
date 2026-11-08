import Foundation

enum SurfaceTapChecks {
    static func run() {
        let gate=UUID(),other=UUID(),origin=CGPoint(x:400,y:200)
        func candidate(_ start:CGPoint=CGPoint(x:400,y:200),_ at:Double=10) -> BCDPackSurfaceTap {
            BCDPackSurfaceTap(action:"attack",gate:"aim",gateOwner:gate,start:start,began:at)
        }
        var tap=candidate()
        assert(tap.recognizes(end:origin,time:10.1,gateOwner:gate))
        assert(!tap.recognizes(end:origin,time:10.1,gateOwner:nil))
        assert(!tap.recognizes(end:origin,time:10.1,gateOwner:other))
        assert(!tap.recognizes(end:origin,time:10.36,gateOwner:gate))
        assert(!tap.recognizes(end:origin,time:9,gateOwner:gate))
        assert(!tap.recognizes(end:CGPoint(x:Double.nan,y:0),time:10.1,gateOwner:gate))
        tap.moved(to:CGPoint(x:440,y:200));tap.moved(to:origin)
        assert(!tap.recognizes(end:origin,time:10.1,gateOwner:gate),"Out-and-back movement became a tap")
        tap=candidate();tap.moved(to:CGPoint(x:Double.nan,y:0));tap.moved(to:origin)
        assert(!tap.recognizes(end:origin,time:10.1,gateOwner:gate))
        // A new touch has its own stable origin on either half of the display.
        for p in [CGPoint(x:30,y:350),CGPoint(x:900,y:90)] {
            assert(candidate(p,20).recognizes(end:p,time:20.1,gateOwner:gate))
        }
        var sequence=BCDPackTapPulses()
        assert(sequence.enqueue(now:0)==true)
        assert(sequence.enqueue(now:0.02)==nil)
        assert(sequence.advance(now:0.051)==false)
        assert(sequence.advance(now:0.07)==nil)
        assert(sequence.advance(now:0.092)==true)
        assert(sequence.advance(now:0.143)==false)
        assert(sequence.advance(now:0.184)==nil && sequence.idle)
        // Main-thread delays cannot compress a real neutral interval to zero.
        assert(sequence.enqueue(now:1)==true);_ = sequence.enqueue(now:1.01)
        assert(sequence.advance(now:3)==false)
        assert(sequence.advance(now:3.001)==nil)
        assert(sequence.advance(now:3.041)==true)
        sequence.cancel();assert(sequence.idle && !sequence.down)
        assert(sequence.advance(now:100)==nil)
        assert(sequence.enqueue(now:.nan)==nil)
        print("PASS: aimed tap gate lifetime, touch slop, hold rejection, retouch, queued edges, neutral gaps and cancellation")
    }
}
