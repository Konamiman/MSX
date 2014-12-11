/*** GTIME - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef gtime

void gtime(time* tm)
{
	regset8 regs;
	doscall (_GTIME, &regs);
	tm->hour = regs.h;
	tm->minute = regs.l;
	tm->second = regs.d;
}
