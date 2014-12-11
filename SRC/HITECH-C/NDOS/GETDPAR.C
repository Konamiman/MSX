/*** GETDPAR - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef getdpar

int getdpar (int drive, diskparam* dpar)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->l = (uchar) drive;
	regs.de = (uint) dpar;
	doscall (_DPARM, &regs);
	if (regs.a) return regs.a;

	regs8->e = drive;
	doscall (_ALLOC, &regs);
	dpar->clustotal = regs.de;
	dpar->clusfree = regs.hl;
	dpar->dpbpnt = regs.ix;
	return 0;
}

