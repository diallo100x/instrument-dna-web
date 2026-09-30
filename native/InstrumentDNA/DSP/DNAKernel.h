#ifndef DNA_KERNEL_H
#define DNA_KERNEL_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
enum { DNA_ATTACK, DNA_BODY, DNA_BRIGHTNESS, DNA_HARMONICS, DNA_NOISE, DNA_RESONANCE, DNA_DYNAMICS, DNA_ARTICULATION, DNA_MOVEMENT, DNA_DRIVE, DNA_TONE_X, DNA_TONE_Y, DNA_BEHAVIOR_X, DNA_BEHAVIOR_Y, DNA_VOLUME, DNA_PITCH, DNA_MODULATION, DNA_BEND_RANGE, DNA_VOICE_MODE, DNA_GLIDE, DNA_LAYER, DNA_ERA, DNA_ERA_AMOUNT, DNA_TRILL_RATE, DNA_TRILL_INTERVAL, DNA_VELOCITY_TRILL, DNA_TRILL_THRESHOLD, DNA_NOTE_LENGTH, DNA_ENGINE_MODE, DNA_PARAMETER_COUNT };
enum { DNA_TOUCH_SLOTS=32, DNA_MIDI_SLOTS=2048, DNA_SLOT_COUNT=2080, DNA_LAYERS=6 };
typedef struct DNAKernel DNAKernel;
typedef struct DNABank DNABank;
DNAKernel *dna_kernel_create(double sample_rate);
void dna_kernel_destroy(DNAKernel *kernel);
void dna_kernel_set_rate(DNAKernel *kernel,double sample_rate);
void dna_parameter_set(DNAKernel *kernel,int parameter,float value);
float dna_parameter_get(DNAKernel *kernel,int parameter);
void dna_note_set(DNAKernel *kernel,int slot,int midi,float velocity,int down);
void dna_note_bend(DNAKernel *kernel,int slot,float semitones);
void dna_midi(DNAKernel *kernel,uint8_t status,uint8_t a,uint8_t b);
void dna_all_notes_off(DNAKernel *kernel);
void dna_render(DNAKernel *kernel,float *left,float *right,uint32_t frames);
DNABank *dna_bank_create(void);
void dna_bank_destroy(DNABank *bank);
int dna_bank_anchor(DNABank *bank,int layer,int midi,float attack,float decay,float release,const float *harmonics,int count,int struck);
int dna_bank_sample(DNABank *bank,int layer,int midi,const float *mono,uint32_t length,double sample_rate);
// Transfers ownership. Immutable banks are published outside the render thread.
void dna_bank_publish(DNAKernel *kernel,DNABank *bank);
#ifdef __cplusplus
}
#endif
#endif
