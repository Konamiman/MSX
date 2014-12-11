/*** BUFFERS - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef buffers

/* Establece bufers (number>0) o consulta (number=0) */
/* Devuelve error (>64) o num. de bufers (<64) */

int buffers (int number)
{
	regset8 regs;
	regs.b = (uchar) number;
	doscall (_BUFFER, &regs);
	if (regs.a) return regs.a;
	else return regs.b;
}

