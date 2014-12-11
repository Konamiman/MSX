/*** GDATE - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef gdate

void gdate(date* dt)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	doscall (_GDATE, &regs);
	dt->year = regs.hl;
	dt->month = regs8->d;
	dt->day = regs8->e;
	dt->wday = regs.a;
}

