#ifndef __BASE64
#define __BASE64


#ifndef byte
#define byte unsigned char
#endif

//* This must be executed before starting any encoding or decoding process.
//  If charsPerLine is not zero, a \r\n will be inserted after that many characters
//  (only used when encoding).
void Base64Init(byte charsPerLine);

//* Encode a chunk of data.
//  Returns the length of the encoded chunk.
//  "final" must be 0 for intermediate blocks, 1 for the final block.
uint Base64EncodeChunk(byte* source, byte* destination, uint length, byte final);

//* Decode a chunk of data.
//  Returns the length of the decoded chunk.
//  "final" must be 0 for intermediate blocks, 1 for the final block.
//  Error can be:
//  0: Ok
//  1: Invalid length in non final block
//  2: Invalid characteres found
uint Base64DecodeChunk(byte* source, byte* destination, uint length, byte final, byte* error);

#endif
