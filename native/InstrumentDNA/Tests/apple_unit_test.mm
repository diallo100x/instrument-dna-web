#import "DNAudioUnit.h"
#import "DNAKernel.h"
#include <cassert>
#include <cmath>
#include <vector>
int main(){@autoreleasepool {
 AudioComponentDescription component={kAudioUnitType_MusicDevice,0x496e444e,0x4462414c,0,0};
 [AUAudioUnit registerSubclass:DNAudioUnit.class asComponentDescription:component name:@"Diallo Beats Audio Lab: Instrument DNA" version:65536];
 NSError*error=nil;DNAudioUnit*unit=[[DNAudioUnit alloc] initWithComponentDescription:component options:0 error:&error];assert(unit&&!error);assert(unit.providesUserInterface);NSArray*configs=@[[[AUAudioUnitViewConfiguration alloc]initWithWidth:320 height:240 hostHasController:NO],[[AUAudioUnitViewConfiguration alloc]initWithWidth:720 height:540 hostHasController:YES],[[AUAudioUnitViewConfiguration alloc]initWithWidth:0 height:0 hostHasController:NO]];assert([unit supportedViewConfigurations:configs].count==3);assert(unit.parameterTree.allParameters.count==DNA_PARAMETER_COUNT);
 std::vector<float> samples(44100);for(int i=0;i<44100;i++)samples[i]=.4f*sin(6.2831853*440*i/44100);
 NSString*encoded=[[NSData dataWithBytes:samples.data() length:samples.size()*4] base64EncodedStringWithOptions:0];
 NSDictionary*anchor=@{@"midi":@69,@"parameters":@{@"harmonicAmplitudes":@{@"model":@[@1,@.2]},@"attackSeconds":@{@"model":@.01}}};
 NSDictionary*reflection=@{@"format":@"instrument-dna-reflection",@"name":@"Native test",@"anchors":@[anchor],@"provenance":@[],@"sampleSlots":@[],@"performance":@{@"voiceMode":@"legato",@"glideMs":@80},@"macros":@{@"Brightness":@.8},@"xy":@{@"tone":@[@.6,@.7]},@"era":@{@"recording":@"tape",@"amount":@.3},@"extensions":@{@"nativePerformance":@{@"bendRange":@12,@"engineMode":@0}}};
 NSDictionary*comparison=@{@"format":@"instrument-dna-playable-comparison",@"version":@1,@"reflection":reflection,@"audio":@[@{@"midi":@69,@"sampleRate":@44100,@"channels":@[encoded]}]};
 NSData*data=[NSJSONSerialization dataWithJSONObject:comparison options:0 error:&error];assert([unit loadModelData:data error:&error]);assert(!error);
 assert(fabs([unit.parameterTree parameterWithAddress:DNA_BRIGHTNESS].value-.8)<.001);assert([unit.parameterTree parameterWithAddress:DNA_VOICE_MODE].value==2);assert([unit.parameterTree parameterWithAddress:DNA_BEND_RANGE].value==12);assert([unit.parameterTree parameterWithAddress:DNA_ERA].value==2);assert(fabs([unit.parameterTree parameterWithAddress:DNA_TONE_Y].value-.7)<.001);
 NSDictionary*state=unit.fullState;[unit.parameterTree parameterWithAddress:DNA_VOLUME].value=.1;unit.fullState=state;assert([unit.parameterTree parameterWithAddress:DNA_VOLUME].value>.6);
 assert([unit allocateRenderResourcesAndReturnError:&error]);[unit touchNote:0 midi:69 velocity:1 down:YES];
 float left[512]={0},right[512]={0};struct {UInt32 count;AudioBuffer buffers[2];} output={2,{{1,sizeof(left),left},{1,sizeof(right),right}}};AudioTimeStamp time={0};time.mFlags=kAudioTimeStampSampleTimeValid;AudioUnitRenderActionFlags flags=0;
 auto render=unit.internalRenderBlock;assert(render(&flags,&time,512,0,(AudioBufferList*)&output,NULL,nil)==noErr);double energy=0;for(float x:left){assert(std::isfinite(x));energy+=x*x;}assert(energy>.001);
 [unit panic];
 NSArray*factory=@[@"marimba",@"kalimba",@"chime",@"djembe",@"nylon-string",@"reed-pipe"];
 for(NSString*name in factory){NSData*json=[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"presets/factory/%@.json",name]];assert(json);assert([unit loadModelData:json error:&error]);assert([unit.parameterTree parameterWithAddress:DNA_ENGINE_MODE].value==4);
 [unit touchNote:0 midi:60 velocity:1 down:YES];double audible=0;for(int block=0;block<32;block++){assert(render(&flags,&time,512,0,(AudioBufferList*)&output,NULL,nil)==noErr);for(float x:left){assert(std::isfinite(x));audible+=x*x;}}assert(audible>.00001);
 [unit.parameterTree parameterWithAddress:DNA_DAMPING].value=.83;NSDictionary*physicalState=unit.fullState;[unit.parameterTree parameterWithAddress:DNA_DAMPING].value=.1;unit.fullState=physicalState;assert(fabs([unit.parameterTree parameterWithAddress:DNA_DAMPING].value-.83)<.001);
 }
 // Analyze actual PCM, load fitted per-anchor models, render, compare and recall host state.
 std::vector<float> decayPCM(32000);for(int i=0;i<32000;i++){double value=0;for(int h=1;h<=4;h++){double tone=.72,base=-log(1000)/2,loss=440*log(tone/sqrt(1+pow(1-tone,2)-2*(1-tone)*cos(6.283185307*440*h/16000)));value+=.35/h*sin(6.283185307*440*h*i/16000)*exp((base+loss)*i/16000);}decayPCM[i]=(float)value;}
 NSData*pcm=[NSData dataWithBytes:decayPCM.data() length:decayPCM.size()*sizeof(float)];
 for(NSString*kind in @[@"modal",@"waveguide"]){NSError*fitError=nil;NSDictionary*fit=[DNAudioUnit fitPhysicalPCM:pcm sampleRate:16000 midi:69 kind:kind error:&fitError];assert(fit&&!fitError);assert([fit[@"model"][@"origin"] isEqual:@"analyzed"]);
 NSMutableDictionary*fitted=[reflection mutableCopy];fitted[@"extensions"]=@{@"physicalModel":fit[@"model"],@"physicalFits":@{@"version":@1,@"anchors":@[fit]},@"nativePerformance":@{@"engineMode":@4}};
 NSMutableDictionary*playable=[comparison mutableCopy];playable[@"reflection"]=fitted;NSData*json=[NSJSONSerialization dataWithJSONObject:playable options:0 error:nil];assert([unit loadModelData:json error:&fitError]);assert(!fitError);
 for(int mode=0;mode<=4;mode+=4){[unit panic];[unit.parameterTree parameterWithAddress:DNA_ENGINE_MODE].value=mode;[unit touchNote:0 midi:69 velocity:.8 down:YES];double power=0;for(int b=0;b<24;b++){assert(render(&flags,&time,512,0,(AudioBufferList*)&output,NULL,nil)==noErr);for(float x:left){assert(std::isfinite(x));power+=x*x;}}assert(power>1e-5);}
 NSDictionary*saved=unit.fullState;unit.fullState=saved;assert([unit.modelData isEqual:json]);
 NSMutableDictionary*bad=[fitted mutableCopy];bad[@"extensions"]=@{@"physicalModel":fit[@"model"],@"physicalFits":@[]};NSError*invalidError=nil;assert(![unit loadModelData:[NSJSONSerialization dataWithJSONObject:bad options:0 error:nil] error:&invalidError]);assert(invalidError);
 }
 NSData*baseJSON=[NSData dataWithContentsOfFile:@"presets/factory/marimba.json"];
 for(int variant=0;variant<4;variant++){NSMutableDictionary*bad=[NSJSONSerialization JSONObjectWithData:baseJSON options:NSJSONReadingMutableContainers error:nil];NSMutableDictionary*ext=bad[@"extensions"];NSMutableDictionary*physical=ext[@"physicalModel"];
 if(variant==0)physical[@"version"]=@1.2;if(variant==1)physical[@"continuous"]=@.5;if(variant==2)physical[@"modes"][0][@"ratio"]=[NSNull null];if(variant==3)ext[@"physicalControls"]=@{@"damping":@"wrong"};
 NSData*invalid=[NSJSONSerialization dataWithJSONObject:bad options:0 error:nil];NSError*rejected=nil;assert(![unit loadModelData:invalid error:&rejected]);assert(rejected);}
 // Host formats/block sizes omitted by the former local-only acceptance tests.
 for(int channels=1;channels<=2;channels++)for(BOOL interleaved : {NO,YES}) {
  NSError*hostError=nil;DNAudioUnit*hostUnit=[[DNAudioUnit alloc]initWithComponentDescription:component options:0 error:&hostError];assert(hostUnit&&!hostError);
  assert(([hostUnit.channelCapabilities isEqual:@[@0,@1,@0,@2]]));
  auto hostRender=hostUnit.internalRenderBlock; // Obtained before host negotiation.
  AVAudioFormat*format=[[AVAudioFormat alloc]initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:channels interleaved:interleaved];
  assert([hostUnit.outputBusses[0] setFormat:format error:&hostError]);hostUnit.maximumFramesToRender=8192;assert([hostUnit allocateRenderResourcesAndReturnError:&hostError]);assert(!hostError);
  [hostUnit touchNote:0 midi:69 velocity:1 down:YES];
  BOOL packed=interleaved&&channels==2;
  std::vector<float> first(8192*(packed?2:1)+1,123),second(8193,123);UInt32 buffers=packed?1:channels;
  struct {UInt32 count;AudioBuffer buffers[2];} hostOutput={buffers,{{(UInt32)(packed?2:1),(UInt32)(8192*sizeof(float)*(packed?2:1)),first.data()},{1,8192*sizeof(float),second.data()}}};
  assert(hostRender(&flags,&time,8192,0,(AudioBufferList*)&hostOutput,NULL,nil)==noErr);
  double power=0;for(int i=0;i<8192*(packed?2:1);i++){assert(std::isfinite(first[i]));power+=first[i]*first[i];}assert(power>1e-5);assert(first[8192*(packed?2:1)]==123);assert(second[8192]==123);
  for(UInt32 i=0;i<buffers;i++){hostOutput.buffers[i].mData=NULL;hostOutput.buffers[i].mDataByteSize=0;}
  assert(hostRender(&flags,&time,8192,0,(AudioBufferList*)&hostOutput,NULL,nil)==noErr);
  for(UInt32 i=0;i<buffers;i++)assert(hostOutput.buffers[i].mData&&hostOutput.buffers[i].mDataByteSize==8192*sizeof(float)*(packed?2:1));
  assert(hostRender(&flags,&time,8192,0,(AudioBufferList*)&hostOutput,NULL,nil)==noErr); // Reuse AU-owned storage.
  float sentinel=123;hostOutput.buffers[0].mData=&sentinel;hostOutput.buffers[0].mDataByteSize=sizeof(float);
  assert(hostRender(&flags,&time,512,0,(AudioBufferList*)&hostOutput,NULL,nil)!=noErr);assert(sentinel==123);
  [hostUnit deallocateRenderResources];
 }
 [unit panic];[unit deallocateRenderResources];puts("Apple AU integration: mono/planar/interleaved 48 kHz and 8192-frame host negotiation, PCM modal/string fitting and Hybrid comparison, model/sample import, 33 parameters and six physical factories, XY/Era recall, host state and audible render passed.");
}}
