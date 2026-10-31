#include "DNAPhysical.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static DNAPhysicalModel model(void){
 DNAPhysicalModel m={.version=1,.kind=3,.count=4,.ratios={1,4,10,18},.gains={1,.5,.2,.1},.t60={4,2,.7,.3},.hardness=.7,.position=.28,.noise=.12,.decay=4,.reference_hz=261.625565f,.body_count=3,.excitation=0,.body_ratios={1,2,3},.body_gains={1,.3,.1},.body_t60={1.4,.7,.3},.coupling=.5,.body_mix=.7,.follow=1,.velocity_response=.75,.contact=.0012,.material_loss=.08,.inharmonicity=.00003};return m;
}
static DNAPhysicalControls controls(void){DNAPhysicalControls c={.velocity=.8,.hardness=.7,.position=.28,.damping=.5,.noise=.12,.richness=.5,.body=.5,.brightness=.8,.coupling=.5,.body_mix=.7,.resonator_follow=1,.velocity_response=.75};return c;}
int main(void){
 DNAPhysicalModel m=model();assert(dna_physical_valid(&m));
 DNAPhysicalState *a=malloc(sizeof(*a)),*b=malloc(sizeof(*b));assert(a&&b);
 for(int rate=8000;rate<=192000;rate=rate==8000?24000:rate*2)for(int shape=0;shape<3;shape++){
  m.excitation=shape;DNAPhysicalControls c=controls();dna_physical_reset(a);double energy=0;
  for(int i=0;i<rate/4;i++){float hz=i<rate/8?65:2093,x=dna_physical_tick(a,&m,rate,hz,c);assert(isfinite(x)&&fabsf(x)<=1);energy+=x*x;}
  assert(energy>1e-10);
 }
 m=model();dna_physical_reset(a);dna_physical_reset(b);DNAPhysicalControls dry=controls(),wet=controls();dry.coupling=0;wet.coupling=1;dry.body_mix=wet.body_mix=1;
 double difference=0;for(int i=0;i<24000;i++){float x=dna_physical_tick(a,&m,24000,261.625565f,dry),y=dna_physical_tick(b,&m,24000,261.625565f,wet);difference+=(x-y)*(x-y);}assert(difference>1e-7);
 dna_physical_reset(a);dna_physical_reset(b);dry=controls();wet=controls();dry.velocity=wet.velocity=.5;dry.resonator_follow=0;wet.resonator_follow=1;
 dna_physical_tick(a,&m,24000,523.251f,dry);dna_physical_tick(b,&m,24000,523.251f,wet);assert(fabsf(a->ba1[0]-b->ba1[0])>.001f);
 DNAPhysicalModel bad=m;bad.body_count=9;assert(!dna_physical_valid(&bad));bad=m;bad.contact=0;assert(!dna_physical_valid(&bad));bad=m;bad.body_t60[0]=INFINITY;assert(!dna_physical_valid(&bad));bad=m;bad.coupling=1.1;assert(!dna_physical_valid(&bad));bad=m;bad.excitation=3;assert(!dna_physical_valid(&bad));
 free(a);free(b);puts("Native coupled bodies: finite retuned strike/pluck/air at 8–192 kHz, audible coupling, independent body tracking and invalid-model rejection passed.");return 0;
}
