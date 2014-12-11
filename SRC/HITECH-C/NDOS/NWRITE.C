/*** WRITE - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nwrite

int nwrite (fhandle fh, char* buf, int nbytes)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->b = fh;
	regs.de = (uint) buf;
	regs.hl = nbytes;
	doscall (_WRITE, &regs);
	return (int)regs.hl;
}

