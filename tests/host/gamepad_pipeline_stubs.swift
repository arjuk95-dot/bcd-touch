// Engine spies for the production GamepadInput publisher. This is not a Wine guest.
import Foundation
import GameController
struct winios_gamepad { var connected:Int32=0;var buttons:UInt16=0;var left_trigger:UInt8=0;var right_trigger:UInt8=0;var lx:Int16=0;var ly:Int16=0;var rx:Int16=0;var ry:Int16=0 }
struct winios_hidpad { var connected:Int32=0;var buttons:UInt32=0;var left_trigger:UInt8=0;var right_trigger:UInt8=0;var lx:Int16=0;var ly:Int16=0;var rx:Int16=0;var ry:Int16=0;var battery:UInt8=0;var charging:UInt8=0 }
let WINIOS_HIDPAD_BATTERY_UNKNOWN=255
let WINIOS_HIDPAD_L2:UInt32=0x10000, WINIOS_HIDPAD_R2:UInt32=0x20000, WINIOS_HIDPAD_TOUCHPAD:UInt32=0x40000
enum PipelineSpy {
    static let lock=NSLock()
    static var state=winios_gamepad()
    static var simultaneous=false
    static var triggerAtGyro=false
    static var disconnectedPublications=0
    static func disconnectedCount()->Int {lock.lock();defer{lock.unlock()};return disconnectedPublications}
    static func read() -> (winios_gamepad,Bool,Bool) { lock.lock();defer {lock.unlock()};return(state,simultaneous,triggerAtGyro) }
}
func winios_gamepad_set_state(_ slot:Int32,_ state:UnsafePointer<winios_gamepad>?) {
    guard slot==0 else{return};PipelineSpy.lock.lock();defer{PipelineSpy.lock.unlock()}
    PipelineSpy.state=state?.pointee ?? winios_gamepad()
    if state==nil {PipelineSpy.disconnectedPublications += 1}
    let s=PipelineSpy.state
    if s.lx != 0 && s.right_trigger != 0 && (s.rx != 0 || s.ry != 0) {PipelineSpy.simultaneous=true}
}
func winios_gamepad_set_vibration(_ slot:Int32,_ left:UInt16,_ right:UInt16) {}
func winios_hidpad_set_state(_ state:UnsafePointer<winios_hidpad>?) {}
func madeira_pad_output_configure(_ x:Int32,_ h:Int32) {}
func madeira_pad_output_set_active(_ x:Int32) {}
func madeira_pad_output_set_slot(_ slot:Int32,_ controller:GCController?) {}
enum MadeiraConfig {
    nonisolated(unsafe) static var fixtureGameValues: [String:String] = [:]
    static func get(_ key:String)->String?{nil}
    static func gameValue(_ key:String)->String?{fixtureGameValues[key]}
}
final class LogStore {static let shared=LogStore();func log(_ text:String){print(text)}}
enum SystemGestures {static func beginSession(enabled:Bool){};static func apply(_ c:[GCController]){}}
struct PadBindings {}
final class PadKeyboardMouse {
    static let shared=PadKeyboardMouse();var holding=false
    func releaseAll(_ why:String){}
    func feed(buttons:UInt16,lt:UInt8,rt:UInt8,lx:Int16,ly:Int16,rx:Int16,ry:Int16,bindings:PadBindings,focused:Bool){}
}
enum BCDPlayersLive {
    static var listening = -1;static var touchSlot=0
    static func pressed(in profiles:[GCExtendedGamepad?])->Int?{nil}
    static func keys(for c:[GCController])->[ObjectIdentifier:String]{[:]}
    static func slot(forKey key:String?,occupied:[Bool])->Int?{occupied.firstIndex(of:false)}
    static func report(_ c:[GCController?]){}
}
extension GamepadInput {func assignListened(_ index:Int){}}
final class LibraryController {
    static let shared=LibraryController();var ownsInput=false
    func sample(buttons:UInt16,lx:Int16,ly:Int16){}
}
final class HardwareInput {static let shared=HardwareInput();var baseFocused=true}
final class BCDGyroLive {
    static let shared=BCDGyroLive();static var stickActive=false;static var padNeeded=true
    func padSample(_ s:inout winios_gamepad){PipelineSpy.lock.lock();if s.right_trigger==255 {PipelineSpy.triggerAtGyro=true};PipelineSpy.lock.unlock()}
}
final class BCDTurboLive {static let shared=BCDTurboLive();static var padNeeded=false;func padSample(_ s:inout winios_gamepad){}}
