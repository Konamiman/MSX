/*** PARSEF - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef parsef

int parsef(char* fname, char* buffer, parsedata* pd)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs.de = (uint) fname;
	regs.hl = (uint) buffer;
	doscall (_PFILE, &regs);
	pd->f = regs8->b;
	pd->termchar = regs.de;
	pd->lastitem = regs.hl;
	return regs.a;
}

