/*** OPEN - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nopen

int nopen (char * filename, char mode)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs.de = (uint) filename;
	regs.a = (uchar) (mode^F_NOINH);
	doscall (_OPEN, &regs);
	return regs8->b;
}

