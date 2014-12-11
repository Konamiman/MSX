/*** GETDRV - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef getdrv

int getdrv()
{
	regset regs;
	doscall (_CURDRV, &regs);
	return regs.a;
}

