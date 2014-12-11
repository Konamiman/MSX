/*** EOF - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef eof

int eof (fhandle fh)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->b = (uchar) fh;
	regs.a = (uchar) 0;
	doscall (_IOCTL, &regs);
	return ((regs8->e & 64)!=0);
}

