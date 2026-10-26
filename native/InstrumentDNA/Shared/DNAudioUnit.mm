#import "DNAudioUnit.h"
#import "DNAKernel.h"
#import "DNAPhysicalFit.h"
#include <vector>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstring>
static const AUAudioFrameCount HostFrameCapacity=65536;
static NSString*const StateKey=@"InstrumentDNAModel";
static NSArray<NSString*>*LayerNames(){return @[@"sustain",@"trill",@"staccato",@"accent",@"breathy",@"alternate"];}
static float Field(NSDictionary *params,NSString *key,float fallback){id p=params[key];if(![p isKindOfClass:NSDictionary.class])return fallback;id n=p[@"model"]?:p[@"analyzed"];return [n isKindOfClass:NSNumber.class]?[n floatValue]+[p[@"offset"] floatValue]:fallback;}
static NSError*Failure(NSString*message){return [NSError errorWithDomain:@"InstrumentDNA" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}
static BOOL ReadPhysical(NSDictionary*physical,DNAPhysicalModel*output){
  if(![physical isKindOfClass:NSDictionary.class]){return NO;}
  for(NSString*key in @[@"version",@"continuous",@"hardness",@"position",@"noise",@"decay"]){if(![physical[key] isKindOfClass:NSNumber.class]){return NO;}}
  if([physical[@"version"] doubleValue]!=1||([physical[@"continuous"] doubleValue]!=0&&[physical[@"continuous"] doubleValue]!=1)){return NO;}
  DNAPhysicalModel m={0};m.version=[physical[@"version"] intValue];m.measured=[physical[@"origin"] isEqual:@"analyzed"];m.kind=[physical[@"kind"] isEqual:@"modal"]?0:[physical[@"kind"] isEqual:@"waveguide"]?1:[physical[@"kind"] isEqual:@"additive-string"]?2:-1;
  NSArray*modes=physical[@"modes"];m.count=[modes isKindOfClass:NSArray.class]?(int)modes.count:0;m.continuous=[physical[@"continuous"] boolValue];m.hardness=[physical[@"hardness"] floatValue];m.position=[physical[@"position"] floatValue];m.noise=[physical[@"noise"] floatValue];m.decay=[physical[@"decay"] floatValue];
  if(m.count<1||m.count>16){return NO;}
  for(int i=0;i<m.count;i++){NSDictionary*mode=modes[i];if(![mode isKindOfClass:NSDictionary.class]){m.version=0;break;}if(![mode[@"ratio"] isKindOfClass:NSNumber.class]||![mode[@"gain"] isKindOfClass:NSNumber.class]||![mode[@"t60"] isKindOfClass:NSNumber.class]){m.version=0;break;}m.ratios[i]=[mode[@"ratio"] floatValue];m.gains[i]=[mode[@"gain"] floatValue];m.t60[i]=[mode[@"t60"] floatValue];if(mode[@"phase"]){if(![mode[@"phase"] isKindOfClass:NSNumber.class])return NO;m.phases[i]=[mode[@"phase"] floatValue];}}
  if(physical[@"waveguideTone"]){if(![physical[@"waveguideTone"] isKindOfClass:NSNumber.class])return NO;m.waveguide_tone=[physical[@"waveguideTone"] floatValue];if(m.waveguide_tone==0)return NO;}
  if(physical[@"lossSampleRate"]){if(![physical[@"lossSampleRate"] isKindOfClass:NSNumber.class])return NO;m.loss_rate=[physical[@"lossSampleRate"] floatValue];if(m.loss_rate==0)return NO;}
  if(!dna_physical_valid(&m))return NO;*output=m;return YES;
}
// AUAudioUnitBus's default format setter rejects stereo interleaved PCM on
// some SDKs. Keep its canonical channel/rate bookkeeping while exposing the
// actual supported client layout through the public format property.
@interface DNAOutputBus : AUAudioUnitBus
@end
@implementation DNAOutputBus {AVAudioFormat *_clientFormat;}
- (AVAudioFormat*)format {return _clientFormat?:super.format;}
- (BOOL)setFormat:(AVAudioFormat*)format error:(NSError**)error {
 if(format.commonFormat!=AVAudioPCMFormatFloat32||format.channelCount<1||format.channelCount>2||!std::isfinite(format.sampleRate)||format.sampleRate<8000||format.sampleRate>192000||self.ownerAudioUnit.renderResourcesAllocated){if(error)*error=Failure(@"Unsupported output format or active render resources");return NO;}
 if(self.ownerAudioUnit&&![self.ownerAudioUnit shouldChangeToFormat:format forBus:self]){if(error)*error=Failure(@"Host output format change refused");return NO;}
 AVAudioFormat*canonical=[[AVAudioFormat alloc]initStandardFormatWithSampleRate:format.sampleRate channels:format.channelCount];
 if(![super setFormat:canonical error:error])return NO;
 [self willChangeValueForKey:@"format"];_clientFormat=format;[self didChangeValueForKey:@"format"];
 if(error)*error=nil;return YES;
}
@end
@implementation DNAudioUnit {
 std::atomic<uint64_t> _renderedFrames;
 std::atomic<uint64_t> _audibleFrames;
 DNAKernel *_kernel; AUAudioUnitBus *_output; AUAudioUnitBusArray *_outputs,*_inputs; AUParameterTree *_tree;
 std::vector<float> _left,_right,_interleaved; NSData *_modelData; NSLock *_stateLock;
}
+ (NSDictionary*)fitPhysicalPCM:(NSData*)pcm sampleRate:(double)rate midi:(NSInteger)midi kind:(NSString*)kind error:(NSError**)error {
 if(pcm.length%sizeof(float)||pcm.length>rate*15*sizeof(float)||(![kind isEqual:@"modal"]&&![kind isEqual:@"waveguide"])){if(error)*error=Failure(@"Invalid physical fitting input");return nil;}
 std::vector<float> samples(pcm.length/sizeof(float));memcpy(samples.data(),pcm.bytes,pcm.length);DNAPhysicalFit fit={0};
 if(!dna_physical_fit(samples.data(),(int)samples.size(),rate,(int)midi,[kind isEqual:@"waveguide"]?1:0,&fit)){if(error)*error=Failure(@"No reliable physical fit. Use an isolated decaying note of at least 0.35 seconds; strings need two harmonic partials. Try Modal or Hybrid.");return nil;}
 DNAPhysicalModel*m=&fit.model;NSMutableArray*modes=[NSMutableArray new],*measurements=[NSMutableArray new];
 for(int i=0;i<m->count;i++){[modes addObject:@{@"ratio":@(m->ratios[i]),@"gain":@(m->gains[i]),@"t60":@(m->t60[i])}];[measurements addObject:@{@"hz":@(fit.frequencies[i]),@"r2":@(fit.r2[i]),@"observedSeconds":@(fit.observed[i]),@"t60":@(m->t60[i])}];}
 NSMutableDictionary*model=[@{@"version":@1,@"kind":kind,@"origin":@"analyzed",@"referenceMidi":@(midi),@"continuous":@NO,@"hardness":@(m->hardness),@"position":@(m->position),@"noise":@(m->noise),@"decay":@(m->decay),@"modes":modes} mutableCopy];if(m->waveguide_tone>0){model[@"waveguideTone"]=@(std::round(m->waveguide_tone*1000000.0)/1000000.0);model[@"lossSampleRate"]=@(m->loss_rate);}
 return @{@"midi":@(midi),@"model":model,@"confidence":@(fit.confidence),@"lossError":@(fit.loss_error),@"analyzerVersion":@"physical-fit-1",@"measurements":measurements,@"unsupported":@[@"excitation residual",@"body/string separation",@"dispersion",@"nonlinear response",@"velocity learning",@"wind excitation"],@"recommendation":fit.confidence<.55?@"Additional clean reference recommended near this note.":@""};
}
- (instancetype)initWithComponentDescription:(AudioComponentDescription)description options:(AudioComponentInstantiationOptions)options error:(NSError**)error {
 if(!(self=[super initWithComponentDescription:description options:options error:error]))return nil;
 _renderedFrames.store(0,std::memory_order_relaxed);_audibleFrames.store(0,std::memory_order_relaxed);
 _kernel=dna_kernel_create(44100);if(!_kernel){if(error)*error=Failure(@"Cannot allocate instrument kernel");return nil;}
 _stateLock=[NSLock new];_modelData=[NSData data];self.maximumFramesToRender=4096;_left.resize(HostFrameCapacity);_right.resize(HostFrameCapacity);_interleaved.resize(HostFrameCapacity*2);
 NSLog(@"InstrumentDNA AU initialized: type=%u subtype=%u",description.componentType,description.componentSubType);
 _output=[[DNAOutputBus alloc] initWithFormat:[[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2] error:error];if(!_output)return nil;
 _output.maximumChannelCount=2;_output.supportedChannelCounts=@[@1,@2];
 _outputs=[[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[_output]];
 _inputs=[[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[]];
 NSArray*names=@[@"Attack",@"Body",@"Brightness",@"Harmonics",@"Noise",@"Resonance",@"Dynamics",@"Articulation",@"Movement",@"Drive",@"Tone X",@"Tone Y",@"Behavior X",@"Behavior Y",@"Volume",@"Global Bend",@"Modulation",@"Bend Range",@"Voice Mode",@"Legato Glide",@"Articulation Layer",@"Recording Era",@"Era Amount",@"Trill Rate",@"Trill Interval",@"Velocity Trill",@"Trill Threshold",@"Note Length",@"Engine Mode",@"Exciter Hardness",@"Strike Position",@"Damping",@"Exciter Noise",@"Reference Tuning Hz",@"Guitar Pickup",@"Vibrato Depth",@"Vibrato Rate",@"Body Texture",@"Room Amount",@"Slide From",@"Audition MIDI"];
 NSMutableArray*parameters=[NSMutableArray array];for(int i=0;i<DNA_PARAMETER_COUNT;i++){
  float lo=0,hi=1;if(i==DNA_PITCH)lo=-1;if(i==DNA_BEND_RANGE)hi=48;if(i==DNA_VOICE_MODE||i==DNA_ERA)hi=2;if(i==DNA_GLIDE){lo=10;hi=2000;}if(i==DNA_LAYER)hi=5;if(i==DNA_TRILL_RATE){lo=3;hi=15;}if(i==DNA_TRILL_INTERVAL){lo=1;hi=12;}if(i==DNA_TRILL_THRESHOLD){lo=1;hi=127;}if(i==DNA_NOTE_LENGTH)hi=15;if(i==DNA_ENGINE_MODE)hi=4;if(i==DNA_REFERENCE_HZ){lo=432;hi=444;}if(i==DNA_PICKUP)hi=3;if(i==DNA_VIBRATO_RATE){lo=.5;hi=9;}if(i==DNA_SLIDE_FROM){lo=-12;hi=12;}if(i==DNA_AUDITION_MIDI){lo=40;hi=88;}
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
- (BOOL)providesUserInterface{return YES;}
- (NSIndexSet*)supportedViewConfigurations:(NSArray<AUAudioUnitViewConfiguration*>*)configurations {
 NSMutableIndexSet*accepted=[NSMutableIndexSet indexSet];
 [configurations enumerateObjectsUsingBlock:^(AUAudioUnitViewConfiguration*c,NSUInteger index,BOOL*stop){if(c.width>=0&&c.height>=0&&std::isfinite(c.width)&&std::isfinite(c.height))[accepted addIndex:index];}];return accepted;
}
- (NSArray<NSNumber*>*)channelCapabilities{return @[@0,@1,@0,@2];}
- (BOOL)shouldChangeToFormat:(AVAudioFormat*)format forBus:(AUAudioUnitBus*)bus {
 return !self.renderResourcesAllocated&&bus==_output&&format.commonFormat==AVAudioPCMFormatFloat32&&format.channelCount>=1&&format.channelCount<=2&&std::isfinite(format.sampleRate)&&format.sampleRate>=8000&&format.sampleRate<=192000;
}
- (BOOL)canProcessInPlace{return NO;}
- (BOOL)supportsMPE{return YES;}
- (BOOL)supportsUserPresets{return YES;}
- (BOOL)allocateRenderResourcesAndReturnError:(NSError**)error {
 if(_output.format.channelCount<1||_output.format.channelCount>2||_output.format.commonFormat!=AVAudioPCMFormatFloat32){if(error)*error=Failure(@"Choose a mono or stereo Float32 output");return NO;}
 if(!std::isfinite(_output.format.sampleRate)||_output.format.sampleRate<8000||_output.format.sampleRate>192000){if(error)*error=Failure(@"Output sample rate must be 8–192 kHz");return NO;}
 if(self.maximumFramesToRender<1||self.maximumFramesToRender>HostFrameCapacity){if(error)*error=Failure(@"Maximum render block must be 1–65536 frames");return NO;}
 NSLog(@"InstrumentDNA host allocation: %@, maximumFrames=%u",_output.format,self.maximumFramesToRender);if(![super allocateRenderResourcesAndReturnError:error])return NO;
 dna_kernel_set_rate(_kernel,_output.format.sampleRate);return YES;
}
- (void)deallocateRenderResources {[self panic];[super deallocateRenderResources];}
- (uint64_t)renderedFrames {return _renderedFrames.load(std::memory_order_relaxed);}
- (uint64_t)audibleFrames {return _audibleFrames.load(std::memory_order_relaxed);}
- (AUInternalRenderBlock)internalRenderBlock {
 auto rendered=&_renderedFrames;auto audible=&_audibleFrames;
 DNAKernel*k=_kernel;float*l=_left.data(),*r=_right.data(),*packed=_interleaved.data();AUAudioFrameCount maxFrames=HostFrameCapacity;
 return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *flags,const AudioTimeStamp *time,AUAudioFrameCount count,NSInteger bus,AudioBufferList *output,const AURenderEvent *events,AURenderPullInputBlock pull){
  if(bus!=0||count>maxFrames||!l||!r||output->mNumberBuffers<1)return kAudioUnitErr_TooManyFramesToProcess;
  // A host may negotiate either planar stereo, interleaved stereo, or mono.
  // Validate its storage before advancing voices or writing output.
  BOOL stereoPacked=output->mNumberBuffers==1&&output->mBuffers[0].mNumberChannels==2;
  if(output->mNumberBuffers>2||(!stereoPacked&&output->mBuffers[0].mNumberChannels!=1)||(output->mNumberBuffers==2&&output->mBuffers[1].mNumberChannels!=1))return kAudioUnitErr_FormatNotSupported;
  for(UInt32 i=0;i<output->mNumberBuffers;i++){UInt32 required=count*sizeof(float)*(stereoPacked?2:1);if(output->mBuffers[i].mData&&output->mBuffers[i].mDataByteSize<required)return kAudioUnitErr_TooManyFramesToProcess;}
  uint32_t cursor=0;const AURenderEvent*event=events;
  while(event){int64_t when=event->head.eventSampleTime==AUEventSampleTimeImmediate?cursor:event->head.eventSampleTime-(int64_t)time->mSampleTime;uint32_t at=(uint32_t)std::max<int64_t>(cursor,std::min<int64_t>(count,when));if(at>cursor){dna_render(k,l+cursor,r+cursor,at-cursor);cursor=at;}
   switch(event->head.eventType){case AURenderEventMIDI:if(event->MIDI.length>=3)dna_midi(k,event->MIDI.data[0],event->MIDI.data[1],event->MIDI.data[2]);break;
    case AURenderEventParameter:case AURenderEventParameterRamp:dna_parameter_set(k,(int)event->parameter.parameterAddress,event->parameter.value);break;default:break;}
   event=event->head.next;
  }
  if(cursor<count)dna_render(k,l+cursor,r+cursor,count-cursor);
  if(stereoPacked){
   float*target=output->mBuffers[0].mData?(float*)output->mBuffers[0].mData:packed;
   for(uint32_t i=0;i<count;i++){target[2*i]=l[i];target[2*i+1]=r[i];}
   output->mBuffers[0].mData=target;output->mBuffers[0].mDataByteSize=count*2*sizeof(float);
  }else for(UInt32 channel=0;channel<output->mNumberBuffers;channel++){float*source=channel==0?l:r;if(!output->mBuffers[channel].mData)output->mBuffers[channel].mData=source;else if(output->mBuffers[channel].mData!=source)memcpy(output->mBuffers[channel].mData,source,count*sizeof(float));output->mBuffers[channel].mDataByteSize=count*sizeof(float);}
  uint64_t sounding=0;for(uint32_t i=0;i<count;i++)if(std::fabs(l[i])>0.00001f||std::fabs(r[i])>0.00001f)sounding++;
  rendered->fetch_add(count,std::memory_order_relaxed);audible->fetch_add(sounding,std::memory_order_relaxed);
  if(flags)*flags &= ~kAudioUnitRenderAction_OutputIsSilence;
  (void)pull;return noErr;
 };
}
- (void)touchNote:(NSInteger)slot midi:(NSInteger)midi velocity:(float)velocity down:(BOOL)down{if(slot>=0&&slot<DNA_TOUCH_SLOTS)dna_note_set(_kernel,(int)slot,(int)midi,velocity,down);}
- (void)touchBend:(NSInteger)slot semitones:(float)semitones{if(slot>=0&&slot<DNA_TOUCH_SLOTS)dna_note_bend(_kernel,(int)slot,semitones);}
- (void)previewSlide:(NSInteger)midi semitones:(float)semitones layer:(NSInteger)layer{dna_preview_slide(_kernel,(int)midi,semitones,(int)layer);}
- (void)previewNote:(NSInteger)midi layer:(NSInteger)layer source:(BOOL)source down:(BOOL)down{dna_preview(_kernel,(int)midi,(int)layer,source,down);}
- (void)panic{dna_all_notes_off(_kernel);}
- (void)receiveMIDI:(uint8_t)status a:(uint8_t)a b:(uint8_t)b{dna_midi(_kernel,status,a,b);}
- (NSData*)modelData {[_stateLock lock];NSData*d=_modelData;[_stateLock unlock];return d;}
- (BOOL)loadModelData:(NSData*)data error:(NSError**)error {
 if(data.length>100000000){if(error)*error=Failure(@"Preset exceeds 100 MB");return NO;}
 id parsed=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];if(![parsed isKindOfClass:NSDictionary.class])return NO;
 NSDictionary*document=parsed;BOOL comparison=[document[@"format"] isEqual:@"instrument-dna-playable-comparison"];NSDictionary*reflection=comparison?document[@"reflection"]:document;
 if(![reflection isKindOfClass:NSDictionary.class]||![reflection[@"format"] isEqual:@"instrument-dna-reflection"]||![reflection[@"anchors"] isKindOfClass:NSArray.class]){if(error)*error=Failure(@"Choose an Instrument DNA Reflection or playable comparison");return NO;}
 id tuning=reflection[@"performance"][@"referenceHz"];if(tuning&&(![tuning isKindOfClass:NSNumber.class]||([tuning doubleValue]!=432&&[tuning doubleValue]!=435&&[tuning doubleValue]!=440&&[tuning doubleValue]!=444))){if(error)*error=Failure(@"Reference tuning must be 432, 435, 440 or 444 Hz");return NO;}
 DNABank*bank=dna_bank_create();if(!bank){if(error)*error=Failure(@"Cannot allocate model");return NO;}
 NSDictionary*extensions=reflection[@"extensions"];if(extensions&&![extensions isKindOfClass:NSDictionary.class]){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid model extensions");return NO;}
 NSDictionary*guitar=extensions[@"scalarControls"];NSDictionary*guitarDefaults=@{@"pickup":@0,@"vibratoDepth":@0,@"vibratoRate":@5.2,@"bodyTexture":@0,@"room":@0,@"slideFrom":@-2,@"auditionMidi":@66};
 NSDictionary*guitarBounds=@{@"pickup":@[@0,@3],@"vibratoDepth":@[@0,@1],@"vibratoRate":@[@.5,@9],@"bodyTexture":@[@0,@1],@"room":@[@0,@1],@"slideFrom":@[@-12,@12],@"auditionMidi":@[@40,@88]};
 if(guitar){if(![guitar isKindOfClass:NSDictionary.class]){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid guitar controls");return NO;}for(NSString*key in guitarDefaults){id v=guitar[key];NSArray*bounds=guitarBounds[key];if(v&&(![v isKindOfClass:NSNumber.class]||!std::isfinite([v doubleValue])||[v doubleValue]<[bounds[0] doubleValue]||[v doubleValue]>[bounds[1] doubleValue]||(([key isEqual:@"pickup"]||[key isEqual:@"auditionMidi"])&&[v doubleValue]!=[v intValue]))){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid guitar control value");return NO;}}}
 NSDictionary*physical=extensions[@"physicalModel"];
 if(physical){
  DNAPhysicalModel m={0};if(!ReadPhysical(physical,&m)){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid physical model");return NO;}
  NSDictionary*edits=extensions[@"physicalControls"];if(edits){if(![edits isKindOfClass:NSDictionary.class]){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid physical controls");return NO;}for(NSString*key in @[@"hardness",@"position",@"damping",@"noise"]){id value=edits[key];if(value&&(![value isKindOfClass:NSNumber.class]||!std::isfinite([value doubleValue])||[value doubleValue]<0||[value doubleValue]>1)){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid physical control value");return NO;}}}
  if(!dna_bank_physical(bank,&m)){dna_bank_destroy(bank);if(error)*error=Failure(@"Unsupported or invalid physical model");return NO;}
 }
 NSDictionary*fits=extensions[@"physicalFits"];
 if(fits){
  NSArray*items=[fits isKindOfClass:NSDictionary.class]?fits[@"anchors"]:nil;
  if(![fits isKindOfClass:NSDictionary.class]||![fits[@"version"] isKindOfClass:NSNumber.class]||[fits[@"version"] intValue]!=1||![items isKindOfClass:NSArray.class]||items.count>128){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid physical fits");return NO;}
  NSMutableSet*seen=[NSMutableSet new];for(NSDictionary*f in items){DNAPhysicalModel m={0};id midi=[f isKindOfClass:NSDictionary.class]?f[@"midi"]:nil;id confidence=[f isKindOfClass:NSDictionary.class]?f[@"confidence"]:nil;
   if(![midi isKindOfClass:NSNumber.class]||[midi doubleValue]!=[midi intValue]||[seen containsObject:midi]||![confidence isKindOfClass:NSNumber.class]||!std::isfinite([confidence doubleValue])||[confidence doubleValue]<0||[confidence doubleValue]>1||!ReadPhysical(f[@"model"],&m)||!dna_bank_physical_anchor(bank,[midi intValue],&m)){dna_bank_destroy(bank);if(error)*error=Failure(@"Invalid physical fit anchor");return NO;}[seen addObject:midi];
  }
 }
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
 NSDictionary*performance=reflection[@"performance"];[_tree parameterWithAddress:DNA_REFERENCE_HZ].value=tuning?[tuning floatValue]:440;NSDictionary*map=@{@"glideMs":@(DNA_GLIDE),@"trillRateHz":@(DNA_TRILL_RATE),@"trillInterval":@(DNA_TRILL_INTERVAL),@"trillThreshold":@(DNA_TRILL_THRESHOLD),@"velocityTrill":@(DNA_VELOCITY_TRILL),@"noteLengthSeconds":@(DNA_NOTE_LENGTH)};for(NSString*key in map)if([performance[key] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:[map[key] unsignedLongLongValue]].value=[performance[key] floatValue];
 NSArray*voiceNames=@[@"poly",@"mono",@"legato"];NSUInteger voice=[voiceNames indexOfObject:performance[@"voiceMode"]?:@"poly"];[_tree parameterWithAddress:DNA_VOICE_MODE].value=voice<3?voice:0;
 NSUInteger layer=[layers indexOfObject:performance[@"selectedArticulation"]?:@"sustain"];[_tree parameterWithAddress:DNA_LAYER].value=layer<6?layer:0;
 NSDictionary*xy=reflection[@"xy"];for(NSString*name in @[@"tone",@"behavior"]){NSArray*pair=xy[name];int base=[name isEqualToString:@"tone"]?DNA_TONE_X:DNA_BEHAVIOR_X;if([pair isKindOfClass:NSArray.class]&&pair.count==2)for(int i=0;i<2;i++)if([pair[i] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:base+i].value=[pair[i] floatValue];}
 NSDictionary*era=reflection[@"era"];NSUInteger eraIndex=[@[@"none",@"vintage",@"tape"] indexOfObject:era[@"recording"]?:@"none"];[_tree parameterWithAddress:DNA_ERA].value=eraIndex<3?eraIndex:0;if([era[@"amount"] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:DNA_ERA_AMOUNT].value=[era[@"amount"] floatValue];
 NSDictionary*native=reflection[@"extensions"][@"nativePerformance"];NSDictionary*nativeMap=@{@"bendRange":@(DNA_BEND_RANGE),@"modulation":@(DNA_MODULATION),@"engineMode":@(DNA_ENGINE_MODE),@"volume":@(DNA_VOLUME)};for(NSString*key in nativeMap)if([native[key] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:[nativeMap[key] unsignedLongLongValue]].value=[native[key] floatValue];
 NSArray*guitarKeys=@[@"pickup",@"vibratoDepth",@"vibratoRate",@"bodyTexture",@"room",@"slideFrom",@"auditionMidi"];for(int i=0;i<7;i++)[_tree parameterWithAddress:DNA_PICKUP+i].value=[(guitar[guitarKeys[i]]?:guitarDefaults[guitarKeys[i]]) floatValue];
 if(physical){NSDictionary*edits=reflection[@"extensions"][@"physicalControls"]?:@{};NSArray*keys=@[@"hardness",@"position",@"damping",@"noise"];for(int i=0;i<4;i++){NSString*key=keys[i];NSNumber*value=edits[key]?:physical[key]?:@.5;[_tree parameterWithAddress:DNA_HARDNESS+i].value=value.floatValue;}}
 __weak DNAudioUnit*weak=self;dispatch_async(dispatch_get_main_queue(),^{if(weak)[NSNotificationCenter.defaultCenter postNotificationName:@"InstrumentDNAModelChanged" object:weak];});
 return YES;
}
- (NSDictionary*)fullState {NSMutableDictionary*state=[[super fullState] mutableCopy]?:[NSMutableDictionary dictionary];state[StateKey]=self.modelData;NSMutableArray*values=[NSMutableArray array];for(int i=0;i<DNA_PARAMETER_COUNT;i++)[values addObject:@(dna_parameter_get(_kernel,i))];state[@"DNAParameters"]=values;return state;}
- (void)setFullState:(NSDictionary*)state {[super setFullState:state];NSData*data=state[StateKey];if([data isKindOfClass:NSData.class]&&data.length){NSError*error=nil;[self loadModelData:data error:&error];}NSArray*values=state[@"DNAParameters"];if([values isKindOfClass:NSArray.class])for(int i=0;i<MIN(DNA_PARAMETER_COUNT,values.count);i++)if([values[i] isKindOfClass:NSNumber.class])[_tree parameterWithAddress:i].value=[values[i] floatValue];}
@end
