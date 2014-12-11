/*** SDATE - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef sdate

int sdate (date* dt)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs.hl = dt->year;
	regs8->d = dt->month;
	regs8->e = dt->day;
	doscall (_SDATE, &regs);
	return (regs.a!=0);
}

