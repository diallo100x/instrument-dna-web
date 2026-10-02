#import "DNAudioUnit.h"
#import "DNAKernel.h"
#include <cassert>
#include <cmath>
#include <vector>
int main(){@autoreleasepool {
 AudioComponentDescription component={kAudioUnitType_MusicDevice,0x496e444e,0x4462414c,0,0};
 [AUAudioUnit registerSubclass:DNAudioUnit.class asComponentDescription:component name:@"Diallo Beats Audio Lab: Instrument DNA" version:65536];
 NSError*error=nil;DNAudioUnit*unit=[[DNAudioUnit alloc] initWithComponentDescription:component options:0 error:&error];assert(unit&&!error);assert(unit.hasCustomView);NSArray*configs=@[[[AUAudioUnitViewConfiguration alloc]initWithWidth:320 height:240 hostHasController:NO],[[AUAudioUnitViewConfiguration alloc]initWithWidth:720 height:540 hostHasController:YES],[[AUAudioUnitViewConfiguration alloc]initWithWidth:0 height:0 hostHasController:NO]];assert([unit supportedViewConfigurations:configs].count==3);assert(unit.parameterTree.allParameters.count==DNA_PARAMETER_COUNT);
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
 [unit panic];[unit deallocateRenderResources];puts("Apple AU integration: model/sample import, 29 parameters, XY/Era recall, host state and audible render passed.");
}}
