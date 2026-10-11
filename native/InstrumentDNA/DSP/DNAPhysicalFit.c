#include "DNAPhysicalFit.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#define PI 3.14159265358979323846
static double bound(double x,double lo,double hi){return fmin(hi,fmax(lo,x));}
typedef struct {double hz,gain,t60,slope,r2,observed,confidence;} Peak;
static int decay(const float*a,int length,double sr,double hz,Peak*p){
 int n=(int)fmin(4096,fmax(512,round(sr*fmax(.055,8/hz)))),hop=(int)round(sr*.045),count=0;
 double times[60],amps[60],peak=0;
 for(int start=(int)round(sr*.035);start+n<=length&&count<60;start+=hop){double re=0,im=0;for(int i=0;i<n;i++){double x=a[start+i]*(.5-.5*cos(2*PI*i/(n-1))),w=2*PI*hz*i/sr;re+=x*cos(w);im+=x*sin(w);}times[count]=(start+n*.5)/sr;amps[count]=hypot(re,im)/n;peak=fmax(peak,amps[count]);count++;}
 double x[60],y[60],sx=0,sy=0,sxx=0,sxy=0;int usable=0;
 for(int i=0;i<count;i++)if(amps[i]>fmax(1e-7,peak*.03)){x[usable]=times[i];y[usable]=log(amps[i]);sx+=x[usable];sy+=y[usable];sxx+=x[usable]*x[usable];sxy+=x[usable]*y[usable];usable++;}
 if(usable<5)return 0;
 double slope=(usable*sxy-sx*sy)/(usable*sxx-sx*sx),intercept=(sy-slope*sx)/usable,total=0,error=0;
 for(int i=0;i<usable;i++){total+=pow(y[i]-sy/usable,2);error+=pow(y[i]-intercept-slope*x[i],2);}
 double r2=1-error/fmax(1e-12,total),drop=-slope*(x[usable-1]-x[0]),t60=-log(1000)/slope;
 if(!isfinite(slope)||slope>=0||r2<.8||drop<.65||t60<.02||t60>15)return 0;
 p->slope=slope;p->t60=t60;p->r2=r2;p->observed=x[usable-1]-x[0];p->confidence=bound(r2*fmin(1,drop/2.3),0,.85);return 1;
}
static int by_gain(const void*a,const void*b){double d=((const Peak*)b)->gain-((const Peak*)a)->gain;return d>0?1:d<0?-1:0;}
static int by_hz(const void*a,const void*b){double d=((const Peak*)a)->hz-((const Peak*)b)->hz;return d>0?1:d<0?-1:0;}
int dna_physical_fit(const float*a,int length,double sr,int midi,int kind,DNAPhysicalFit*out){
 if(!a||!out||!isfinite(sr)||sr<8000||sr>192000||length<sr*.35||length>sr*15||midi<24||midi>108||kind<0||kind>1)return 0;
 for(int i=0;i<length;i++)if(!isfinite(a[i]))return 0;
 int n=1;while(n*2<=8192&&n*2<=length)n*=2;
 double *re=calloc(n,sizeof(double)),*im=calloc(n,sizeof(double)),*mag=calloc(n/2,sizeof(double));Peak*peaks=calloc(n/2,sizeof(Peak));
 if(!re||!im||!mag||!peaks){free(re);free(im);free(mag);free(peaks);return 0;}
 int offset=(int)fmin(round(sr*.025),length-n);
 for(int i=0;i<n;i++)re[i]=a[offset+i]*(.5-.5*cos(2*PI*i/(n-1)));
 for(int i=1,j=0;i<n;i++){int bit=n>>1;for(;j&bit;bit>>=1)j^=bit;j^=bit;if(i<j){double tmp=re[i];re[i]=re[j];re[j]=tmp;}}
 for(int size=2;size<=n;size*=2)for(int start=0;start<n;start+=size)for(int j=0;j<size/2;j++){double w=-2*PI*j/size,c=cos(w),s=sin(w);int p=start+j,q=p+size/2;double r=re[q]*c-im[q]*s,t=re[q]*s+im[q]*c;re[q]=re[p]-r;im[q]=im[p]-t;re[p]+=r;im[p]+=t;}
 double maximum=0,f0=440*pow(2,(midi-69)/12.);for(int i=0;i<n/2;i++){mag[i]=hypot(re[i],im[i]);maximum=fmax(maximum,mag[i]);}
 int count=0;
 if(maximum>1e-5)for(int i=2;i<n/2-1;i++)if(mag[i]>maximum*.045&&mag[i]>=mag[i-1]&&mag[i]>mag[i+1]){
  double l=log(mag[i-1]+1e-12),c=log(mag[i]+1e-12),r=log(mag[i+1]+1e-12),hz=(i+bound(.5*(l-r)/(l-2*c+r),-.5,.5))*sr/n;
  if(!isfinite(hz)||hz/f0<.25||hz/f0>64||hz>=sr*.45)continue;
  Peak p={0};p.hz=hz;p.gain=mag[i]/maximum;peaks[count++]=p;
 }
 qsort(peaks,count,sizeof(Peak),by_gain);int candidates=count<32?count:32;count=0;for(int i=0;i<candidates;i++){Peak p=peaks[i];if(decay(a,length,sr,p.hz,&p))peaks[count++]=p;}
 int success=0;
 if(count){qsort(peaks,count,sizeof(Peak),by_gain);if(count>16)count=16;qsort(peaks,count,sizeof(Peak),by_hz);memset(out,0,sizeof(*out));out->confidence=.85f;
  DNAPhysicalModel*m=&out->model;m->version=1;m->measured=1;m->kind=kind;m->count=count;m->hardness=.7f;m->position=.5f;m->decay=(float)peaks[0].t60;m->reference_hz=(float)f0;
  for(int i=0;i<count;i++){m->ratios[i]=(float)(peaks[i].hz/f0);m->gains[i]=(float)peaks[i].gain;m->t60[i]=(float)peaks[i].t60;out->frequencies[i]=(float)peaks[i].hz;out->r2[i]=(float)peaks[i].r2;out->observed[i]=(float)peaks[i].observed;out->confidence=fminf(out->confidence,(float)peaks[i].confidence);}
  success=1;
  if(kind==1){int harmonics[16],hcount=0,fundamental=0;for(int i=0;i<count;i++)if(fabs(m->ratios[i]-round(m->ratios[i]))<.04&&round(m->ratios[i])<=12){harmonics[hcount++]=i;if(fabs(m->ratios[i]-1)<.04)fundamental=1;}
   double best=HUGE_VAL,best_base=0,best_tone=0;
   if(hcount>=2&&fundamental)for(double tone=.05;tone<=.98001;tone+=.005){double losses[16],base=0;for(int i=0;i<hcount;i++){Peak*p=&peaks[harmonics[i]];losses[i]=f0*log(tone/sqrt(1+pow(1-tone,2)-2*(1-tone)*cos(2*PI*p->hz/sr)));base+=p->slope-losses[i];}base/=hcount;if(base>=0)continue;double error=0;for(int i=0;i<hcount;i++)error+=pow(peaks[harmonics[i]].slope-base-losses[i],2);error/=hcount;if(error<best){best=error;best_base=base;best_tone=tone;}}
   if(!isfinite(best)||-log(1000)/best_base>15)success=0;else{m->waveguide_tone=(float)best_tone;m->loss_rate=(float)sr;m->decay=(float)bound(-log(1000)/best_base,.05,15);out->loss_error=(float)sqrt(best);out->confidence/=1+out->loss_error;}
  }else out->confidence*=.9f;
  success=success&&dna_physical_valid(m);
 }
 free(re);free(im);free(mag);free(peaks);return success;
}
