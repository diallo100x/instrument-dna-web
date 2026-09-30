#import "DNAudioUnit.h"
#import "DNAKernel.h"
#include <vector>
#include <algorithm>
#include <cmath>
#include <cstring>
static NSString*const StateKey=@"InstrumentDNAModel";
static NSArray<NSString*>*LayerNames(){return @[@"sustain",@"trill",@"staccato",@"accent",@"breathy",@"alternate"];}
static float Field(NSDictionary *params,NSString *key,float fallback){id p=params[key];if(![p isKindOfClass:NSDictionary.class])return fallback;id n=p[@"model"]?:p[@"analyzed"];return [n isKindOfClass:NSNumber.class]?[n floatValue]+[p[@"offset"] floatValue]:fallback;}
static NSError*Failure(NSString*message){return [NSError errorWithDomain:@"InstrumentDNA" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}
@implementation DNAudioUnit {
 DNAKernel *_kernel; AUAudioUnitBus *_output; AUAudioUnitBusArray *_outputs,*_inputs; AUParameterTree *_tree;
 std::vector<float> _left,_right; NSData *_modelData; NSLock *_stateLock;
}
- (instancetype)initWithComponentDescription:(AudioComponentDescription)description options:(AudioComponentInstantiationOptions)options error:(NSError**)error {
 if(!(self=[super initWithComponentDescription:description options:options error:error]))return nil;
 _kernel=dna_kernel_create(44100);if(!_kernel){if(error)*error=Failure(@"Cannot allocate instrument kernel");return nil;}
 _stateLock=[NSLock new];_modelData=[NSData data];self.maximumFramesToRender=4096;_left.resize(4096);_right.resize(4096);
 _output=[[AUAudioUnitBus alloc] initWithFormat:[[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2] error:error];if(!_output)return nil;
 _outputs=[[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[_output]];
 _inputs=[[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[]];
 NSArray*names=@[@"Attack",@"Body",@"Brightness",@"Harmonics",@"Noise",@"Resonance",@"Dynamics",@"Articulation",@"Movement",@"Drive",@"Tone X",@"Tone Y",@"Behavior X",@"Behavior Y",@"Volume",@"Global Bend",@"Modulation",@"Bend Range",@"Voice Mode",@"Legato Glide",@"Articulation Layer",@"Recording Era",@"Era Amount",@"Trill Rate",@"Trill Interval",@"Velocity Trill",@"Trill Threshold",@"Note Length",@"Engine Mode"];
 NSMutableArray*parameters=[NSMutableArray array];for(int i=0;i<DNA_PARAMETER_COUNT;i++){
  float lo=0,hi=1;if(i==DNA_PITCH)lo=-1;if(i==DNA_BEND_RANGE)hi=48;if(i==DNA_VOICE_MODE||i==DNA_ERA)hi=2;if(i==DNA_GLIDE){lo=10;hi=250;}if(i==DNA_LAYER)hi=5;if(i==DNA_TRILL_RATE){lo=3;hi=15;}if(i==DNA_TRILL_INTERVAL){lo=1;hi=12;}if(i==DNA_TRILL_THRESHOLD){lo=1;hi=127;}if(i==DNA_NOTE_LENGTH)hi=15;if(i==DNA_ENGINE_MODE)hi=3;
  AUParameter*p=[AUParameterTree createParameterWithIdentifier:[NSString stringWithFormat:@"dna%d",i] name:names[i] address:i min:lo max:hi unit:kAudioUnitParameterUnit_Generic unitName:nil flags:kAudioUnitParameterFlag_IsReadable|kAudioUnitParameterFlag_IsWritable|kAudioUnitParameterFlag_CanRamp valueStrings:nil dependentParameters:nil];p.value=dna_parameter_get(_kernel,i);[parameters addObject:p];
 }
 _tree=[AUParameterTree createTreeWithChildren:parameters];DNAKernel*k=_kernel;
 _tree.implementorValueObserver=^(AUParameter*p,AUValue value){dna_parameter_set(k,(int)p.address,value);};
 _tree.implementorValueProvider=^AUValue(AUParameter*p){return dna_parameter_get(k,(int)p.address);};return self;
}
- (void)dealloc {dna_kernel_destroy(_kernel);}
- (AUAudioUnitBusArray*)outputBusses{return _outputs;}
- (AUAudioUnitBusArray*)inputBusses{return _inputs;}
- (AUParameterTree*)parameterTree{return _tree;}
- (BOOL)canProcessInPlace{return NO;}
- (BOOL)supportsMPE{return YES;}
- (BOOL)supportsUserPresets{return YES;}
- (BOOL)allocateRenderResourcesAndReturnError:(NSError**)error {
 if(_output.format.channelCount<1||_output.format.channelCount>2||_output.format.commonFormat!=AVAudioPCMFormatFloat32||_output.format.interleaved){if(error)*error=Failure(@"Choose a mono or stereo noninterleaved Float32 output");return NO;}
 if(self.maximumFramesToRender>4096){if(error)*error=Failure(@"Maximum render block is 4096 frames");return NO;}if(![super allocateRenderResourcesAndReturnError:error])return NO;
 dna_kernel_set_rate(_kernel,_output.format.sampleRate);return YES;
}
- (void)deallocateRenderResources {[self panic];[super deallocateRenderResources];}
- (AUInternalRenderBlock)internalRenderBlock {
 DNAKernel*k=_kernel;float*l=_left.data(),*r=_right.data();AUAudioFrameCount maxFrames=4096;
 return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *flags,const AudioTimeStamp *time,AUAudioFrameCount count,NSInteger bus,AudioBufferList *output,const AURenderEvent *events,AURenderPullInputBlock pull){
  if(bus!=0||count>maxFrames||!l||!r||output->mNumberBuffers<1)return kAudioUnitErr_TooManyFramesToProcess;
  uint32_t cursor=0;const AURenderEvent*event=events;
  while(event){int64_t when=event->head.eventSampleTime==AUEventSampleTimeImmediate?cursor:event->head.eventSampleTime-(int64_t)time->mSampleTime;uint32_t at=(uint32_t)std::max<int64_t>(cursor,std::min<int64_t>(count,when));if(at>cursor){dna_render(k,l+cursor,r+cursor,at-cursor);cursor=at;}
   switch(event->head.eventType){case AURenderEventMIDI:if(event->MIDI.length>=3)dna_midi(k,event->MIDI.data[0],event->MIDI.data[1],event->MIDI.data[2]);break;
    case AURenderEventParameter:case AURenderEventParameterRamp:dna_parameter_set(k,(int)event->parameter.parameterAddress,event->parameter.value);break;default:break;}
   event=event->head.next;
  }
  if(cursor<count)dna_render(k,l+cursor,r+cursor,count-cursor);
  for(UInt32 channel=0;channel<output->mNumberBuffers;channel++){float*source=channel==0?l:r;if(!output->mBuffers[channel].mData)output->mBuffers[channel].mData=source;else memcpy(output->mBuffers[channel].mData,source,count*sizeof(float));output->mBuffers[channel].mDataByteSize=count*sizeof(float);}
  (void)flags;(void)pull;return noErr;
 };
}
- (void)touchNote:(NSInteger)slot midi:(NSInteger)midi velocity:(float)velocity down:(BOOL)down{if(slot>=0&&slot<DNA_TOUCH_SLOTS)dna_note_set(_kernel,(int)slot,(int)midi,velocity,down);}
- (void)touchBend:(NSInteger)slot semitones:(float)semitones{if(slot>=0&&slot<DNA_TOUCH_SLOTS)dna_note_bend(_kernel,(int)slot,semitones);}
- (void)panic{dna_all_notes_off(_kernel);}
- (void)receiveMIDI:(uint8_t)status a:(uint8_t)a b:(uint8_t)b{dna_midi(_kernel,status,a,b);}
- (NSData*)modelData {[_stateLock lock];NSData*d=_modelData;[_stateLock unlock];return d;}
- (BOOL)loadModelData:(NSData*)data error:(NSError**)error {
 if(data.length>100000000){if(error)*error=Failure(@"Preset exceeds 100 MB");return NO;}
 id parsed=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];if(![parsed isKindOfClass:NSDictionary.class])return NO;
 NSDictionary*document=parsed;BOOL comparison=[document[@"format"] isEqual:@"instrument-dna-playable-comparison"];NSDictionary*reflection=comparison?document[@"reflection"]:document;
 if(![reflection isKindOfClass:NSDictionary.class]||![reflection[@"format"] isEqual:@"instrument-dna-reflection"]||![reflection[@"anchors"] isKindOfClass:NSArray.class]){if(error)*error=Failure(@"Choose an Instrument DNA Reflection or playable comparison");return NO;}
 DNABank*bank=dna_bank_create();if(!bank){if(error)*error=Failure(@"Cannot allocate model");return NO;}
 NSArray*layers=LayerNames();BOOL valid=YES;NSUInteger sampleBytes=0;
 for(int layer=0;layer<DNA_LAYERS;layer++){NSArray*anchors=layer==0?reflection[@"anchors"]:reflection[@"performance"][@"layers"][layers[layer]];if(![anchors isKindOfClass:NSArray.class])continue;if(anchors.count>128){valid=NO;break;}
  // Sustain-specific anchors take precedence over the legacy base map.
  if(layer==0&&[reflection[@"performance"][@"layers"][@"sustain"] count])anchors=reflection[@"performance"][@"layers"][@"sustain"];
  for(id item in anchors){if(![item isKindOfClass:NSDictionary.class]){valid=NO;break;}NSDictionary*a=item;int midi=[a[@"midi"] intValue];if(midi<0||midi>127){valid=NO;break;}NSDictionary*params=a[@"parameters"]?:@{};id harmonic=params[@"harmonicAmplitudes"][@"model"]?:params[@"harmonicAmplitudes"][@"analyzed"];float h[12]={0};int count=[harmonic isKindOfClass:NSArray.class]?(int)MIN(12,[harmonic count]):0;for(int i=0;i<count;i++)h[i]=[harmonic[i] floatValue];NSDictionary*global=reflection[@"global"];float attackOffset=[global[@"attackSeconds"][@"offset"] floatValue],decayOffset=[global[@"decaySeconds"][@"offset"] floatValue],releaseOffset=[global[@"releaseSeconds"][@"offset"] floatValue];BOOL struck=[a[@"analysisProfile"] isEqual:@"struck"]||[reflection[@"capture"][@"analysisProfile"] isEqual:@"struck"];
   dna_bank_anchor(bank,layer,midi,Field(params,@"attackSeconds",.015)+attackOffset,Field(params,@"decaySeconds",1.3)+decayOffset,Field(params,@"releaseSeconds",.12)+releaseOffset,h,count,struck);
  }
 }
 if(comparison){NSArray*groups=@[document[@"audio"]?:@[],document[@"audioLayers"]?:@[]];for(int group=0;group<2;group++)for(id item in groups[group]){if(![item isKindOfClass:NSDictionary.class]){valid=NO;break;}NSDictionary*entry=item;int midi=[entry[@"midi"] intValue],layer=group==0?0:(int)[layers indexOfObject:entry[@"layer"]];double rate=[entry[@"sampleRate"] doubleValue];NSArray*channels=entry[@"channels"];if(layer<0||layer>=DNA_LAYERS||midi<0||midi>127||rate<8000||rate>192000||![channels isKindOfClass:NSArray.class]||channels.count<1||channels.count>8){valid=NO;break;}
   std::vector<float>mono;for(NSString*encoded in channels){if(![encoded isKindOfClass:NSString.class]){valid=NO;break;}NSData*bytes=[[NSData alloc]initWithBase64EncodedString:encoded options:0];if(!bytes||bytes.length%4||bytes.length<16*sizeof(float)||bytes.length>rate*15*sizeof(float)){valid=NO;break;}sampleBytes+=bytes.length;if(sampleBytes>100000000){valid=NO;break;}size_t n=bytes.length/sizeof(float);if(mono.empty())mono.assign(n,0);if(mono.size()!=n){valid=NO;break;}const float*samples=(const float*)bytes.bytes;for(size_t i=0;i<n;i++){if(!std::isfinite(samples[i])){valid=NO;break;}mono[i]+=samples[i]/channels.count;}}
   if(valid&&!dna_bank_sample(bank,layer,midi,mono.data(),(uint32_t)mono.size(),rate))valid=NO;
  }}
 if(!valid){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid model anchors or audio slices");return NO;}
 [self panic];[_stateLock lock];dna_bank_publish(_kernel,bank);_modelData=[data copy];[_stateLock unlock];
 NSArray*macroNames=@[@"Attack",@"Body",@"Brightness",@"Harmonics",@"Noise",@"Resonance",@"Dynamics",@"Articulation",@"Movement",@"Drive"];for(int i=0;i<10;i++)if([reflection[@"macros"][macroNames[i]] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:i].value=[reflection[@"macros"][macroNames[i]] floatValue];
 NSDictionary*performance=reflection[@"performance"];NSDictionary*map=@{@"glideMs":@(DNA_GLIDE),@"trillRateHz":@(DNA_TRILL_RATE),@"trillInterval":@(DNA_TRILL_INTERVAL),@"trillThreshold":@(DNA_TRILL_THRESHOLD),@"velocityTrill":@(DNA_VELOCITY_TRILL),@"noteLengthSeconds":@(DNA_NOTE_LENGTH)};for(NSString*key in map)if([performance[key] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:[map[key] unsignedLongLongValue]].value=[performance[key] floatValue];
 NSArray*voiceNames=@[@"poly",@"mono",@"legato"];NSUInteger voice=[voiceNames indexOfObject:performance[@"voiceMode"]?:@"poly"];[_tree parameterWithAddress:DNA_VOICE_MODE].value=voice<3?voice:0;
 NSUInteger layer=[layers indexOfObject:performance[@"selectedArticulation"]?:@"sustain"];[_tree parameterWithAddress:DNA_LAYER].value=layer<6?layer:0;
 NSDictionary*xy=reflection[@"xy"];for(NSString*name in @[@"tone",@"behavior"]){NSArray*pair=xy[name];int base=[name isEqualToString:@"tone"]?DNA_TONE_X:DNA_BEHAVIOR_X;if([pair isKindOfClass:NSArray.class]&&pair.count==2)for(int i=0;i<2;i++)if([pair[i] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:base+i].value=[pair[i] floatValue];}
 NSDictionary*era=reflection[@"era"];NSUInteger eraIndex=[@[@"none",@"vintage",@"tape"] indexOfObject:era[@"recording"]?:@"none"];[_tree parameterWithAddress:DNA_ERA].value=eraIndex<3?eraIndex:0;if([era[@"amount"] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:DNA_ERA_AMOUNT].value=[era[@"amount"] floatValue];
 NSDictionary*native=reflection[@"extensions"][@"nativePerformance"];NSDictionary*nativeMap=@{@"bendRange":@(DNA_BEND_RANGE),@"modulation":@(DNA_MODULATION),@"engineMode":@(DNA_ENGINE_MODE),@"volume":@(DNA_VOLUME)};for(NSString*key in nativeMap)if([native[key] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:[nativeMap[key] unsignedLongLongValue]].value=[native[key] floatValue];
 __weak DNAudioUnit*weak=self;dispatch_async(dispatch_get_main_queue(),^{if(weak)[NSNotificationCenter.defaultCenter postNotificationName:@"InstrumentDNAModelChanged" object:weak];});
 return YES;
}
- (NSDictionary*)fullState {NSMutableDictionary*state=[[super fullState] mutableCopy]?:[NSMutableDictionary dictionary];state[StateKey]=self.modelData;NSMutableArray*values=[NSMutableArray array];for(int i=0;i<DNA_PARAMETER_COUNT;i++)[values addObject:@(dna_parameter_get(_kernel,i))];state[@"DNAParameters"]=values;return state;}
- (void)setFullState:(NSDictionary*)state {[super setFullState:state];NSData*data=state[StateKey];if([data isKindOfClass:NSData.class]&&data.length){NSError*error=nil;[self loadModelData:data error:&error];}NSArray*values=state[@"DNAParameters"];if([values isKindOfClass:NSArray.class])for(int i=0;i<MIN(DNA_PARAMETER_COUNT,values.count);i++)if([values[i] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:i].value=[values[i] floatValue];}
@end
