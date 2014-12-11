/*** DTOI - By Konami Man, 2-2001 ***/

#include "ndos.h"

#undef dtoi

uint dtoi(date d)
{
	return (((d.year-1980)<<9) + (d.month<<5) + d.day);
}




