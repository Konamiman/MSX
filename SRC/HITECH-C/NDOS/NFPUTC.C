/*** FPUTC - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nfputc

#ifndef EOF
#define EOF 0x1A
#endif

int nfputc (fhandle fh, char c)
{
	if(!nwrite(fh, &c, 1)) return -1; else return c;
}

