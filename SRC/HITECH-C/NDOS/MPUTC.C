/* MPUTC - By Konami Man, 2-2001 */

#include "ndos.h"

#undef mputc

void mputc(char c, ...)
{
	char* pnt = &c;
	do
	{
		nputc(c);
		pnt += sizeof(char*);
		c = *(unsigned char*)pnt;
	} while (c);
}

