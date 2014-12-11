/*** FILEATT - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef fileatt

/* newatt = new attributos byte (set) o -1 (get only) */
/* fh = -1 if a filename is specified in "file" */

int fileatt (char* file, fhandle fh, int newatt)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	regs8->a = (uchar) (newatt<0 ? 0 : 1);
	regs8->l = (uchar) newatt;
	regs8->b = (uchar) fh;
	regs.de = (uint) file;
	doscall ((fh<0 ? _ATTR : _HATTR), &regs);
	return regs8->l;
}


