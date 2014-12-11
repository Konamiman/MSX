/*** DOSVER - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef dosver

/* Devuelve version kernel + 65536 * version MSXDOS.SYS */

unsigned int dosver(int which)
{
	regset regs;
	doscall(_DOSVER, &regs);
	if(regs.bc<0x200) return 0;
	else return (which?regs.de:regs.bc);
}

