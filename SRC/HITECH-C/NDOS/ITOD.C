/*** ITOD - By Konami Man, 2-2001 ***/

#include "ndos.h"

#undef itod

date itod(uint i)
{
	date d;
	d.day = i & 0x001F;
	d.month =  (i & 0x01E0) >> 5;
	d.year = 1980+(i >> 9);
	d.wday = -1;
	return d;
}


