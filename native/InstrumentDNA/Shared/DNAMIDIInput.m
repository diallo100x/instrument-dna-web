#import "DNAMIDIInput.h"
#import "DNAudioUnit.h"
#import <CoreMIDI/CoreMIDI.h>
@implementation DNAMIDIInput { MIDIClientRef _client; MIDIPortRef _port; DNAudioUnit *_unit; NSMutableSet<NSNumber*> *_sources; }
- (instancetype)initWithUnit:(DNAudioUnit*)unit {if(!(self=[super init]))return nil;_unit=unit;_sources=[NSMutableSet set];__weak DNAMIDIInput*weak=self;MIDIClientCreateWithBlock(CFSTR("Instrument DNA MIDI"),&_client,^(const MIDINotification*note){[weak connectSources];});DNAudioUnit*u=unit;MIDIInputPortCreateWithBlock(_client,CFSTR("Instrument DNA Input"),&_port,^(const MIDIPacketList*list,void*connection){const MIDIPacket*packet=&list->packet[0];for(UInt32 i=0;i<list->numPackets;i++){uint8_t status=0,a=0;int position=0;for(UInt16 j=0;j<packet->length;j++){uint8_t byte=packet->data[j];if(byte>=0xf8)continue;if(byte&0x80){status=byte;position=0;continue;}if((status&0xf0)==0xc0||(status&0xf0)==0xd0)continue;if(position==0){a=byte;position=1;}else{[u receiveMIDI:status a:a b:byte];position=0;}}packet=MIDIPacketNext(packet);}(void)connection;});[self connectSources];return self;}
- (void)connectSources { @synchronized(_sources) {if(!_port)return;for(ItemCount i=0;i<MIDIGetNumberOfSources();i++){MIDIEndpointRef source=MIDIGetSource(i);if(![_sources containsObject:@(source)]){MIDIPortConnectSource(_port,source,NULL);[_sources addObject:@(source)];}}}}
- (void)dealloc {if(_port)MIDIPortDispose(_port);if(_client)MIDIClientDispose(_client);}
@end
