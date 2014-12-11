/*** FORK - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef fork

int fork()
{
	regset8 regs;
	doscall (_FORK, &regs);
	return regs.b;
}

