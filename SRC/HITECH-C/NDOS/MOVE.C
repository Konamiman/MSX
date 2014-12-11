/*** MOVE - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef move

int move (char* oldpath, char* newpath)
{
	regset regs;
	regs.de = (uint) oldpath;
	regs.hl = (uint) newpath;
	doscall (_MOVE, &regs);
	return regs.a;
}

