/*** WPATH - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef wpath

char* wpath(char* buffer)
{
	regset regs;
	regs.de = (uint) buffer;
	doscall (_WPATH, &regs);
	return regs.hl;
}

