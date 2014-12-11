/*** ITOT - By Konami Man, 2-2001 ***/

#include "ndos.h"

#undef itot

time itot(uint i)
{
	time t;
	t.hour = i >> 11;
	t.minute = (i & 0x07E0) >> 5;
	t.second = (i & 0x001F) << 1;
	return t;
}


