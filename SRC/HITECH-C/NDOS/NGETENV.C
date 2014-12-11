/*** GETENV - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef ngetenv

int ngetenv (char* name, char* buffer, int bufsize)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs.hl = (uint) name;
	regs.de = (uint) buffer;
	regs8->b = (uchar) bufsize;
	doscall (_GENV, &regs);
	return regs.a;
}

