// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum BCDNoitaPack {
    static func matches(_ identity: BCDControlPack.Identity) -> Bool {
        identity.storeID == "steam:881100" || identity.executable.replacingOccurrences(of:"\\",with:"/").split(separator:"/").last?.lowercased() == "noita.exe"
    }
    /// Defaults are the owner's specified KB/M set until installed metadata or
    /// an explicit personal binding confirms/replaces them. Never claim a read.
    static func make(identity: BCDControlPack.Identity, bindings: [String:String] = [:]) -> BCDControlPack {
        let definitions:[(String,String,String,String,String)] = [
            ("move-left","Move left","arrow.left","key:65","hold"),
            ("move-right","Move right","arrow.right","key:68","hold"),
            ("levitate","Levitate","chevron.up.2","key:87","hold"),
            ("down-eat","Down / Eat","arrow.down","key:83","hold"),
            ("use-selected","Fire / Use","bcd.wand","mouse:left","hold"),
            ("kick","Kick","bcd.boot","key:70","hold"),
            ("interact","Interact","bcd.interact","key:69","tap"),
            ("inventory","Inventory","bcd.inventory","key:9","tap"),
            ("pause","Pause","pause","key:27","tap"),
            ("throw","Throw selected item","arrow.up.forward","mouse:right","tap"),
            ("pointer-select","Select / drag","cursorarrow","mouse:left","hold"),
            ("pointer-secondary","Secondary click","cursorarrow.click.2","mouse:right","hold")
        ]
        var actions=definitions.map { id,label,icon,output,behavior in BCDControlPack.Action(id:id,label:label,icon:icon,output:output,behavior:behavior,evidence:"requested-defaults",contexts:["onFoot","pointer"]) }
        for i in 1...8 { actions.append(.init(id:"slot-\(i)",label:"\(i<=4 ? "Wand":"Item") slot \(i)",icon:i<=4 ? "bcd.wand":"bcd.inventory",output:"key:\(48+i)",behavior:"tap",evidence:"requested-defaults",contexts:["onFoot"])) }
        func layout(pad: Bool) -> BCDControlPack.Layout {
            func c(_ id: String,_ action: String,_ role: String,_ x: Double,_ y: Double,_ r: Double) -> BCDControlPack.Control {
                .init(id:id,action:action,role:role,x:x,y:y,radius:r,hitRadius:r,opacity:0.75,labelPlacement:"inside")
            }
            return .init(aimRect:.init(x:0.42,y:0.12,width:0.58,height:0.88),controls:[
                c("move","move-left","move",0.17,0.76,pad ? 0.12:0.145),
                c("inventory","inventory","button",0.04,0.08,0.042),
                c("pause","pause","button",0.96,0.08,0.042),
                c("fire","use-selected","fireAim",pad ? 0.91:0.90,0.74,pad ? 0.085:0.105),
                c("kick","kick","button",0.83,0.47,0.065),
                c("interact","interact","button",0.95,0.40,0.067),
                c("equipment","slot-1","radial",pad ? 0.79:0.73,0.90,0.068)
            ],movementRect:.init(x:0,y:0.25,width:0.42,height:0.75))
        }
        var pack=BCDControlPack(version:4,id:"noita-cursor-v4",title:"Noita",identity:identity,inputMode:"keyboardMouse",aim:.init(),actions:actions,phone:layout(pad:false),pad:layout(pad:true),gestures:[],radial:(1...8).map { "slot-\($0)" },contexts:["onFoot","pointer"],evidence:[.init(id:"requested-defaults",source:"Owner's Noita KB/M specification",detail:"Expected defaults: A/D horizontal, W levitation, S down/eat, left mouse uses selected item, right mouse throws, F kick, E interact, Tab inventory, number keys 1–8 equipment, Escape pause. These expected defaults alone are not proof of installed remaps.")],unresolved:["Installed binding file and Noita controller-detection setting need verification.","Actual Noita cursor, scrolling-camera and inventory drag behavior require an on-device test."],lookMode:"relativeMouse",digitalMovement:.init(left:"move-left",right:"move-right",up:"levitate",down:"down-eat"),cursorControls:.init(fire:"use-selected",inventory:"inventory",pause:"pause",throwAction:"throw",primaryClick:"pointer-select",secondaryClick:"pointer-secondary"))
        pack.aim.deadZone=0
        if !bindings.isEmpty {
            pack.evidence.append(.init(id:"installed-input-metadata",source:"Bounded installed Noita input configuration",detail:"Input attributes were read on-device and included in the identity digest. Unrecognized fields are evidence only; they are not guessed bindings. Inspect preparation metadata or confirm mappings in Noita before marking physical validation complete."))
        }
        return pack
    }
    /// Read only known input config; no saves, game data extraction or recursive scan.
    static func inputMetadata(drive: URL) -> [String:String] {
        let root=drive.appendingPathComponent("users",isDirectory:true)
        let users=(try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)) ?? []
        var result:[String:String]=[:]
        for user in users.prefix(12) {
            let file=user.appendingPathComponent("AppData/LocalLow/Nolla_Games_Noita/save_shared/config.xml").resolvingSymlinksInPath()
            guard file.path.hasPrefix(root.resolvingSymlinksInPath().path+"/"),let h=try? FileHandle(forReadingFrom:file) else { continue }
            defer { try? h.close() }
            guard let data=try? h.read(upToCount:32769),data.count<=32768 else { continue }
            let delegate=InputAttributes();let parser=XMLParser(data:data);parser.shouldResolveExternalEntities=false;parser.delegate=delegate
            if parser.parse(), !delegate.values.isEmpty,let encoded=try? JSONSerialization.data(withJSONObject:delegate.values,options:[.sortedKeys]),let text=String(data:encoded,encoding:.utf8) {
                result["noita/save_shared/config.xml input attributes"]=text;break
            }
        }
        return result
    }
    private final class InputAttributes: NSObject, XMLParserDelegate {
        var values:[String:String]=[:]
        func parser(_ parser: XMLParser,didStartElement elementName:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
            for (key,value) in attributes where key.count<100 && value.count<256 {
                let k=key.lowercased()
                if ["key","mouse","joystick","gamepad","controller"].contains(where:{k.contains($0)}) { values[key]=value }
            }
        }
    }
}
