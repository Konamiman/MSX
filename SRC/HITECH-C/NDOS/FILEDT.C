/*** FILEDT - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef filedt

/* fhanlde = -1 si se especifica nombre de fichero en "file" */
/* modif = 1 para modificar fecha y/o hora */
/* t o d a NULL para no modificar o no consultar */

int filedt (char* file, fhandle fh, int modif, int* t, int* d)
{
	regset regs;
	regset8 * regs8 = (regset8 *)&regs;
	int told,dold;

	if(!modif || t==NULL || d==NULL)
	{
		regs.de = (uint) file;
		regs8->b = (uchar) fh;
		regs.a = 0;
		doscall((fh<0 ? _FTIME : _HFTIME), &regs);
		if (regs.a) return regs.a;
		told = regs.de;
		dold = regs.hl;
	}

	if(modif)
	{
		regs.de = (uint) file;
		regs8->b = (uchar) fh;
		regs.a = 1;
		if(t==NULL)
			regs.ix = told;
		else
			regs.ix = *t;
		if(d==NULL)
			regs.hl = dold;
		else
			regs.hl = *d;
		doscall((fh<0 ? _FTIME : _HFTIME), &regs);
	}
	else
	{
		if(t!=NULL) *t = told;
		if(d!=NULL) *d = dold;
	}
	return regs.a;
}

