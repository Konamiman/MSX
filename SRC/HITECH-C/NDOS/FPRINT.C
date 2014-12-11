/*** FPRINT - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef fprint

int fprint (fhandle fh, char* string)
{
	int longitud = 0;
	char* buscafin = string;
	while(*buscafin++) longitud++;
	return nwrite(fh, string, longitud);
}


