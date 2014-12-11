/*** RMDIR - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef nrmdir

int nrmdir (char* dirname)
{
	regset regs;
	int errcode,attributes;
	attributes=getfatt(dirname);
	errcode=geterr();
	if (errcode==_NOFIL) return _NODIR;
	if (errcode) return errcode;
	if (!(attributes & A_DIR)) return _NODIR;
	regs.de = (uint) dirname;
	doscall (_DELETE, &regs);
	return regs.a;
}

