/*** EXIT - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nexit

void nexit(int code)
{
	regset8 regs8;
	regs8.b = (uchar) code;
	doscall (_TERM, (regset *) &regs8);
}

