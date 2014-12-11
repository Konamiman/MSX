/* BIOSCALL - C function for calling BIOS routines */
/* By Konami Man, 2-2001 */

#include "nasm.h"
#undef bioscall

void bioscall (void* a, regset * reg)
{
	if (reg == NULL)
	{
		regset reg2;
		reg = &reg2;
	}
	reg->ix = (uint) a;
	reg->iy = (*(uint *)0xFCC0);
	asmcall((void*)0x001C, reg);
}
