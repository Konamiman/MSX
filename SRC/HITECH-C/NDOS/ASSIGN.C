/*** ASSIGN - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef assign

/*
phydrv!=0, logdrv!=0 -> Asigna logdrv a phydrv
phydrv=0, logdrv!=0 -> Cancela la asignacion de logdrv
phydrv=0, logdrv=0 -> Cancela todas las asignaciones
phydrv=&HFF, logdrv!=0 -> Devuelve asignacion de logdrv

Devuelve error (si >8) o unidad (si >0) o 0
*/

int assign(int logdrv, int phydrv)
{
	regset8 regs;
	regs.b = (uchar) logdrv;
	regs.d = (uchar) phydrv;
	doscall (_ASSIGN, &regs);
	if (regs.a) return regs.a;
	if (phydrv==0xFF) return regs.d; else return 0;
}

