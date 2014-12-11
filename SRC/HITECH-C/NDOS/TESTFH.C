/*** TESTFH - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef testfh

int testfh (char* fname, fhandle fh)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->b = (uchar) fh;
	regs.de = (uint) fname;
	doscall(_HTEST, &regs);
	return(regs8->b ? -1 : 0);
}

