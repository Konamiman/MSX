/*** GETDTA - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef getdta

int getdta()
{
	regset regs;
	doscall (_GETDTA, &regs);
	return regs.de;
}

