#include "asm.h"

byte UnapiRead(unapi_code_block* codeBlock, uint address)
{
	Z80_registers regs;
	regs.Words.HL = address;
	AsmCall((uint)&(codeBlock->UnapiReadCode), &regs, REGS_MAIN, REGS_AF);
	return regs.Bytes.A;
}
