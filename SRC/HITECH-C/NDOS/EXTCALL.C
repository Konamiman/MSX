/* EXTCALL - C function for calling extended BIOS functions */
/* By Konami Man, 2-2001 */

#include "nasm.h"
#undef extcall

void extcall (uchar dev, uchar fun, regset * regs)
{
	if (regs == NULL)
	{
		regset reg2;
		regs = &reg2;
	}
	regs->de = (dev<<8)|fun;
	asmcall((void*)0xFFCA, regs);
}

