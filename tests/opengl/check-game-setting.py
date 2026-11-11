"""Exercise the real GL row -> production routing branch -> per-game file storage.
Engine value models are small stubs; GameProfile storage, row construction and
setLine are extracted verbatim. Uses unique temporary profile names on CI.
"""
import pathlib,re,subprocess,tempfile
r=pathlib.Path(__file__).resolve().parents[2]
live=(r/'app/Madeira/BCDGamePageLive.swift').read_text()
profiles=(r/'app/Madeira/GameProfiles.swift').read_text()
def block(text,header):
 start=text.index(header);opening=text.index('{',start);depth=1;end=opening+1
 while depth:
  depth+=(text[end]=='{')-(text[end]=='}');end+=1
 return text[start:end]
storage=profiles[profiles.index('struct GameProfile {'):profiles.index('    func set(')]+block(profiles,'    func set(')+'\n}\n'
route=re.search(r'^        case [^\n]*"gl-backend"[^\n]*:\n.*?(?=^        case |^        default:)',block(live,'    func set('),re.M|re.S)
assert route,'Displayed GL picker must route into the game profile'
row=re.search(r'Self.line\(BCDOpenGL.key[^\n]*\n\s*note: BCDOpenGL.pageNote\),',live)
assert row
source=r'''import Foundation
enum CoverStore {
 static func stableHash(_ value:String)->UInt64 { value.utf8.reduce(14695981039346656037) { ($0 ^ UInt64($1)) &* 1099511628211 } }
}
struct LibraryEntry {var id:String;var windowsPath:String}
struct BCDGame {var entry:LibraryEntry}
final class LibraryModel {
 static let shared=LibraryModel();var entries:[LibraryEntry]=[]
 func save(_ entry:LibraryEntry){entries.append(entry)}
}
enum GamepadInput {static let padModeKey="env.MADEIRA_PAD_MODE"}
enum BCDGPUCards {static let key="gpu";static let memoryKey="vram"}
struct BCDGameChoice {var value:String;var label:String}
struct BCDGameSetting {
 enum Kind {case choice([BCDGameChoice])}
 var id:String;var title:String;var kind:Kind;var value:String;var defaultValue:String;var note:String
}
'''+(r/'app/Madeira/BCDOpenGL.swift').read_text()+'\n'+storage+'\nfinal class Fixture {\nfunc entry(for game:BCDGame)->LibraryEntry? {game.entry}\n'+block(live,'    func setLine(')+'\n'+block(live,'    private static func line(')+'''
static func glRow(_ profile:GameProfile)->BCDGameSetting { return '''+row[0][:-1]+''' }
func set(_ setting:String,to value:String,for game:BCDGame) {
 switch setting {
'''+route[0]+''' default:break
 }
}
}
'''+r'''
@main struct Check {
 static func main() throws {
  let nonce=UUID().uuidString
  let noita=LibraryEntry(id:"noita-"+nonce,windowsPath:"TEST-GL/"+nonce+"/Noita.exe")
  let dread=LibraryEntry(id:"dread-"+nonce,windowsPath:"TEST-GL/"+nonce+"/Dread.exe")
  let n=GameProfile(windowsPath:noita.windowsPath),d=GameProfile(windowsPath:dread.windowsPath)
  let imported=GameProfile(windowsPath:"TEST-GL/"+nonce+"/Import.exe")
  defer { for p in [n,d,imported] { if let url=p.url {try? FileManager.default.removeItem(at:url)} } }
  n.text="# personal settings\nfps-limit = 40\nenv.TEST_PRESERVED = 1\n"
  d.text="env.SDL_JOYSTICK_RAWINPUT = 0\nfps-limit = 30\n"
  let baseline=d.text;LibraryModel.shared.entries=[dread]
  let fixture=Fixture();let game=BCDGame(entry:noita)
  let row=Fixture.glRow(n);precondition(row.id=="gl-backend" && row.value.isEmpty)
  fixture.set(row.id,to:"zink",for:game)
  precondition(GameProfile(windowsPath:noita.windowsPath).get("gl-backend")=="zink")
  precondition(Fixture.glRow(n).value=="zink")
  precondition(n.get("fps-limit")=="40" && n.get("env.TEST_PRESERVED")=="1")
  precondition(d.text==baseline && d.get("gl-backend")==nil)
  precondition(LibraryModel.shared.entries.count==2)
  imported.text=n.text;precondition(imported.get("gl-backend")=="zink")
  fixture.set(row.id,to:"gles",for:game);precondition(Fixture.glRow(n).value=="gles")
  fixture.set(row.id,to:"",for:game);precondition(n.get("gl-backend")==nil && Fixture.glRow(n).value.isEmpty)
  precondition(n.get("fps-limit")=="40" && d.text==baseline)
  let before=n.text;fixture.set("unrelated",to:"zink",for:game);precondition(n.text==before)
  print("PASS: production GL picker routing, per-game persistence/cold read/export/reset; other game and settings preserved")
 }
}
'''
with tempfile.TemporaryDirectory(prefix='bcd-gl-setting-') as tmp:
 path=pathlib.Path(tmp);swift=path/'Probe.swift';swift.write_text(source)
 subprocess.run(['swiftc','-parse-as-library',str(swift),'-o',str(path/'probe')],check=True)
 subprocess.run([str(path/'probe')],check=True)
