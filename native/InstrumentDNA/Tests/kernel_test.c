#include "DNAKernel.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#define SR 48000
#define N 48000
static float left[N],right[N];
static void render(DNAKernel*k){for(int offset=0;offset<N;offset+=256){int count=N-offset<256?N-offset:256;dna_render(k,left+offset,right+offset,count);}for(int i=0;i<N;i++){assert(isfinite(left[i]));assert(left[i]==right[i]);assert(fabsf(left[i])<=1);}}
static double frequency(void){int crossings=0;for(int i=12001;i<36000;i++)if(left[i-1]<=0&&left[i]>0)crossings++;return crossings*2.;}
static double energy(void){double sum=0;for(int i=24000;i<N;i++)sum+=left[i]*left[i];return sum/24000;}
static double component(double hz){double re=0,im=0;for(int i=12000;i<36000;i++){double phase=6.283185307179586*hz*i/SR;re+=left[i]*cos(phase);im+=left[i]*sin(phase);}return hypot(re,im)/24000;}
static void pitch_test(void){DNAKernel*k=dna_kernel_create(SR);assert(k);dna_note_set(k,0,60,1,1);render(k);assert(energy()>.0001);assert(fabs(frequency()-261.63)<4);dna_note_bend(k,0,12);render(k);assert(fabs(frequency()-523.25)<4);dna_parameter_set(k,DNA_BEND_RANGE,12);dna_parameter_set(k,DNA_PITCH,-1);render(k);assert(fabs(frequency()-261.63)<4);dna_all_notes_off(k);render(k);assert(energy()<1e-10);dna_kernel_destroy(k);}
static void independent_test(void){DNAKernel*k=dna_kernel_create(SR);dna_note_set(k,0,60,.8,1);dna_note_set(k,1,64,.8,1);dna_note_bend(k,0,12);render(k);assert(component(523.25)>.01);assert(component(329.63)>.01);assert(component(261.63)<.003);dna_kernel_destroy(k);}
static void mono_test(void){DNAKernel*k=dna_kernel_create(SR);dna_parameter_set(k,DNA_VOICE_MODE,2);dna_note_set(k,0,60,1,1);render(k);dna_note_set(k,1,64,1,1);render(k);assert(fabs(frequency()-329.63)<4);dna_note_set(k,1,64,0,0);render(k);assert(fabs(frequency()-261.63)<4);dna_kernel_destroy(k);}
static void midi_test(void){DNAKernel*k=dna_kernel_create(SR);dna_midi(k,0x91,60,100);dna_midi(k,0x92,60,100);dna_midi(k,0xe1,127,127);render(k);assert(component(261.63)>.005);assert(component(293.65)>.005);dna_all_notes_off(k);render(k);dna_midi(k,0x90,69,100);dna_midi(k,0xb0,64,127);dna_midi(k,0x80,69,0);render(k);assert(energy()>.0001);dna_midi(k,0xb0,64,0);render(k);assert(energy()<1e-10);dna_kernel_destroy(k);}
static void sample_layers_test(void){DNAKernel*k=dna_kernel_create(SR);DNABank*b=dna_bank_create();float *a=malloc(N*3*sizeof(float)),*c=malloc(N*3*sizeof(float));for(int i=0;i<N*3;i++){a[i]=sin(6.283185307179586*440*i/SR)*.6;c[i]=sin(6.283185307179586*880*i/SR)*.6;}float h[]={1,.4,.2};assert(dna_bank_anchor(b,0,60,.01,1,.1,h,3,0));assert(dna_bank_anchor(b,1,60,.01,1,.1,h,3,0));assert(dna_bank_sample(b,0,60,a,N*3,SR));assert(dna_bank_sample(b,1,60,c,N*3,SR));free(a);free(c);dna_bank_publish(k,b);dna_note_set(k,0,60,1,1);render(k);assert(fabs(frequency()-440)<4);dna_all_notes_off(k);render(k);dna_parameter_set(k,DNA_LAYER,1);dna_note_set(k,0,60,1,1);render(k);assert(fabs(frequency()-880)<4);dna_kernel_destroy(k);}
static void*publisher(void*context){DNAKernel*k=context;for(int i=0;i<200;i++){DNABank*b=dna_bank_create();float h[]={1,.2};assert(dna_bank_anchor(b,0,60,.01,.5,.1,h,2,0));dna_bank_publish(k,b);}return NULL;}
static void publication_test(void){DNAKernel*k=dna_kernel_create(SR);dna_note_set(k,0,60,1,1);pthread_t thread;assert(pthread_create(&thread,NULL,publisher,k)==0);for(int i=0;i<50;i++)render(k);pthread_join(thread,NULL);dna_kernel_destroy(k);}
static void panic_test(void){DNAKernel*k=dna_kernel_create(SR);dna_parameter_set(k,DNA_ENGINE_MODE,3);dna_note_set(k,0,60,1,1);render(k);assert(energy()>.00001);dna_all_notes_off(k);render(k);assert(energy()<1e-10);dna_kernel_destroy(k);}
static void preview_test(void){
 DNAKernel*k=dna_kernel_create(SR);DNABank*b=dna_bank_create();float*sample=malloc(N*3*sizeof(float));for(int i=0;i<N*3;i++)sample[i]=.4f*sin(6.283185307179586*880*i/SR);assert(dna_bank_sample(b,1,69,sample,N*3,SR));free(sample);dna_bank_publish(k,b);
 dna_parameter_set(k,DNA_VOICE_MODE,2);dna_parameter_set(k,DNA_ENGINE_MODE,1);dna_parameter_set(k,DNA_PITCH,1);dna_parameter_set(k,DNA_BEND_RANGE,12);
 dna_note_set(k,0,48,1,1);dna_preview(k,69,1,1,1);render(k);assert(component(880)>.05);assert(component(261.63)>.02);assert(dna_parameter_get(k,DNA_LAYER)==0);assert(dna_parameter_get(k,DNA_ENGINE_MODE)==1);
 dna_preview(k,69,1,1,0);render(k);assert(component(880)<.001);assert(component(261.63)>.02);
 dna_preview(k,69,1,0,1);render(k);assert(energy()>.0001);dna_all_notes_off(k);render(k);assert(energy()<1e-10);dna_kernel_destroy(k);
}
int main(void){preview_test();panic_test();pitch_test();independent_test();mono_test();midi_test();sample_layers_test();publication_test();puts("Native DSP: output, independent/global bend, legato priority, MPE, sustain, sample layers, struck-note panic and concurrent model publication passed.");return 0;}
