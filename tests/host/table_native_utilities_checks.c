#include <assert.h>
#include "../../app/Madeira/BCDTableNativeUtilities.h"
int main(void) {
 const char *c="a9929c9e7e7f06829692ae7c23df2c147d64ea050bdf18649adbd44e1fbcd075";
 const char *i="faca117d2bcfacc1ea980de701253fff20b8c7fb93e01b7033a1f3820697f6a8";
 const uint16_t want[]={0x1000,0x2000,0,0x4000,0x10,0,0};
 for(int u=0;u<7;u++) {
  assert(BCDTableNativeButton(BCDTableSkald,u,c,i,1)==want[u]);
  assert(!BCDTableNativeButton(BCDTableSTS2,u,c,i,1));
  assert(!BCDTableNativeButton(BCDTableSkald,u,"bad",i,1));
  assert(!BCDTableNativeButton(BCDTableSkald,u,c,"bad",1));
  assert(!BCDTableNativeButton(BCDTableSkald,u,0,i,1));
 }
 assert(!BCDTableNativeButton(BCDTableSkald,BCDTableInventory,c,i,0));
 const char *sc="0861bfa1df347538d932f22d580e75420f08082792eb914e53b4882764acdbe9";
 const char *si="88bc2e4f6a2627204b20a714cb8746a269c009e48255dcfc7a0eaef9503d2227";
 for(int u=0;u<7;u++) {
   assert(BCDTableNativeButton(BCDTableSTS2,u,sc,si,0)==(u==BCDTableCancel?0x2000:u==BCDTableMap?0x20:0));
   assert(!BCDTableNativeButton(BCDTableSTS2,u,"bad",si,0));
   assert(!BCDTableNativeButton(BCDTableSTS2,u,sc,"bad",0));
 }
 assert(BCDTableNativeButton(BCDTableSTS2,BCDTableMap,"0861bfa1df347538d932f22d580e75420f08082792eb914e53b4882764acdbe9","88bc2e4f6a2627204b20a714cb8746a269c009e48255dcfc7a0eaef9503d2227",0)==0x20);
 assert(!BCDTableNativeButton(99,BCDTableSelect,c,i,1));
 assert(!BCDTableNativeButton(BCDTableSkald,99,c,i,1));
}
