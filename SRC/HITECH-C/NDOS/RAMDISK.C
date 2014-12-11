/*** RAMDISK - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"
#include "ndos.h"

#undef ramdisk

/* Tamanyo = 0 para destruir, -1 para consultar, otro para estab. (en K) */

int ramdisk(int size)
{
	regset8 regs;
	if (size<0) regs.b = 0xFF;
	else regs.b = (size>=0xFE*16 ? 0xFE : (size%16 ? (size>>4)+1 : size>>4));
	doscall (_RAMD, &regs);
	return regs.b*16;
}

