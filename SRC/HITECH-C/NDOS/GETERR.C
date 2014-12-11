/* GETERR - By Konami Man, 2-2001 */

#include "nasm.h"
#include "doscodes.h"
#include "ndos.h"

#undef geterr

int geterr()
{
	regset8 regs8;
	doscall (_ERROR, &regs8);
	return regs8.b;
}

