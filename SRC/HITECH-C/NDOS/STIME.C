/*** STIME Nestoreado ***/

#include "doscodes.h"
#include "asm.h"

typedef struct {
	int hour;
	int minute;
	int second;
} time;

int stime (time * tm)
{
	regset8 regs;
	regs.h = tm->hour;
	regs.l = tm->minute;
	regs.d = tm->second;
	doscall (_STIME, &regs);
	return (regs.a!=0);
}
