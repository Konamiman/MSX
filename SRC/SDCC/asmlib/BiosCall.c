#include "asm.h"

void BiosCall(uint address, Z80_registers* regs, register_usage outRegistersDetail)
{
    regs->Bytes.IYh = *((byte*)0xFCC1);
    regs->Words.IX = address;
    AsmCall(0x001C,regs,REGS_ALL, outRegistersDetail);
}
