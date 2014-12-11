/*** GETCWD - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef ngetcwd

int ngetcwd(int drive, char* buffer)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs.de = (uint) buffer;
	regs8->b = (uchar) drive;
	doscall (_GETCD, &regs);
	return regs.a;
}

