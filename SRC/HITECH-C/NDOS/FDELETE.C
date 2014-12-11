/*** FDELETE - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef fdelete

int fdelete(char* filename)
{
              regset regs;
              int errcode,attributes;
	      attributes=getfatt(filename);
	      errcode=geterr();
	      if (errcode) return errcode;
	      if (attributes & A_DIR) return _NOFIL;
	      regs.de = (uint) filename;
              doscall (_DELETE, &regs);
              return regs.a;
}

