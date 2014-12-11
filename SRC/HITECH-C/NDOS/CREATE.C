/*** CREATE - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef create

int create (char* name, int mode, int attributes)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs.de = (uint) name;
	regs.a = (uchar) mode^F_NOINH;
	regs8->b = (uchar) attributes;
	doscall (_CREATE, &regs);
	return regs8->b;
}

