#!/usr/bin/env python3
"""Generate a self-contained Xcode project; no XcodeGen or package download."""
import hashlib,json,pathlib,plistlib
root=pathlib.Path(__file__).resolve().parent
project=root/'InstrumentDNA.xcodeproj'
objects={}
def ident(label):return hashlib.sha1(label.encode()).hexdigest()[:24].upper()
def add(label,kind,**fields):
    key=ident(label);objects[key]={'isa':kind,**fields};return key
class Raw(str):pass
def quote(value):
    if isinstance(value,Raw):return value
    if isinstance(value,str):return json.dumps(value)
    if isinstance(value,dict):return '{ '+''.join(f'{quote(k)} = {quote(v)}; ' for k,v in value.items())+'}'
    if isinstance(value,list):return '( '+', '.join(quote(v) for v in value)+' )'
    return str(value)
ref=lambda key:Raw(key)
shared=sorted([*root.glob('DSP/*.[ch]'),*root.glob('Shared/*.swift'),*root.glob('Shared/*.h'),*root.glob('Shared/*.m'),*root.glob('Shared/*.mm')])
app=list(root.glob('App/*.swift'));extension=list(root.glob('Extension/*.swift'))
files={}
for path in shared+app+extension+[root/'App/Info.plist',root/'Extension/Info.plist']:
    rel=path.relative_to(root).as_posix();types={'.swift':'sourcecode.swift','.c':'sourcecode.c.c','.h':'sourcecode.c.h','.m':'sourcecode.c.objc','.mm':'sourcecode.cpp.objcpp','.plist':'text.plist.xml'}
    files[rel]=add('file:'+rel,'PBXFileReference',lastKnownFileType=types[path.suffix],path=rel,sourceTree='<group>')
frameworks=[]
for name in ['AVFoundation','AudioToolbox','CoreAudioKit','CoreMIDI','UIKit','SwiftUI','UniformTypeIdentifiers']:
    frameworks.append(add('framework:'+name,'PBXFileReference',lastKnownFileType='wrapper.framework',name=name+'.framework',path='System/Library/Frameworks/'+name+'.framework',sourceTree='SDKROOT'))
appProduct=add('app-product','PBXFileReference',explicitFileType='wrapper.application',path='InstrumentDNA.app',sourceTree='BUILT_PRODUCTS_DIR')
extProduct=add('extension-product','PBXFileReference',explicitFileType='wrapper.app-extension',path='InstrumentDNAInstrument.appex',sourceTree='BUILT_PRODUCTS_DIR')
products=add('products','PBXGroup',children=[ref(appProduct),ref(extProduct)],name='Products',sourceTree='<group>')
mainGroup=add('main-group','PBXGroup',children=[ref(x) for x in files.values()]+[ref(x) for x in frameworks]+[ref(products)],sourceTree='<group>')
def configurations(label,settings):
    configs=[]
    for name in ['Debug','Release']:
        values={**settings,'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','GCC_OPTIMIZATION_LEVEL':'0' if name=='Debug' else 's','ONLY_ACTIVE_ARCH':'YES' if name=='Debug' else 'NO'}
        configs.append(add(label+':'+name,'XCBuildConfiguration',buildSettings=values,name=name))
    return add(label+':configs','XCConfigurationList',buildConfigurations=[ref(c) for c in configs],defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
projectSettings={'IPHONEOS_DEPLOYMENT_TARGET':'15.4','SWIFT_VERSION':'5.0','CLANG_CXX_LANGUAGE_STANDARD':'c++17','GCC_C_LANGUAGE_STANDARD':'c11','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SDKROOT':'iphoneos','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','TARGETED_DEVICE_FAMILY':'1,2','ENABLE_BITCODE':'NO','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'','SWIFT_OBJC_BRIDGING_HEADER':'$(SRCROOT)/Shared/BridgingHeader.h','HEADER_SEARCH_PATHS':['$(inherited)','$(SRCROOT)/DSP','$(SRCROOT)/Shared'],'CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.1.0','SUPPORTS_MACCATALYST':'NO'}
projectConfig=configurations('project',projectSettings)
projectID=ident('project');appID=ident('app-target');extID=ident('extension-target')
proxy=add('dependency-proxy','PBXContainerItemProxy',containerPortal=ref(projectID),proxyType=1,remoteGlobalIDString=ref(extID),remoteInfo='InstrumentDNAInstrument')
dependency=add('dependency','PBXTargetDependency',target=ref(extID),targetProxy=ref(proxy))
embedFile=add('embed-extension','PBXBuildFile',fileRef=ref(extProduct),settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})
embed=add('embed-phase','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[ref(embedFile)],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0)
for label,specific,product,bundle,plist in [('app',app,appProduct,'org.diallobeats.instrumentdna','App/Info.plist'),('extension',extension,extProduct,'org.diallobeats.instrumentdna.Instrument','Extension/Info.plist')]:
    sources=[]
    for path in shared+specific:
        if path.suffix not in ['.swift','.c','.m','.mm']:continue
        sources.append(add(label+':build:'+str(path),'PBXBuildFile',fileRef=ref(files[path.relative_to(root).as_posix()])))
    sourcePhase=add(label+':sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=[ref(f) for f in sources],runOnlyForDeploymentPostprocessing=0)
    linked=[add(label+':link:'+f,'PBXBuildFile',fileRef=ref(f)) for f in frameworks]
    frameworkPhase=add(label+':frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[ref(f) for f in linked],runOnlyForDeploymentPostprocessing=0)
    resources=add(label+':resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
    targetSettings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':bundle,'INFOPLIST_FILE':plist,'GENERATE_INFOPLIST_FILE':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks','@executable_path/../../Frameworks']}
    if label=='extension':targetSettings.update(APPLICATION_EXTENSION_API_ONLY='YES',SKIP_INSTALL='YES')
    config=configurations(label,targetSettings)
    add(label+'-target','PBXNativeTarget',buildConfigurationList=ref(config),buildPhases=[ref(sourcePhase),ref(frameworkPhase),ref(resources)]+([ref(embed)] if label=='app' else []),buildRules=[],dependencies=[ref(dependency)] if label=='app' else [],name='InstrumentDNA' if label=='app' else 'InstrumentDNAInstrument',productName='InstrumentDNA' if label=='app' else 'InstrumentDNAInstrument',productReference=ref(product),productType='com.apple.product-type.application' if label=='app' else 'com.apple.product-type.app-extension')
add('project','PBXProject',attributes={'LastUpgradeCheck':'1600','TargetAttributes':{appID:{'CreatedOnToolsVersion':'16.0'},extID:{'CreatedOnToolsVersion':'16.0'}}},buildConfigurationList=ref(projectConfig),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=ref(mainGroup),productRefGroup=ref(products),projectDirPath='',projectRoot='',targets=[ref(appID),ref(extID)])
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+quote({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':{Raw(k):v for k,v in objects.items()},'rootObject':ref(projectID)})+'\n')
schemes=project/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
(schemes/'InstrumentDNA.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{appID}" BuildableName="InstrumentDNA.app" BlueprintName="InstrumentDNA" ReferencedContainer="container:InstrumentDNA.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{appID}" BuildableName="InstrumentDNA.app" BlueprintName="InstrumentDNA" ReferencedContainer="container:InstrumentDNA.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{appID}" BuildableName="InstrumentDNA.app" BlueprintName="InstrumentDNA" ReferencedContainer="container:InstrumentDNA.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
for path in root.glob('*/Info.plist'):plistlib.loads(path.read_bytes())
print(project)
