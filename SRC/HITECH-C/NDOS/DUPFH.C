/*** DUPFH - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef dupfh

int dupfh (fhandle fh)
{
	regset8 regs;
	regs.b = (uchar) fh;
	doscall(_DUP, &regs);
	return regs.b;
}

