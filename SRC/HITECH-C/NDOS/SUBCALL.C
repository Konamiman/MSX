/* SUBCALL - C function for calling sub-BIOS routines */
/* By Konami Man, 2-2001 */

#include "nasm.h"
#undef subcall

void subcall (void* a, regset * reg)
{
	if (reg == NULL)
	{
		regset reg2;
		reg = &reg2;
	}
	reg->ix = (uint) a;
	reg->iy = (*(uint *)0xFAF7);
	asmcall((void*)0x001C, reg);
}
