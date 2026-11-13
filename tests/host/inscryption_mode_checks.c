#include <assert.h>
#include "../../app/Madeira/BCDInscryptionPolicy.h"
int main(void){
 BCDInscryptionMode s={0};
 assert(BCDInscryptionSwitch(&s,0)==BCD_INSCRYPTION_BINDING_UNAVAILABLE);
 assert(!s.explore&&!s.firstStepConsumed);
 assert(BCDInscryptionSwitch(&s,1)==BCD_INSCRYPTION_REQUEST_STEP_BACK);assert(s.explore);
 assert(BCDInscryptionSwitch(&s,0)==BCD_INSCRYPTION_MODE_ONLY);assert(!s.explore);
 assert(BCDInscryptionSwitch(&s,1)==BCD_INSCRYPTION_MODE_ONLY);
 BCDInscryptionMode r={0};BCDInscryptionResync(&r,1);
 assert(BCDInscryptionSwitch(&r,0)==BCD_INSCRYPTION_MODE_ONLY);assert(!r.explore);
 return 0;
}
