/*** ABSEC - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef absec

int absec(int drive, int sector, int number, char* addr, int op)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	if(addr)
	{
		regs.de = (uint) addr;
		doscall (_SETDTA, &regs);
	}
	regs8->h = (uchar) number;
	regs8->l = (uchar) drive;
	regs.de = (uint) sector;
	doscall (op?_WRABS:_RDABS, &regs);
	return regs.a;
}

