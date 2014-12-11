/*** CLOSE - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nclose

int nclose (fhandle fh)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->b = fh;
	doscall (_CLOSE, &regs);
	return (int)regs.a;
}

