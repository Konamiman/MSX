/*** FFIND - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef ffind

typedef struct {
	char  alwaysff;
	char  fname[13];
	char  attrib; /* En realidad es del tipo "flags" */
	uint  time;
	uint  date;
	uint  startclus;
	ulong fsize;
	uchar drive;
	char  internal[38];
} fib;

int ffind (char* path, int attrib, fib* fileinfo, int which)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs.de = (uint) path;
	regs8->b = (uchar) attrib;
	regs.ix = (uint) fileinfo;
	doscall (which?_FNEXT:_FFIRST, &regs);
	return regs.a;
}

