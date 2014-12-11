/*** GETLOGV - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef getlogv

/*
log = getlogv()
(log & 1)!=0 si A: disponible
(log & 2)!=0 si B: disponible
(log & 4)!=0 si C: disponible
(log & 8)!=0 si D: disponible
(log & 16)!=0 si E: disponible
(log & 32)!=0 si F: disponible
(log & 64)!=0 si G: disponible
(log & 128)!=0 si H: disponible
*/

int getlogv()
{
	regset regs;
	doscall (_LOGIN, &regs);
	return regs.hl;
}

