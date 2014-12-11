/*** SETDTA - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef setdta

void setdta (char * addr)
{
	regset regs;
	regs.de = (uint) addr;
	doscall (_SETDTA, &regs);
}

