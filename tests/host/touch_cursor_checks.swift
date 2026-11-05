import Foundation
import CoreGraphics

func checkCursorPacks() throws {
    let identity=BCDControlPack.Identity(executable:"program files (x86)/steam/steamapps/common/noita",storeID:"steam:881100",edition:"installed",build:"unreported",bindingDigest:"44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a")
    let pack=BCDNoitaPack.make(identity:identity);try pack.validate()
    let decoded=try BCDControlPack.decode(JSONEncoder().encode(pack),for:identity);assert(decoded==pack)
    func engine() -> BCDCursorPack {
        let e=BCDCursorPack(pack:pack,pad:false);e.bounds=CGRect(x:0,y:0,width:1000,height:500);e.safe=e.bounds;e.viewport=e.bounds.size;e.guest=e.bounds.size;return e
    }
    func motion(_ events:[BCDCursorPack.Event]) -> (Int,Int) {
        events.reduce((0,0)) { sum,event in if case .motion(let x,let y)=event {return(sum.0+Int(x),sum.1+Int(y))};return sum }
    }
    let e=engine(),aim=CGPoint(x:600,y:200),fire=e.center(pack.phone.controls.first{$0.id=="fire"}!)
    e.begin("look",at:aim,time:0);assert(e.drain().isEmpty)
    e.move("look",to:CGPoint(x:610,y:202),time:0.01);assert(motion(e.drain()).0==10)
    e.move("look",to:CGPoint(x:610,y:202),time:0.02);assert(e.drain().isEmpty)
    e.end("look",at:CGPoint(x:610,y:202),time:0.03,cancelled:false);assert(e.drain().isEmpty)
    e.begin("look2",at:CGPoint(x:700,y:210),time:0.04);assert(e.drain().isEmpty)
    e.move("look2",to:fire,time:0.05)
    var events=e.drain();assert(events.filter{$0 == .button("mouse:left",true)}.count==1)
    e.move("look2",to:CGPoint(x:450,y:150),time:0.06);assert(!e.drain().contains(.button("mouse:left",false)))
    assert(e.firing)
    e.end("look2",at:CGPoint(x:450,y:150),time:0.07,cancelled:false);assert(e.drain()==[.button("mouse:left",false)])
    e.begin("fire",at:fire,time:0.1);assert(e.drain()==[.button("mouse:left",true)])
    e.move("fire",to:CGPoint(x:fire.x-4,y:fire.y+2),time:0.11);assert(motion(e.drain()).0 == -4)
    e.end("fire",at:fire,time:0.12,cancelled:true);assert(e.drain()==[.button("mouse:left",false)])
    // One moving/levitating thumb plus sustained firing; flight releases independently.
    e.begin("move",at:CGPoint(x:150,y:350),time:1)
    e.move("move",to:CGPoint(x:90,y:310),time:1.01)
    assert(e.activeOutputs==["key:65","key:87"])
    e.begin("fire",at:fire,time:1.02);assert(e.activeOutputs.contains("mouse:left"))
    e.move("move",to:CGPoint(x:90,y:345),time:1.03);assert(!e.activeOutputs.contains("key:87") && e.activeOutputs.contains("key:65"))
    e.move("move",to:CGPoint(x:90,y:390),time:1.04);assert(!e.activeOutputs.contains("key:83"))
    e.move("move",to:CGPoint(x:90,y:412),time:1.05);assert(e.activeOutputs.contains("key:83"))
    e.cancel();assert(e.activeOutputs.isEmpty);_ = e.drain()
    // No unrelated control can be acquired by crossing its edge.
    e.begin("look",at:aim,time:2)
    for c in pack.phone.controls.filter({["kick","interact","inventory","equipment"].contains($0.id)}) {e.move("look",to:e.center(c),time:2.1)}
    assert(e.drain().allSatisfy { if case .motion = $0{return true};return false })
    e.end("look",at:aim,time:2.2,cancelled:true);assert(e.drain().isEmpty)
    // Cancel does not process a final boundary crossing as a new shot.
    e.begin("look",at:aim,time:2.3);e.end("look",at:fire,time:2.4,cancelled:true);assert(e.drain().isEmpty)
    let launcher=e.center(pack.phone.controls.first{$0.role=="radial"}!)
    e.begin("move",at:CGPoint(x:100,y:350),time:3);e.move("move",to:CGPoint(x:150,y:310),time:3.01)
    e.begin("fire",at:fire,time:3.02);_ = e.drain()
    e.begin("radial",at:launcher,time:3.03);assert(e.mode == .equipment && !e.firing && e.activeOutputs.contains("key:68"))
    assert(e.drain().contains(.button("mouse:left",false)))
    let ring=e.radialFrame,center=CGPoint(x:ring.midX,y:ring.midY)
    e.move("radial",to:center,time:3.4);e.end("radial",at:center,time:3.5,cancelled:false)
    assert(e.mode == .gameplay && !e.activeOutputs.contains("key:49"));_ = e.drain()
    // An old fire finger cannot resume when a wheel closes.
    e.move("fire",to:fire,time:3.6);assert(!e.firing)
    e.begin("radial2",at:launcher,time:4);e.end("radial2",at:launcher,time:4.1,cancelled:false);assert(e.mode == .equipment)
    let top=CGPoint(x:ring.midX,y:ring.midY-ring.width*0.35)
    assert(e.sector(top)==0 && e.sector(CGPoint(x:ring.midX+ring.width*0.35,y:ring.midY))==2)
    e.begin("choose",at:top,time:4.2);assert(e.mode == .gameplay && !e.firing)
    events=e.drain();assert(events.contains(.button("key:49",true)))
    e.tick(4.3);assert(e.drain().contains(.button("key:49",false)))
    e.cancel();_ = e.drain()
    // Explicit inventory mode: releases gameplay first, cursor-only movement and held-click drag.
    e.begin("fire",at:fire,time:5);_ = e.drain();e.openInventory(time:5.1)
    events=e.drain();assert(events.first == .button("mouse:left",false) && events.contains(.button("key:9",true)))
    assert(e.mode == .pointer)
    e.tick(5.2);_ = e.drain()
    e.begin("cursor",at:aim,time:5.3);assert(e.drain().isEmpty)
    let click=e.overlayButtons.first{$0.0=="click"}!.2
    e.begin("click",at:CGPoint(x:click.midX,y:click.midY),time:5.4);assert(e.drain()==[.button("mouse:left",true)])
    e.move("cursor",to:CGPoint(x:630,y:220),time:5.5);assert(motion(e.drain()).0==30)
    e.end("click",at:CGPoint(x:click.midX,y:click.midY),time:5.6,cancelled:false);assert(e.drain()==[.button("mouse:left",false)])
    e.switchMode(.gameplay);_ = e.drain();assert(e.activeOutputs.isEmpty)
    // Two independent owners of the same output must release independently.
    var duplicate=pack.phone.controls.first{$0.id=="fire"}!
    duplicate.id="left-fire";duplicate.role="button";duplicate.x=0.1;duplicate.y=0.2;duplicate.radius=0.04;duplicate.hitRadius=0.04
    e.layout.controls.append(duplicate)
    e.begin("first",at:fire,time:6);e.begin("second",at:e.center(duplicate),time:6.01)
    assert(e.drain().filter{$0 == .button("mouse:left",true)}.count==1)
    e.end("first",at:fire,time:6.02,cancelled:true);assert(!e.drain().contains(.button("mouse:left",false)))
    e.end("second",at:e.center(duplicate),time:6.03,cancelled:true);assert(e.drain()==[.button("mouse:left",false)])
    e.begin("independent-look",at:aim,time:6.1);e.begin("independent-fire",at:fire,time:6.2)
    assert(e.drain()==[.button("mouse:left",true)])
    e.move("independent-look",to:CGPoint(x:605,y:200),time:6.3);assert(motion(e.drain()).0==5)
    e.end("independent-fire",at:fire,time:6.4,cancelled:true);assert(e.drain()==[.button("mouse:left",false)])
    e.end("independent-look",at:CGPoint(x:605,y:200),time:6.5,cancelled:true)
    // Pause clears a held shot before Escape; recovering mode never sends a click.
    e.begin("held",at:fire,time:7);_ = e.drain();e.pause(time:7.1)
    events=e.drain();assert(events.first == .button("mouse:left",false) && events.contains(.button("key:27",true)))
    e.switchMode(.gameplay);assert(!e.drain().contains(.button("mouse:left",true)))
    // Fresh floating origins on retouch, with no idle visual or inherited keys.
    e.begin("floating",at:CGPoint(x:300,y:320),time:8);assert(e.movementFinger?.start==CGPoint(x:300,y:320))
    e.end("floating",at:CGPoint(x:300,y:320),time:8.1,cancelled:false);assert(e.movementFinger==nil)
    e.begin("floating",at:CGPoint(x:100,y:250),time:8.2);assert(e.movementFinger?.start==CGPoint(x:100,y:250))
    e.cancel();_ = e.drain()
    // Tap-open More, deliberate throw, and central cancel never select equipment.
    e.begin("tap-wheel",at:launcher,time:9);e.end("tap-wheel",at:launcher,time:9.1,cancelled:false)
    let more=e.moreFrame;e.begin("more",at:CGPoint(x:more.midX,y:more.midY),time:9.2);assert(e.mode == .utilities)
    let throwButton=e.overlayButtons.first{$0.0=="throw"}!.2
    e.begin("throw",at:CGPoint(x:throwButton.midX,y:throwButton.midY),time:9.3)
    events=e.drain();assert(events.contains(.button("mouse:right",true)) && !events.contains(.button("mouse:left",true)))
    e.tick(9.4);assert(e.drain().contains(.button("mouse:right",false)))
    e.cancel();_ = e.drain()
    // A long hold without a slide cancels, even if a personal launcher overlaps the ring.
    e.begin("hold-wheel",at:launcher,time:10);e.end("hold-wheel",at:launcher,time:10.5,cancelled:false)
    assert(e.mode == .gameplay && e.drain().isEmpty)
    // Fractional corrections are preserved, independent of input cadence/render scale.
    for hz in [60.0,120.0] { for scale in [0.5,1.0,2.0] {
        let q=engine();q.guest=CGSize(width:1000*scale,height:500*scale)
        q.begin("slow",at:aim,time:0)
        var total=0
        for i in 1...120 {q.move("slow",to:CGPoint(x:600+Double(i)*0.1,y:200),time:Double(i)/hz);total+=motion(q.drain()).0}
        assert(abs(Double(total)-12*scale)<=1)
        q.cancel();assert(q.activeOutputs.isEmpty)
    }}
    // Repeated swipes cross the viewport's left half; no coordinate clipping to the aim area.
    let cursor=engine();var x=800
    for i in 0..<4 {
        cursor.begin(i,at:CGPoint(x:700,y:200),time:Double(i))
        cursor.move(i,to:CGPoint(x:500,y:200),time:Double(i)+0.1);x+=motion(cursor.drain()).0
        cursor.end(i,at:CGPoint(x:500,y:200),time:Double(i)+0.2,cancelled:false);assert(cursor.drain().isEmpty)
    }
    assert(x==0)
    for fps in [30.0,60.0] {
        let q=engine();q.begin("radial",at:launcher,time:0);q.end("radial",at:launcher,time:0.1,cancelled:false);q.begin("slot",at:top,time:0.2)
        assert(q.activeOutputs.contains("key:49"));_ = q.drain()
        q.tick(0.2+1/fps);assert(q.activeOutputs.contains("key:49"))
        q.tick(0.28+1/fps);assert(!q.activeOutputs.contains("key:49"))
    }
    var invalid=pack;invalid.version=3;assert((try? invalid.validate())==nil)
    invalid=pack;invalid.cursorControls?.fire="missing";assert((try? invalid.validate())==nil)
    invalid=pack;invalid.digitalMovement?.downThreshold=0;assert((try? invalid.validate())==nil)
    // Personal calibration and regions survive regeneration and JSON round trips.
    var personal=pack;personal.cursorControls?.firingMultiplier=0.8;personal.digitalMovement?.downThreshold=1.1
    let merged=try BCDPackAuthoring.merge(base:pack,personal:personal,baseline:pack);assert(merged.cursorControls==personal.cursorControls && merged.digitalMovement==personal.digitalMovement)
    if let target=ProcessInfo.processInfo.environment["NOITA_PACK_EXPORT"] {
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
        try encoder.encode(pack).write(to:URL(fileURLWithPath:target))
    }
    print("PASS: cursor continuity, stationary/retouch, direct and slide fire, simultaneous digital movement/flight/fire, deep down, unrelated crossing, radial cancel/slot fire quarantine, explicit pointer dragging, focus-style cancel, fractional 60/120Hz/render-scale corrections, V4 validation and override regeneration; host engine fixture, no game")
}
