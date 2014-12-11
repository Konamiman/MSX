/*** CHKCHAR - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef chkchar

char chkchar(char* c, char* f)	 /* "f" is of "flags" type actually */
{
	regset8 regs;
	regs.e = *c;
	regs.d = *f;
	doscall (_CHKCHR, &regs);
	*c = regs.e;
	*f = regs.d;
	return regs.e;
}

