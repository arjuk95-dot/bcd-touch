#pragma once
#include <cstdint>
#include <cstddef>
#include <algorithm>
#include <cstdlib>
namespace queen_nav662 {
struct Span{uint32_t bits,pad;Span* next;};
struct HF{int w,h;char unused[32];Span** heads;};
static_assert(sizeof(Span)==16 && offsetof(Span,next)==8 && offsetof(HF,heads)==40);
inline void Filter(int height,int climb,HF* hf) {
 constexpr int dx[4]={-1,0,1,0},dz[4]={0,1,0,-1};
 for(int z=0;z<hf->h;++z)for(int x=0;x<hf->w;++x)
 for(Span*s=hf->heads[static_cast<std::ptrdiff_t>(x)+static_cast<std::ptrdiff_t>(z)*hf->w];s;s=s->next){
  if(!(s->bits>>26))continue;
  int bot=(s->bits>>13)&8191,top=s->next?int(s->next->bits&8191):65535;
  int mind=65535,amin=bot,amax=bot;
  for(int d=0;d<4;++d){
   int nx=x+dx[d],nz=z+dz[d];
   if(nx<0||nz<0||nx>=hf->w||nz>=hf->h){mind=std::min(mind,-climb-bot);continue;}
   Span*n=hf->heads[static_cast<std::ptrdiff_t>(nx)+static_cast<std::ptrdiff_t>(nz)*hf->w];int ntop=n?int(n->bits&8191):65535;
   if(std::min(top,ntop)-std::max(bot,-climb)>height)mind=std::min(mind,-climb-bot);
   for(;n;n=n->next){
    int nb=(n->bits>>13)&8191;ntop=n->next?int(n->next->bits&8191):65535;
    if(std::min(top,ntop)-std::max(bot,nb)>height){
     int delta=nb-bot;mind=std::min(mind,delta);
     if(std::abs(delta)<=climb){amin=std::min(amin,nb);amax=std::max(amax,nb);}
    }
   }
  }
  if(mind< -climb||amax-amin>climb)s->bits&=0x03ffffff;
 }
}

}
