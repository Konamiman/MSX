/*** FGETC - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nfgetc

int nfgetc (fhandle fh)
{
	char c;
	if(!nread(fh, &c, 1)) return -1; else return (int)c;
}

