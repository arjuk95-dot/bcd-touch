// Engine boundary stubs for SDK typechecking the production UIKit/SwiftUI pack surface.
import Foundation
import Combine
import UIKit
struct LibraryEntry {
    var id = UUID(); var title = "Fixture"; var desktop: Bool?; var steamAppID: Int?
    var launchRelativePath = "fixture.exe"; var relativePath = "fixture.exe"; var steamMetadataInstall: String?; var controllerBinds: [String:String]?
    static let hostDrive = URL(fileURLWithPath:"/tmp/fixture-drive")
    static func hostURL(ofWindowsPath:String) -> URL? { hostDrive.appendingPathComponent("fixture.exe") }
}
@MainActor final class LibraryModel: ObservableObject {
    static let shared = LibraryModel()
    @Published var blocksGameplayTouch = false
    var current:NSObject?
    var menu=false, launching=false
    var menuButtonRect=CGRect.zero, performanceRect=CGRect.zero
}
@MainActor final class GamepadInput {
    static let shared = GamepadInput()
    static var sessionHIDKind:String?
    func configurePack(enabled:Bool, accepting:Bool, calibration:BCDMouseJoystick.Calibration) {}
    func packTouch(owner:UUID,value:GamepadSample?) {}
    func packLook(owner:UUID,phase:Int,dx:Double=0,dy:Double=0,time:Double) {}
}
@MainActor final class HardwareInput {
    static let shared = HardwareInput()
    func postRelative(_ x:Int32,_ y:Int32) {}
    var pointerHeldByProgram=false
    static var fixturePointer=false
    static func isPointerEvent(_ event:UIEvent?) -> Bool { fixturePointer }
}
@MainActor final class TouchControlsModel {
    static let shared=TouchControlsModel()
    var editing=false, sessionPanel=false
    func hitsInteractive(_ point:CGPoint,in bounds:CGRect,topBar:Bool=true)->Bool { false }
}
@MainActor enum ControlPresetsModel { static let enabled=false }
@MainActor final class BCDTouchFeelModel {
    static let shared=BCDTouchFeelModel();var seconds=0.0
    static func fingersDown(in event:UIEvent)->Int { 0 }
    func controlsTouched(fingers:Int) {}
}
enum MadeiraConfig { static func gameValue(_ name:String)->String? { nil };static func get(_ name:String)->String? { nil } }
@MainActor final class LogStore { static let shared=LogStore();func log(_ message:String) {} }
@MainActor final class BCDInputLive { static let shared = BCDInputLive(); func refresh() {} }
func winios_post_key(_ key:Int32,_ down:Int32) {}
func winios_pointer(_ x:Int32,_ y:Int32,_ flags:UInt32,_ wheel:Int32) {}
