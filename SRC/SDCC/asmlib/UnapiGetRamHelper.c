#include "asm.h"

void UnapiGetRamHelper(uint* jumpTableAddress, uint* mapperTableAddress)
{
	char* arg;

	Z80_registers regs;
	regs.Words.HL = 0;
	regs.Words.DE = 0x2222;
	regs.Bytes.A = 0xFF;

	AsmCall(0xFFCA, &regs, REGS_MAIN, REGS_MAIN);
	if(jumpTableAddress != NULL) {
		*jumpTableAddress=regs.Words.HL;
	}
	if(mapperTableAddress != NULL) {
		*mapperTableAddress=regs.Words.BC;
	}
}
