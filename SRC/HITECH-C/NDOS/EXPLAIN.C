/*** EXPLAIN - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef explain

int explain(int code, char* buffer)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->b = (uchar) code;
	regs.de = (uint) buffer;
	doscall (_EXPLAIN, &regs);
	return regs8->b;
}

