#include "asm.h"

void UnapiParseCodeBlock(unapi_code_block* codeBlock, byte* slot, byte* segment, uint* address)
{
	if(codeBlock->UnapiCallCode[0] == 0xC3) {
		*address = *(uint*)&(codeBlock->UnapiCallCode[1]);
		return;
	}

	*address = *(uint*)&(codeBlock->UnapiCallCode[6]);
	*segment = codeBlock->UnapiCallCode[2];
	*slot = codeBlock->UnapiCallCode[3];
}
