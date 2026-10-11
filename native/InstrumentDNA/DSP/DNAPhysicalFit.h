#ifndef DNA_PHYSICAL_FIT_H
#define DNA_PHYSICAL_FIT_H
#include "DNAPhysical.h"
// Analysis only: allocates scratch memory; never call on the audio render thread.
typedef struct {DNAPhysicalModel model;float confidence,loss_error,frequencies[16],r2[16],observed[16];} DNAPhysicalFit;
int dna_physical_fit(const float *pcm,int length,double rate,int midi,int kind,DNAPhysicalFit *fit);
#endif
