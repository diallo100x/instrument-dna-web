#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface DNAudioUnit : AUAudioUnit
@property(nonatomic,readonly) NSData *modelData;
- (void)touchNote:(NSInteger)slot midi:(NSInteger)midi velocity:(float)velocity down:(BOOL)down;
- (void)touchBend:(NSInteger)slot semitones:(float)semitones;
- (void)panic;
- (void)receiveMIDI:(uint8_t)status a:(uint8_t)a b:(uint8_t)b;
- (BOOL)loadModelData:(NSData *)data error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
