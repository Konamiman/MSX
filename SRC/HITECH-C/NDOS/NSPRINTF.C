/*** NSPRINTF - SPRINTF using DOPRNES, by Konami Man, 2-2001 ***/

#include "nasm.h"
#include "doscodes.h"
#include "ndos.h"

#undef "nsprintf"


int nsprintf (char* memadd, char* f, int a)
{
	return (_doprnes(255, memadd, f, &a));
}


