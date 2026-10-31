from pathlib import Path
import plistlib,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
p=(root/'InstrumentDNAMac.xcodeproj/project.pbxproj').read_text()
assert p.count('"MACOSX_DEPLOYMENT_TARGET" = "12.0";')==2
assert 'UIKit.framework' not in p
assert '../InstrumentDNA/Shared/TouchSurface.swift' not in p
assert '../InstrumentDNA/Shared/InstrumentEditorController.swift' not in p
for folder in ['Shared','App','Extension']:
 for f in (root/folder).glob('*.swift'):assert str(f.relative_to(root)) in p,f
for kind in ['App','Extension']:
 info=plistlib.loads((root/kind/'Info.plist').read_bytes())
 assert info['CFBundleShortVersionString']=='0.4.3' and info['CFBundleVersion']=='10'
 assert 'UIBackgroundModes' not in info
 ent=plistlib.loads((root/kind/('App.entitlements' if kind=='App' else 'Instrument.entitlements')).read_bytes())
 assert ent['com.apple.security.app-sandbox'] and ent['com.apple.security.files.user-selected.read-write']
component=plistlib.loads((root/'Extension/Info.plist').read_bytes())['NSExtension']['NSExtensionAttributes']['AudioComponents'][0]
assert (component['type'],component['subtype'],component['manufacturer'])==('aumu','InDN','DbAL')
ET.parse(root/'InstrumentDNAMac.xcodeproj/xcshareddata/xcschemes/InstrumentDNAMac.xcscheme')
print('Mac project, shared source, AU identity, entitlements and minimum OS checks passed.')
