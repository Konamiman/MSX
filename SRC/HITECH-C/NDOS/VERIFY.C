/*** VERIFY - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef verify

/*
Entrada: mode=0 para desactivar
	 mode=1 para activar
	 mode>1 para consultar
Salida:  0 si esta desactivado
	 1 si esta activado
	 otro: error
*/

int verify(int mode)
{
	regset8 regs;
	regs.a = (uchar) (mode<2 ? 1:0);
	regs.b = (uchar) (mode ? 0:0xFF);
	doscall (_DSKCHK, &regs);
	if(!regs.a) return (regs.b ? 0:1); else return regs.a;
}

