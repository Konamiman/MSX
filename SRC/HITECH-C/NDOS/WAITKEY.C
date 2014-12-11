/*** WAITKEY - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef waitkey

void waitkey ()
{
	regset regs;
	do doscall (_CONST, &regs); while (!regs.a);
}

