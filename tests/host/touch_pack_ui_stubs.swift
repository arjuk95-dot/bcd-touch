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
}
@MainActor final class BCDInputLive { static let shared = BCDInputLive(); func refresh() {} }
func winios_post_key(_ key:Int32,_ down:Int32) {}
func winios_pointer(_ x:Int32,_ y:Int32,_ flags:UInt32,_ wheel:Int32) {}
