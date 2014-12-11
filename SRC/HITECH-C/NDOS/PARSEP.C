/*** PARSEP - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef parsep

int parsep (char* path, parsedata* pd)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->b = (uchar) pd->f;
	regs.de = (uint) path;
	doscall (_PARSE, &regs);
	pd->f = regs8->b;
	pd->termchar = regs.de;
	pd->lastitem = regs.hl;
	pd->logdrive = regs8->c;
	return regs.a;
}

