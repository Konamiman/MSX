/*** GETC - By Konami Man, 2-2001 ***/

#include "ndos.h"
#include "doscodes.h"
#include "nasm.h"

#undef ngetc

int ngetc(int modo)
{
	regset reg;
	if(modo&NOWAIT)
	{
		doscall(_CONST,&reg);
		if (!reg.a) return 0;
	}
	doscall(modo&NOECHO?_INNOE:_CONIN,&reg);
	return reg.a;
}
