#include "DNAPhysical.h"
#include <math.h>
#include <string.h>
#define PI 3.14159265358979323846
static float bound(float v,float lo,float hi){return fminf(hi,fmaxf(lo,v));}
void dna_physical_reset(DNAPhysicalState*s){memset(s,0,sizeof(*s));s->random=12345;s->last_hz=-1;}
int dna_physical_valid(const DNAPhysicalModel*m){
 if(!m||m->version!=1||m->kind<0||m->kind>1||m->count<1||m->count>16||m->continuous<0||m->continuous>1)return 0;
 if(!isfinite(m->hardness)||m->hardness<0||m->hardness>1||!isfinite(m->position)||m->position<0||m->position>1||!isfinite(m->noise)||m->noise<0||m->noise>1||!isfinite(m->decay)||m->decay<.05||m->decay>15)return 0;
 if(m->loss_rate!=0&&(!isfinite(m->loss_rate)||m->loss_rate<8000||m->loss_rate>192000))return 0;
 if(m->waveguide_tone!=0&&(!isfinite(m->waveguide_tone)||m->waveguide_tone<.05||m->waveguide_tone>.98))return 0;
 for(int i=0;i<m->count;i++)if(!isfinite(m->ratios[i])||m->ratios[i]<.25||m->ratios[i]>64||!isfinite(m->gains[i])||m->gains[i]<0||m->gains[i]>1||!isfinite(m->t60[i])||m->t60[i]<.02||m->t60[i]>15)return 0;
 return 1;
}
float dna_physical_tick(DNAPhysicalState*s,const DNAPhysicalModel*m,double rate,float hz,DNAPhysicalControls c){
 // Controls and pitch are clamped before delay addressing or feedback calculation.
 hz=bound(hz,40,(float)rate*.4f);float velocity=bound(c.velocity,0,1),hardness=bound(c.hardness,0,1),position=bound(c.position,.02,.98),damping=bound(c.damping,0,1),richness=bound(c.richness,0,1);
 s->random=s->random*1664525u+1013904223u;float noise=(s->random/4294967295.0f)*2-1;
 float cutoff=500+hardness*hardness*14000*(.3f+.7f*velocity),coefficient=1-expf(-(float)(2*PI)*fminf(cutoff,(float)rate*.45f)/(float)rate);
 s->exciter+=coefficient*(noise-s->exciter);
 float output=0;
 if(m->kind==1){
  // Fractional-delay Karplus–Strong loop; averaging loss is compensated in tuning.
  float fittedTone=m->waveguide_tone>0?1-powf(1-m->waveguide_tone,(m->loss_rate>0?m->loss_rate:(float)rate)/(float)rate):0;
  float loopTone=m->waveguide_tone>0?bound(fittedTone+(hardness-m->hardness)*.3f,.01f,.99f):bound(.2f+.7f*hardness+.08f*velocity,.2f,.98f);
  float delay=bound((float)rate/hz-(m->waveguide_tone>0?(1-loopTone)/loopTone:.5f),2,DNA_PHYSICAL_DELAY-3);int whole=(int)delay;float fraction=delay-whole;
  uint32_t at=(s->write+DNA_PHYSICAL_DELAY-whole)%DNA_PHYSICAL_DELAY,previous=(at+DNA_PHYSICAL_DELAY-1)%DNA_PHYSICAL_DELAY;
  float delayed=s->delay[at]*(1-fraction)+s->delay[previous]*fraction;
  float feedback=expf(-6.907755f*delay/((float)rate*m->decay*(1.5f-damping)));

  s->loop+=loopTone*(delayed-s->loop);
  float pluck=s->age<1/hz?s->exciter*(.35f+.65f*velocity):0;
  // A delayed subtraction shapes the initial pluck position without moving body pitch.
  uint32_t comb=(s->write+DNA_PHYSICAL_DELAY-(uint32_t)fmaxf(1,delay*position))%DNA_PHYSICAL_DELAY;
  float excitation=pluck-(s->age<1/hz?s->delay[comb]*.45f:0);
  float next=excitation+s->loop*feedback;
  s->delay[s->write]=bound(next,-2,2);s->write=(s->write+1)%DNA_PHYSICAL_DELAY;output=delayed;
 }else{
  if(s->frame%32==0||s->last_hz<0){
   for(int i=0;i<m->count;i++){
    float frequency=hz*m->ratios[i];
    float t60=m->t60[i]*(1.5f-damping),r=expf(-6.907755f/(t60*(float)rate));
    float angle=(float)(2*PI)*fminf(frequency,(float)rate*.45f)/(float)rate;
    s->a1[i]=2*r*cosf(angle);s->a2[i]=-r*r;
    float spectral=powf(m->measured?bound(1+(hardness-m->hardness)*.7f+(richness-.5f)*.35f+(velocity-100/127.f)*.3f,.15f,1.5f):bound(.3f+.7f*hardness*velocity+.35f*richness,.15f,1),log2f(fmaxf(1,m->ratios[i])));
    float hit=i==0?1:.25f+.75f*fabsf(sinf((float)PI*position*m->ratios[i]));if(m->measured&&i>0)hit/=.25f+.75f*fabsf(sinf((float)PI*.5f*m->ratios[i]));
    s->input_gain[i]=frequency<rate*.45?m->gains[i]*spectral*hit*sinf(angle):0;
   }
   s->last_hz=hz;
  }
  float width=.001f+(1-hardness)*.012f;
  float excitation=(s->frame==0?1:0)+s->exciter*bound(c.noise,0,1)*.08f*expf(-(float)s->age/width);
  if(m->continuous)excitation+=s->exciter*(.002f+.005f*velocity)*(0.2f+bound(c.noise,0,1));
  float normal=0;
  for(int i=0;i<m->count;i++){
   if(s->input_gain[i]==0){s->y1[i]=s->y2[i]=0;continue;}
   float y=s->a1[i]*s->y1[i]+s->a2[i]*s->y2[i]+excitation*s->input_gain[i];
   // Bounded state and finite coefficients prevent unstable exported configurations.
   y=bound(y,-8,8);s->y2[i]=s->y1[i];s->y1[i]=y;output+=y;normal+=m->gains[i];
  }
  output/=fmaxf(1,normal*.6f);
 }
 if(m->kind==1)output*=2.5f;
 float drive=bound(c.drive,0,1)*3*velocity;
 output=tanhf(output*(1+drive))/(1+drive*.4f);
 float tone=1-expf(-(float)(2*PI)*fminf(500+bound(c.brightness,0,1)*15000,(float)rate*.45f)/(float)rate);
 s->last_sample+=tone*(output-s->last_sample);s->age+=1/rate;s->frame++;
 return s->last_sample*(.25f+.75f*velocity)*(.5f+bound(c.body,0,1)*.5f);
}
