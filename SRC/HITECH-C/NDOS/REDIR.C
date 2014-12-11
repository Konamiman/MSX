/*** REDIR - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef redir

/* input y output: 0 para anular redir, 1 para restablecer, >1 para no modif. */
/* Devuelve: <4 para estado antes de la llamada, >4 para error */

int redir (int input, int output)
{
	regset8 regs;
	regs.a = 0;
	doscall (_REDIR, &regs);

	if (!(input>1 && output>1))
	{
		if (input<2)  regs.b = (regs.b & 2) | input;
		if (output<2) regs.b = (regs.b & 1) | output*2;
		regs.a = 1;
		doscall (_REDIR, &regs);
	}
	if (regs.a) return regs.a; else return regs.b;
}

