/*** CHDIR - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nchdir

int nchdir (char* dir)
{
	regset regs;
	regs.de = (uint) dir;
	doscall (_CHDIR, &regs);
	return regs.a;
}

