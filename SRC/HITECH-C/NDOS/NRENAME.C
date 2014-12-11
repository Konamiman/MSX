/*** RENAME - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nrename

int nrename (char* oldname, char* newname)
{
	regset regs;
	regs.de = (uint) oldname;
	regs.hl = (uint) newname;
	doscall (_RENAME, &regs);
	return regs.a;
}

