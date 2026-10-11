#ifndef DNA_PHYSICAL_H
#define DNA_PHYSICAL_H
#include <stdint.h>
#define DNA_PHYSICAL_MODES 16
#define DNA_PHYSICAL_DELAY 8192
#define DNA_PHYSICAL_VERSION 1
// Independently authored DSP: driven damped modes and a fractional-delay string.
// All configurations are immutable during rendering; voice storage is preallocated.
typedef struct {int version,kind,count,continuous,measured;float ratios[16],gains[16],t60[16];float hardness,position,noise,decay,reference_hz,waveguide_tone,loss_rate;} DNAPhysicalModel;
typedef struct {float y1[16],y2[16],a1[16],a2[16],input_gain[16],delay[8192];uint32_t random,frame,write;double age;float last_hz,last_damping,last_richness,exciter,loop,last_sample;} DNAPhysicalState;
typedef struct {float velocity,hardness,position,damping,noise,richness,body,drive,brightness;} DNAPhysicalControls;
#ifdef __cplusplus
extern "C" {
#endif
void dna_physical_reset(DNAPhysicalState*s);
int dna_physical_valid(const DNAPhysicalModel*m);
float dna_physical_tick(DNAPhysicalState*s,const DNAPhysicalModel*m,double rate,float hz,DNAPhysicalControls c);
#ifdef __cplusplus
}
#endif
#endif
