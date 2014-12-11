/*** FINDENV - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef findenv

int findenv (int number, char* buffer, int bufsize)
{
	regset regs;
	regset8* regs8 = (regset8*) &regs;
	regs.de = (uint) number;
	regs.hl = (uint) buffer;
	regs8->b = (uchar) bufsize;
	doscall (_FENV, &regs);
	return regs.a;
}

