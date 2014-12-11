/*** IOCTRL - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef ioctrl

/* En realidad "params" es del tipo "flags" */

int ioctrl(fhandle fh, int subf, int* params)
{
	regset regs;
	regset8* regs8 = (regset8*) &regs;
	regs8->b = (uchar) fh;
	regs.a = (uchar) subf;
	regs.de = (uint) params;
	doscall(_IOCTL, &regs);
	*params = regs.de;
	return regs.a;
}

