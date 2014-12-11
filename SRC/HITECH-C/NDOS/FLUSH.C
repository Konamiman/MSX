/*** FLUSH - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef flush

int flush(int drive, int op)
{
	regset8 regs;
	regs.b = (uchar) (drive<0 ? 0xFF : drive);
	regs.d = (uchar) (op ? 0xFF : 0);
	doscall (_FLUSH, &regs);
	return regs.b;
}

