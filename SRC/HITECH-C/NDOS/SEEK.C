/*** SEEK - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef seek

long seek(fhandle fh, long offset, int method)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->b = (uchar) fh;
	regs.a = (uchar) method;
	regs.de = (uint) ((offset & 0xFFFF0000) >> 16);
	regs.hl = (uint) (offset & 0xFFFF);
	doscall (_SEEK, &regs);
	return (regs.hl + ((regs.de)>>16));
}


