/*** SETENV - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nsetenv

int nsetenv (char* name, char* buffer)
{
	regset regs;
	regs.hl = (uint) name;
	regs.de = (uint) buffer;
	doscall (_SENV, &regs);
	return regs.a;
}

