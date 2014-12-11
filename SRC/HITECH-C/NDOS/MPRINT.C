/* MPRINT - By Konami Man, 2-2001 */

#include "ndos.h"

#undef mprint

void mprint(char* str, ...)
{

	char* pnt = &str;
	do
	{
		print(str);
		pnt += sizeof(char*);
		str = *(unsigned int*)pnt;
	} while (str);
}

