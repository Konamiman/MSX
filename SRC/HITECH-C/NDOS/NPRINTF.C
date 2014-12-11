/*** PRINTF Nestoreado ***/

#include "asm.h"
#include "doscodes.h"

int nprintf (char* f, int a)
{
	return (_doprnes(STDOUT, 0, f, &a));
}

