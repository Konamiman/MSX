/*
SHA1 library code for Z80/SDCC
Adapted by Konamiman 5/2010

Compilation command:

sdcc -mz80 -c --disable-warning 196 hmac-sha1.c

(depends on the sha1 library)

*/


/* hmac-sha1.c -- hashed message authentication codes
   Copyright (C) 2005, 2006 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

/* Written by Simon Josefsson.  */

void memxor (void* dest, void* src, int n)
{
    char* d=dest;
    char* s=src;

  for (; n > 0; n--)
    *d++ ^= *s++;
}

#define IPAD_BYTE 0x36
#define OPAD_BYTE 0x5c
#define SHA1_BLOCKSIZE 64

#include "sha1.h"
#include <string.h>

  SHA_CTX inner;
  SHA_CTX outer;
  SHA_CTX keyhash;
  char optkeybuf[20];
  char block[SHA1_BLOCKSIZE];
  char innerhash[20];


void hmac_sha1 (const void *key, int keylen, const void *in, int inlen, void *resbuf)
{
  /* Reduce the key's size, so that it becomes <= 64 bytes large.  */

  if (keylen > SHA1_BLOCKSIZE)
    {
      SHAInit(&keyhash);
      SHAUpdate(&keyhash, key, keylen);
      SHAFinal(optkeybuf, &keyhash);

      key = optkeybuf;
      keylen = 20;
    }

  /* Compute INNERHASH from KEY and IN.  */

  memset(block, IPAD_BYTE, SHA1_BLOCKSIZE);
  memxor(block, key, keylen);

  SHAInit(&inner);
  SHAUpdate(&inner, block, SHA1_BLOCKSIZE);
  SHAUpdate(&inner, in, inlen);

  SHAFinal(innerhash, &inner);

  /* Compute result from KEY and INNERHASH.  */

  memset(block, OPAD_BYTE, SHA1_BLOCKSIZE);
  memxor(block, key, keylen);

  SHAInit(&outer);
  SHAUpdate(&outer, block, SHA1_BLOCKSIZE);
  SHAUpdate(&outer, innerhash, 20);

  SHAFinal(resbuf, &outer);
}
