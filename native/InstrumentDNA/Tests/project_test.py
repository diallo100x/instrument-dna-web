import pathlib,plistlib,re,xml.etree.ElementTree as ET
root=pathlib.Path(__file__).resolve().parents[1]
app=plistlib.loads((root/'App/Info.plist').read_bytes())
extension=plistlib.loads((root/'Extension/Info.plist').read_bytes())
component=extension['NSExtension']['NSExtensionAttributes']['AudioComponents'][0]
assert component['type']=='aumu' and component['manufacturer']=='DbAL' and component['subtype']=='InDN'
assert extension['NSExtension']['NSExtensionPrincipalClass']=='$(PRODUCT_MODULE_NAME).InstrumentViewController'
project=(root/'InstrumentDNA.xcodeproj/project.pbxproj').read_text()
ids=re.findall(r'\b([A-F0-9]{24}) = \{ \"isa\"',project)
assert len(ids)==len(set(ids)), 'duplicate project IDs'
assert 'Embed App Extensions' in project
# Keep both configurations compatible with iPadOS 15.4.1. Targets inherit
# the project minimum; reject a newer target override as well.
minimums=re.findall(r'"IPHONEOS_DEPLOYMENT_TARGET" = "([^"]+)";',project)
assert minimums == ['15.4','15.4'], f'unexpected deployment targets: {minimums}'
assert project.count('"CLANG_WARN_UNGUARDED_AVAILABILITY" = "YES_ERROR";') == 2
assert app['CFBundleShortVersionString'] == extension['CFBundleShortVersionString'] == '0.4.0'
assert app['CFBundleVersion'] == extension['CFBundleVersion'] == '7'
assert component['version'] == 65543
for directory in ['DSP','Shared','App','Extension']:
    for file in (root/directory).iterdir():
        if file.suffix in ['.c','.m','.mm','.h','.swift']:
            assert str(file.relative_to(root)) in project, f'missing {file}'
ET.parse(root/'InstrumentDNA.xcodeproj/xcshareddata/xcschemes/InstrumentDNA.xcscheme')
print('Project checks: source membership, component IDs, embedded extension, deployment target, scheme and plists passed. Apple compilation and runtime checks run separately in CI.')
