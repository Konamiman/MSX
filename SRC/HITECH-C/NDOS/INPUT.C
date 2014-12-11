/*** INPUT - By Konami Man, 2-2001 ***/

#include "doscodes.h"
#include "nasm.h"

#undef input

int input (char* buffer, int size)
{
	int donesize;
	regset regs;
	buffer[0] = (char) size;
	regs.de = (uint) buffer;
	doscall (_BUFIN, &regs);
	buffer[2+(donesize = buffer[1])] = 0;
	return donesize;
}

