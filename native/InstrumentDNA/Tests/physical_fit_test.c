#include "DNAPhysicalFit.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#define PI 3.14159265358979323846
int main(void){
 int sr=16000,length=sr*2;float*a=calloc(length,sizeof(float));assert(a);DNAPhysicalFit fit;
 double hz=440*pow(2,(60-69)/12.),ratios[]={1,2.71,4.08},gains[]={.5,.3,.2},t60[]={2,1,.7};
 for(int i=0;i<length;i++)for(int h=0;h<3;h++)a[i]+=(float)(gains[h]*sin(2*PI*hz*ratios[h]*i/sr)*exp(-log(1000)*i/sr/t60[h]));
 assert(dna_physical_fit(a,length,sr,60,0,&fit));assert(fit.model.count==3);
 for(int h=0;h<3;h++){assert(fabs(fit.model.ratios[h]-ratios[h])<.01);assert(fabs(fit.model.t60[h]-t60[h])<.12);}
 for(int i=0;i<length;i++){a[i]=0;for(int h=1;h<=4;h++){double tone=.72,base=-log(1000)/2,loss=440*log(tone/sqrt(1+pow(1-tone,2)-2*(1-tone)*cos(2*PI*440*h/sr)));a[i]+=(float)(.5/h*sin(2*PI*440*h*i/sr)*exp((base+loss)*i/sr));}}
 assert(dna_physical_fit(a,length,sr,69,1,&fit));assert(fabs(fit.model.waveguide_tone-.72)<.03);assert(fabs(fit.model.decay-2)<.2);assert(fit.loss_error<.1);fit.model.waveguide_tone=.98f;assert(dna_physical_valid(&fit.model));fit.model.waveguide_tone=.05f;assert(dna_physical_valid(&fit.model));
 for(int i=0;i<length;i++){a[i]=.5f*sinf((float)(2*PI*440*i/sr));}assert(!dna_physical_fit(a,length,sr,69,0,&fit));
 a[0]=NAN;assert(!dna_physical_fit(a,length,sr,69,0,&fit));assert(!dna_physical_fit(a,16,sr,69,0,&fit));free(a);puts("Native physical frequency/decay/string-loss fitting and rejection tests passed.");return 0;
}
