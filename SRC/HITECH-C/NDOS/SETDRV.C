/*** SETDRV - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef setdrv

/* Devuelve el num. de unidades */

int setdrv(int drive)
{
	regset8 regs;
	regs.e = (uchar) drive;
	doscall (_SELDSK, &regs);
	return regs.a;
}

