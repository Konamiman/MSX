/*** FPRINTF Nestoreado ***/

#include "asm.h"
#include "doscodes.h"

int nfprintf (fhandle fh, char* f, int a)
{
	return (_doprnes(fh, 0, f, &a));
}

