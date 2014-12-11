/*** JOIN - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef join

uint join(int parent)
{
	regset8 regs;
	regs.b = (uchar) parent;
	doscall (_JOIN, &regs);
	return regs.b + 256*regs.c;
}

