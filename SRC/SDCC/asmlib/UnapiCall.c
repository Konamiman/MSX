#include "asm.h"

void UnapiCall(unapi_code_block* codeBlock, byte functionNumber, Z80_registers* registers, register_usage inRegistersDetail, register_usage outRegistersDetail)
{
	registers->Bytes.A = functionNumber;
	AsmCall((uint)&(codeBlock->UnapiCallCode), registers, inRegistersDetail == REGS_NONE ? REGS_AF : inRegistersDetail, outRegistersDetail);
}
