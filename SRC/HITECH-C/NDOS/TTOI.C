/*** TTOI - By Konami Man, 2-2001 ***/

#include "ndos.h"

#undef ttoi

uint ttoi(time t)
{
	return ((t.hour<<11) + (t.minute<<5) + (t.second>>1));
}


