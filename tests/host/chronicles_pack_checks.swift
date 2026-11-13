import Foundation
@main struct ChroniclesPackChecks {
    static func main() throws {
        let identity=BCDControlPack.Identity(executable:"Program Files (x86)/Steam/steamapps/common/Chronicles of the Wolf/Cotw.exe",storeID:"local",edition:"installed",build:"unreported",bindingDigest:"fixture")
        let config="[varcom]\nM=32\nN=0\nO=5\nP=1\nQ=2\nR=3\nS=0\nT=6\nU=7\n[global]\nT=1\nU=0\n"
        let p=try BCDChroniclesPack.make(identity:identity,bindings:[BCDChroniclesPack.configPath:config])
        let a=Dictionary(uniqueKeysWithValues:p.actions.map{($0.id,$0.output)})
        assert(a == ["move":"LS","attack":"RT","jump":"A","special":"RB","helper":"B","map":"X","subscreen":"Y","confirm":"View","cancel":"Menu","up":"D↑"])
        assert(p.id == "chronicles-reviewed-controller-v6" && p.lookMode == "none" && p.inputMode == "controller")
        assert(p.gestures.isEmpty && p.digitalMovement == nil)
        for id in ["attack","jump","special","helper"] { assert(p.actions.first{$0.id==id}?.behavior == "hold") }
        for layout in [p.phone,p.pad] {
            assert(layout.controls.filter{$0.role=="move"}.count == 1)
            assert(layout.controls.allSatisfy{$0.hitRadius==$0.radius})
            assert(layout.controls.allSatisfy{$0.x-$0.radius>=0 && $0.x+$0.radius<=1 && $0.y-$0.radius>=0 && $0.y+$0.radius<=1})
        }
        let expected=["A","B","X","Y","LB","RB","View","Menu","L3","R3","D↑","D↓","D←","D→"]
        for (code,out) in expected.enumerated() { assert(BCDChroniclesPack.output(for:code)==out) }
        assert(BCDChroniclesPack.output(for:31)=="LT" && BCDChroniclesPack.output(for:32)=="RT")
        for code in [-1,14,30,33,Int.max] { assert(BCDChroniclesPack.output(for:code)==nil) }
        func rejects(_ text:String) { do { _=try BCDChroniclesPack.configuredOutputs(text);fatalError("Expected rejection") } catch {} }
        rejects("");rejects(config.replacingOccurrences(of:"M=32",with:"M=14"));rejects(config.replacingOccurrences(of:"M=32",with:"M=NaN"))
        rejects(config.replacingOccurrences(of:"M=32",with:"M=32\nM=0"));rejects(config.replacingOccurrences(of:"M=32",with:"m=32"))
        rejects(String(repeating:" ",count:32769));rejects(config.replacingOccurrences(of:"[varcom]",with:"[global]"))
        let changed=try BCDChroniclesPack.configuredOutputs(config.replacingOccurrences(of:"M=32",with:"M=31").replacingOccurrences(of:"N=0",with:"N=3"))
        assert(changed["attack"]=="LT" && changed["jump"]=="Y")
        let crlf=try BCDChroniclesPack.configuredOutputs("\u{feff}"+config.replacingOccurrences(of:"\n",with:"\r\n"))
        assert(crlf==a.filter{!["move","up"].contains($0.key)})
        var wrong=identity;wrong.executable += ".bak";assert(!BCDChroniclesPack.matches(wrong))
        do { _=try BCDChroniclesPack.make(identity:identity);fatalError("Missing config must not invent defaults") } catch {}
        try p.validate(for:identity)
        print("PASS Chronicles factory: exact native ABI, current remaps, bounded parser, geometry and no keyboard fallback. Not device validation.")
    }
}
