#ifndef __HMAC_SHA1
#define __HMAC_SHA1

#include "sha1.h"
#include <string.h>

//* Generate the HMAC SHA1 digest of message "in" (whose length is "keylen"),
//  using the specified "key" (whose length is "inlen"),
//  and place the result in "resbuf"
void hmac_sha1(const void *key, int keylen, const void *in, int inlen, void *resbuf);

#endif