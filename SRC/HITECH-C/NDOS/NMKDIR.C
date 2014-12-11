/* MKDIR - By Konami Man, 2-2001 */

#include "ndos.h"
#include "doscodes.h"

int nmkdir(char* name)
{
	int errcode;
	ncreate(name, 0, A_DIR|A_NEW);
	errcode = geterr();
	if (errcode!=_FILEX) return errcode;
	if (getfatt(name) & A_DIR)
		return _DIRX;
	else
		return _FILEX;
}

