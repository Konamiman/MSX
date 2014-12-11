/* DOSCALL - C function for calling DOS functions */
/* By Konami Man, 2-2001 */

#include "nasm.h"
#undef doscall

void doscall (uchar f, regset * regs)
{
	regset8 *regs8;
	if (regs == NULL)
	{
		regset reg2;
		regs = &reg2;
	}
	regs8 = (regset8*) regs;
	regs8->c = (uchar) f;
	asmcall((void*)0x0005, regs);
}
