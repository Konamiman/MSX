/*
SHA1 library code for Z80/SDCC
Adapted by Konamiman 5/2010

This code is taken from here: http://www.di-mgt.com.au/src/sha1.c.txt
Changes I have made:

- Embedded sha1.h moved to its own file. golbal.h is still here.
- All the calculation macros have been converted to functions.
  Otherwise the resulting code is a monster that exceeds the 64K once compiled.
- Function SHSTransform substituted for another one much shorter,
  taken from here: http://tomoyo.sourceforge.jp/cgi-bin/lxr/source/lib/sha1.c
- longReverse function rewritten. The original function does not work on
  some values, I don't know if due to a bug on SDCC or to Z80 itself.
- Endianness tests removed.
- main() is disabled.

Compilation command:

sdcc -mz80 -c sha1.c

*/



/* sha1.c : Implementation of the Secure Hash Algorithm */

/* SHA: NIST's Secure Hash Algorithm */

/*	This version written November 2000 by David Ireland of 
	DI Management Services Pty Limited <code@di-mgt.com.au>

	Adapted from code in the Python Cryptography Toolkit, 
	version 1.0.0 by A.M. Kuchling 1995.
*/

/* AM Kuchling's posting:- 
   Based on SHA code originally posted to sci.crypt by Peter Gutmann
   in message <30ajo5$oe8@ccu2.auckland.ac.nz>.
   Modified to test for endianness on creation of SHA objects by AMK.
   Also, the original specification of SHA was found to have a weakness
   by NSA/NIST.  This code implements the fixed version of SHA.
*/

/* Here's the first paragraph of Peter Gutmann's posting:
   
The following is my SHA (FIPS 180) code updated to allow use of the "fixed"
SHA, thanks to Jim Gillogly and an anonymous contributor for the information on
what's changed in the new version.  The fix is a simple change which involves
adding a single rotate in the initial expansion function.  It is unknown
whether this is an optimal solution to the problem which was discovered in the
SHA or whether it's simply a bandaid which fixes the problem with a minimum of
effort (for example the reengineering of a great many Capstone chips).
*/

#include <stdio.h>
#include <string.h>
#include "sha1.h"

/* global.h */

#ifndef _GLOBAL_H_
#define _GLOBAL_H_ 1

/* POINTER defines a generic pointer type */
typedef unsigned char *POINTER;

/* UINT4 defines a four byte word */
typedef unsigned long UINT4;

/* BYTE defines a unsigned character */
typedef unsigned char BYTE;

#ifndef TRUE
  #define FALSE	0
  #define TRUE	( !FALSE )
#endif /* TRUE */

#endif /* end _GLOBAL_H_ */

static void SHAtoByte(BYTE *output, UINT4 *input, unsigned int len);

/* The SHS block size and message digest sizes, in bytes */

#define SHS_DATASIZE    64
#define SHS_DIGESTSIZE  20

#define safe_memcpy(x,y,n) if((n)>0) {memcpy(x,y,n);}

/* The SHS f()-functions.  The f1 and f3 functions can be optimized to
   save one boolean operation each - thanks to Rich Schroeppel,
   rcs@cs.arizona.edu for discovering this */

/*#define f1(x,y,z) ( ( x & y ) | ( ~x & z ) )          // Rounds  0-19 */
//#define f1(x,y,z)   ( z ^ ( x & ( y ^ z ) ) )           /* Rounds  0-19 */
//#define f2(x,y,z)   ( x ^ y ^ z )                       /* Rounds 20-39 */
/*#define f3(x,y,z) ( ( x & y ) | ( x & z ) | ( y & z ) )   // Rounds 40-59 */
//#define f3(x,y,z)   ( ( x & y ) | ( z & ( x | y ) ) )   /* Rounds 40-59 */
//#define f4(x,y,z)   ( x ^ y ^ z )                       /* Rounds 60-79 */

UINT4 f1(UINT4 x, UINT4 y, UINT4 z) {return ( z ^ ( x & ( y ^ z ) ) ) ;}
UINT4 f2(UINT4 x, UINT4 y, UINT4 z) {return ( x ^ y ^ z ) ;}
UINT4 f3(UINT4 x, UINT4 y, UINT4 z) {return ( ( x & y ) | ( z & ( x | y ) ) ) ;}
//UINT4 f4(UINT4 x, UINT4 y, UINT4 z) {return ( x ^ y ^ z ) ;}


/* The SHS Mysterious Constants */

#define K1  0x5A827999                                 /* Rounds  0-19 */
#define K2  0x6ED9EBA1                                 /* Rounds 20-39 */
#define K3  0x8F1BBCDC                                 /* Rounds 40-59 */
#define K4  0xCA62C1D6                                 /* Rounds 60-79 */

/* SHS initial values */

#define h0init  0x67452301
#define h1init  0xEFCDAB89
#define h2init  0x98BADCFE
#define h3init  0x10325476
#define h4init  0xC3D2E1F0

/* Note that it may be necessary to add parentheses to these macros if they
   are to be called with expressions as arguments */
/* 32-bit rotate left - kludged with shifts */

//#define ROTL(n,X)  ( ( ( X ) << n ) | ( ( X ) >> ( 32 - n ) ) )
UINT4 ROTL(int n, UINT4 X)  {return ( ( ( X ) << n ) | ( ( X ) >> ( 32 - n ) ) );}


/* The initial expanding function.  The hash function is defined over an
   80-UINT2 expanded input array W, where the first 16 are copies of the input
   thedata, and the remaining 64 are defined by

        W[ i ] = W[ i - 16 ] ^ W[ i - 14 ] ^ W[ i - 8 ] ^ W[ i - 3 ]

   This implementation generates these values on the fly in a circular
   buffer - thanks to Colin Plumb, colin@nyx10.cs.du.edu for this
   optimization.

   The updated SHS changes the expanding function by adding a rotate of 1
   bit.  Thanks to Jim Gillogly, jim@rand.org, and an anonymous contributor
   for this information */

/*
#define expand(W,i) ( W[ i & 15 ] = ROTL( 1, ( W[ i & 15 ] ^ W[ (i - 14) & 15 ] ^ \
                                                 W[ (i - 8) & 15 ] ^ W[ (i - 3) & 15 ] ) ) )
*/

//UINT4 expand(UINT4* W, int i) {return ( W[ i & 15 ] = ROTL( 1, ( W[ i & 15 ] ^ W[ (i - 14) & 15 ] ^  W[ (i - 8) & 15 ] ^ W[ (i - 3) & 15 ] ) ) );}


/* The prototype SHS sub-round.  The fundamental sub-round is:

        a' = e + ROTL( 5, a ) + f( b, c, d ) + k + thedata;
        b' = a;
        c' = ROTL( 30, b );
        d' = c;
        e' = d;

   but this is implemented by unrolling the loop 5 times and renaming the
   variables ( e, a, b, c, d ) = ( a', b', c', d', e' ) each iteration.
   This code is then replicated 20 times for each of the 4 functions, using
   the next 20 values from the W[] array each time */

/*
#define subRound(a, b, c, d, e, f, k, thedata) \
    ( e += ROTL( 5, a ) + f( b, c, d ) + k + thedata, b = ROTL( 30, b ) )
*/

//void subRound(UINT4 a, UINT4* b, UINT4 c, UINT4 d, UINT4* e, UINT4(*f)(UINT4, UINT4, UINT4), UINT4 k, UINT4 thedata) {( *e += ROTL( 5, a ) + f( *b, c, d ) + k + thedata, *b = ROTL( 30, *b ) );}

/* Initialize the SHS values */

void SHAInit(SHA_CTX *shsInfo)
{
    //endianTest(&shsInfo->Endianness);
    /* Set the h-vars to their initial values */
    shsInfo->digest[ 0 ] = h0init;
    shsInfo->digest[ 1 ] = h1init;
    shsInfo->digest[ 2 ] = h2init;
    shsInfo->digest[ 3 ] = h3init;
    shsInfo->digest[ 4 ] = h4init;

    /* Initialise bit count */
    shsInfo->countLo = shsInfo->countHi = 0;
}


/* Perform the SHS transformation.  Note that this code, like MD5, seems to
   break some optimizing compilers due to the complexity of the expressions
   and the size of the basic block.  It may be necessary to split it into
   sections, e.g. based on the four subrounds

   Note that this corrupts the shsInfo->thedata area */

    #if 0

static void SHSTransform( UINT4 *digest, UINT4 *thedata )
{
    UINT4 A, B, C, D, E;     /* Local vars */
    UINT4 eData[ 16 ];       /* Expanded data */

    /* Set up first buffer and local thedata buffer */
    A = digest[ 0 ];
    B = digest[ 1 ];
    C = digest[ 2 ];
    D = digest[ 3 ];
    E = digest[ 4 ];
    safe_memcpy( (POINTER)eData, (POINTER)thedata, SHS_DATASIZE );

    /* Heavy mangling, in 4 sub-rounds of 20 interations each. */
    subRound( A, &B, C, D, &E, f1, K1, eData[  0 ] );
    subRound( E, &A, B, C, &D, f1, K1, eData[  1 ] );
    subRound( D, &E, A, B, &C, f1, K1, eData[  2 ] );
    subRound( C, &D, E, A, &B, f1, K1, eData[  3 ] );
    subRound( B, &C, D, E, &A, f1, K1, eData[  4 ] );
    subRound( A, &B, C, D, &E, f1, K1, eData[  5 ] );
    subRound( E, &A, B, C, &D, f1, K1, eData[  6 ] );
    subRound( D, &E, A, B, &C, f1, K1, eData[  7 ] );
    subRound( C, &D, E, A, &B, f1, K1, eData[  8 ] );
    subRound( B, &C, D, E, &A, f1, K1, eData[  9 ] );
    subRound( A, &B, C, D, &E, f1, K1, eData[ 10 ] );
    subRound( E, &A, B, C, &D, f1, K1, eData[ 11 ] );
    subRound( D, &E, A, B, &C, f1, K1, eData[ 12 ] );
    subRound( C, &D, E, A, &B, f1, K1, eData[ 13 ] );
    subRound( B, &C, D, E, &A, f1, K1, eData[ 14 ] );
    subRound( A, &B, C, D, &E, f1, K1, eData[ 15 ] );
    subRound( E, &A, B, C, &D, f1, K1, expand( eData, 16 ) );
    subRound( D, &E, A, B, &C, f1, K1, expand( eData, 17 ) );
    subRound( C, &D, E, A, &B, f1, K1, expand( eData, 18 ) );
    subRound( B, &C, D, E, &A, f1, K1, expand( eData, 19 ) );

    subRound( A, &B, C, D, &E, f2, K2, expand( eData, 20 ) );
    subRound( E, &A, B, C, &D, f2, K2, expand( eData, 21 ) );
    subRound( D, &E, A, B, &C, f2, K2, expand( eData, 22 ) );
    subRound( C, &D, E, A, &B, f2, K2, expand( eData, 23 ) );
    subRound( B, &C, D, E, &A, f2, K2, expand( eData, 24 ) );
    subRound( A, &B, C, D, &E, f2, K2, expand( eData, 25 ) );
    subRound( E, &A, B, C, &D, f2, K2, expand( eData, 26 ) );
    subRound( D, &E, A, B, &C, f2, K2, expand( eData, 27 ) );
    subRound( C, &D, E, A, &B, f2, K2, expand( eData, 28 ) );
    subRound( B, &C, D, E, &A, f2, K2, expand( eData, 29 ) );
    subRound( A, &B, C, D, &E, f2, K2, expand( eData, 30 ) );
    subRound( E, &A, B, C, &D, f2, K2, expand( eData, 31 ) );
    subRound( D, &E, A, B, &C, f2, K2, expand( eData, 32 ) );
    subRound( C, &D, E, A, &B, f2, K2, expand( eData, 33 ) );
    subRound( B, &C, D, E, &A, f2, K2, expand( eData, 34 ) );
    subRound( A, &B, C, D, &E, f2, K2, expand( eData, 35 ) );
    subRound( E, &A, B, C, &D, f2, K2, expand( eData, 36 ) );
    subRound( D, &E, A, B, &C, f2, K2, expand( eData, 37 ) );
    subRound( C, &D, E, A, &B, f2, K2, expand( eData, 38 ) );
    subRound( B, &C, D, E, &A, f2, K2, expand( eData, 39 ) );

    subRound( A, &B, C, D, &E, f3, K3, expand( eData, 40 ) );
    subRound( E, &A, B, C, &D, f3, K3, expand( eData, 41 ) );
    subRound( D, &E, A, B, &C, f3, K3, expand( eData, 42 ) );
    subRound( C, &D, E, A, &B, f3, K3, expand( eData, 43 ) );
    subRound( B, &C, D, E, &A, f3, K3, expand( eData, 44 ) );
    subRound( A, &B, C, D, &E, f3, K3, expand( eData, 45 ) );
    subRound( E, &A, B, C, &D, f3, K3, expand( eData, 46 ) );
    subRound( D, &E, A, B, &C, f3, K3, expand( eData, 47 ) );
    subRound( C, &D, E, A, &B, f3, K3, expand( eData, 48 ) );
    subRound( B, &C, D, E, &A, f3, K3, expand( eData, 49 ) );
    subRound( A, &B, C, D, &E, f3, K3, expand( eData, 50 ) );
    subRound( E, &A, B, C, &D, f3, K3, expand( eData, 51 ) );
    subRound( D, &E, A, B, &C, f3, K3, expand( eData, 52 ) );
    subRound( C, &D, E, A, &B, f3, K3, expand( eData, 53 ) );
    subRound( B, &C, D, E, &A, f3, K3, expand( eData, 54 ) );
    subRound( A, &B, C, D, &E, f3, K3, expand( eData, 55 ) );
    subRound( E, &A, B, C, &D, f3, K3, expand( eData, 56 ) );
    subRound( D, &E, A, B, &C, f3, K3, expand( eData, 57 ) );
    subRound( C, &D, E, A, &B, f3, K3, expand( eData, 58 ) );
    subRound( B, &C, D, E, &A, f3, K3, expand( eData, 59 ) );

    subRound( A, &B, C, D, &E, f4, K4, expand( eData, 60 ) );
    subRound( E, &A, B, C, &D, f4, K4, expand( eData, 61 ) );
    subRound( D, &E, A, B, &C, f4, K4, expand( eData, 62 ) );
    subRound( C, &D, E, A, &B, f4, K4, expand( eData, 63 ) );
    subRound( B, &C, D, E, &A, f4, K4, expand( eData, 64 ) );
    subRound( A, &B, C, D, &E, f4, K4, expand( eData, 65 ) );
    subRound( E, &A, B, C, &D, f4, K4, expand( eData, 66 ) );
    subRound( D, &E, A, B, &C, f4, K4, expand( eData, 67 ) );
    subRound( C, &D, E, A, &B, f4, K4, expand( eData, 68 ) );
    subRound( B, &C, D, E, &A, f4, K4, expand( eData, 69 ) );
    subRound( A, &B, C, D, &E, f4, K4, expand( eData, 70 ) );
    subRound( E, &A, B, C, &D, f4, K4, expand( eData, 71 ) );
    subRound( D, &E, A, B, &C, f4, K4, expand( eData, 72 ) );
    subRound( C, &D, E, A, &B, f4, K4, expand( eData, 73 ) );
    subRound( B, &C, D, E, &A, f4, K4, expand( eData, 74 ) );
    subRound( A, &B, C, D, &E, f4, K4, expand( eData, 75 ) );
    subRound( E, &A, B, C, &D, f4, K4, expand( eData, 76 ) );
    subRound( D, &E, A, B, &C, f4, K4, expand( eData, 77 ) );
    subRound( C, &D, E, A, &B, f4, K4, expand( eData, 78 ) );
    subRound( B, &C, D, E, &A, f4, K4, expand( eData, 79 ) );
    /* Build message digest */
    digest[ 0 ] += A;
    digest[ 1 ] += B;
    digest[ 2 ] += C;
    digest[ 3 ] += D;
    digest[ 4 ] += E;
}

    #else
    
    //Alternate (shorter) code for the transform, taken from  here:
    //http://tomoyo.sourceforge.jp/cgi-bin/lxr/source/lib/sha1.c
    
UINT4 a,b,c,d,e,t;
UINT4 W[ 80 ];       /* Expanded thedata */

static void longReverse(UINT4 *buffer, int byteCount);

//void sha_transform(__u32 *digest, const char *in, __u32 *W)
static void SHSTransform( UINT4 *digest, UINT4 *in )
{
        byte i;

        //for (i = 0; i < 16; i++)
        //        W[i] = be32_to_cpu(((const __be32 *)in)[i]);

    	memcpy(W, in, 64);

        for (i = 0; i < 64; i++)
                //W[i+16] = rol32(W[i+13] ^ W[i+8] ^ W[i+2] ^ W[i], 1);
		W[i+16] = ROTL(1, W[i+13] ^ W[i+8] ^ W[i+2] ^ W[i]);

        a = digest[0];
        b = digest[1];
        c = digest[2];
        d = digest[3];
        e = digest[4];

        for (i = 0; i < 20; i++) {
                t = f1(b, c, d) + K1 + ROTL(5, a) + e + W[i];
                e = d; d = c; c = ROTL(30, b); b = a; a = t;
        }

        for (; i < 40; i ++) {
                t = f2(b, c, d) + K2 + ROTL(5, a) + e + W[i];
                e = d; d = c; c = ROTL(30, b); b = a; a = t;
        }

        for (; i < 60; i ++) {
                t = f3(b, c, d) + K3 + ROTL(5, a) + e + W[i];
                e = d; d = c; c = ROTL(30, b); b = a; a = t;
        }

        for (; i < 80; i ++) {
                t = f2(b, c, d) + K4 + ROTL(5, a) + e + W[i];
                e = d; d = c; c = ROTL(30, b); b = a; a = t;
        }

        digest[0] += a;
        digest[1] += b;
        digest[2] += c;
        digest[3] += d;
        digest[4] += e;
}
    
    #endif

/* When run on a little-endian CPU we need to perform byte reversal on an
   array of long words. */

static void longReverse(UINT4 *lbuffer, int byteCount)
{
    byte* buffer=(byte*)lbuffer;
    byte t;
    while(byteCount>0) {
        t=buffer[0];
        buffer[0]=buffer[3];
        buffer[3]=t;
        t=buffer[1];
        buffer[1]=buffer[2];
        buffer[2]=t;
        buffer+=4;
        byteCount-=4;
    }

    //The original code DOES NOT WORK ON SDCC/Z80,
    //apparently for values >=0x80000000

    #if 0
    
    UINT4 value;

    if (Endianness==TRUE) return;
    byteCount = byteCount >> 2; // /= sizeof( UINT4 );
    while( byteCount-- )
        {
        value = *buffer;
        value = ( ( value & 0xFF00FF00 ) >> 8  ) | \
                ( ( value & 0x00FF00FF ) << 8 );
        *buffer++ = ( value << 16 ) | ( value >> 16 );
        }

    #endif
}

/* Update SHS for a block of thedata */

void SHAUpdate(SHA_CTX *shsInfo, BYTE *buffer, unsigned long count)
{
    UINT4 tmp;
    int dataCount;

    /* Update bitcount */
    
    tmp = shsInfo->countLo;
    shsInfo->countLo += ( ( UINT4 ) count << 3 ) ;
    if ( ( shsInfo->countLo = tmp + ( ( UINT4 ) count << 3 ) ) < tmp )
        shsInfo->countHi++;             /* Carry from low to high */
    shsInfo->countHi += count >> 29;

    /* Get count of bytes already in thedata */
    dataCount = ( int ) ( tmp >> 3 ) & 0x3F;

    /* Handle any leading odd-sized chunks */
    if( dataCount )
        {
        BYTE *p = ( BYTE * ) shsInfo->thedata + dataCount;

        dataCount = SHS_DATASIZE - dataCount;
        if( count < dataCount )
            {
            safe_memcpy( p, buffer, count );
            return;
            }
        safe_memcpy( p, buffer, dataCount );
        longReverse( shsInfo->thedata, SHS_DATASIZE);
        SHSTransform( shsInfo->digest, shsInfo->thedata );
        buffer += dataCount;
        count -= dataCount;
        }

    /* Process thedata in SHS_DATASIZE chunks */
    while( count >= SHS_DATASIZE )
        {
        safe_memcpy( (POINTER)shsInfo->thedata, (POINTER)buffer, SHS_DATASIZE );
        longReverse( shsInfo->thedata, SHS_DATASIZE);
        SHSTransform( shsInfo->digest, shsInfo->thedata );
        buffer += SHS_DATASIZE;
        count -= SHS_DATASIZE;
        }

    /* Handle any remaining bytes of thedata. */
    safe_memcpy( (POINTER)shsInfo->thedata, (POINTER)buffer, count );
}

/* Final wrapup - pad to SHS_DATASIZE-byte boundary with the bit pattern
   1 0* (64-bit count of bits processed, MSB-first) */

void SHAFinal(BYTE *output, SHA_CTX *shsInfo)
{
    int count;
    BYTE *dataPtr;

    /* Compute number of bytes mod 64 */
    count = ( int ) shsInfo->countLo;
    count = ( count >> 3 ) & 0x3F;

    /* Set the first char of padding to 0x80.  This is safe since there is
       always at least one byte free */
    dataPtr = ( BYTE * ) shsInfo->thedata + count;
    *dataPtr++ = 0x80;

    /* Bytes of padding needed to make 64 bytes */
    count = SHS_DATASIZE - 1 - count;

    /* Pad out to 56 mod 64 */
    if( count < 8 )
        {
        /* Two lots of padding:  Pad the first block to 64 bytes */
        memset( dataPtr, 0, count );
        longReverse( shsInfo->thedata, SHS_DATASIZE);
        SHSTransform( shsInfo->digest, shsInfo->thedata );

        /* Now fill the next block with 56 bytes */
        memset( (POINTER)shsInfo->thedata, 0, SHS_DATASIZE - 8 );
        }
    else
        /* Pad block to 56 bytes */
        memset( dataPtr, 0, count - 8 );

    /* Append length in bits and transform */
    shsInfo->thedata[ 14 ] = shsInfo->countHi;
    shsInfo->thedata[ 15 ] = shsInfo->countLo;

    longReverse( shsInfo->thedata, SHS_DATASIZE - 8);
    
    SHSTransform( shsInfo->digest, shsInfo->thedata );

	/* Output to an array of bytes */
	SHAtoByte(output, shsInfo->digest, SHS_DIGESTSIZE);

	/* Zeroise sensitive stuff */
	//memset((POINTER)shsInfo, 0, sizeof(shsInfo));
}

static void SHAtoByte(BYTE *output, UINT4 *input, unsigned int len)
{	/* Output SHA digest in byte array */
	unsigned int i, j;

	for(i = 0, j = 0; j < len; i++, j += 4) 
	{
        output[j+3] = (BYTE)( input[i]        & 0xff);
        output[j+2] = (BYTE)((input[i] >> 8 ) & 0xff);
        output[j+1] = (BYTE)((input[i] >> 16) & 0xff);
        output[j  ] = (BYTE)((input[i] >> 24) & 0xff);
	}
}


#if 0

unsigned char digest[20];
unsigned char message[3] = {'a', 'b', 'c' };
unsigned char *mess56 = 
	"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";

/* Correct solutions from FIPS PUB 180-1 */
char *dig1 = "A9993E36 4706816A BA3E2571 7850C26C 9CD0D89D";
char *dig2 = "84983E44 1C3BD26E BAAE4AA1 F95129E5 E54670F1";
char *dig3 = "34AA973C D4C4DAA4 F61EEB2B DBAD2731 6534016F";

/* Output should look like:-
 a9993e36 4706816a ba3e2571 7850c26c 9cd0d89d
 A9993E36 4706816A BA3E2571 7850C26C 9CD0D89D <= correct
 84983e44 1c3bd26e baae4aa1 f95129e5 e54670f1
 84983E44 1C3BD26E BAAE4AA1 F95129E5 E54670F1 <= correct
 34aa973c d4c4daa4 f61eeb2b dbad2731 6534016f
 34AA973C D4C4DAA4 F61EEB2B DBAD2731 6534016F <= correct
*/

main()
{
	SHA_CTX sha;
	int i;
	BYTE big[1000];

	SHAInit(&sha);
	SHAUpdate(&sha, message, 3);
	SHAFinal(digest, &sha);

	for (i = 0; i < 20; i++)
	{
		if ((i % 4) == 0) printf(" ");
		printf("%02x", digest[i]);
	}
	printf("\n");
	printf(" %s <= correct\n", dig1);

	SHAInit(&sha);
	SHAUpdate(&sha, mess56, 56);
	SHAFinal(digest, &sha);

	for (i = 0; i < 20; i++)
	{
		if ((i % 4) == 0) printf(" ");
		printf("%02x", digest[i]);
	}
	printf("\n");
	printf(" %s <= correct\n", dig2);

	/* Fill up big array */
	for (i = 0; i < 1000; i++)
		big[i] = 'a';

	SHAInit(&sha);
	/* Digest 1 million x 'a' */
	for (i = 0; i < 1000; i++)
		SHAUpdate(&sha, big, 1000);
	SHAFinal(digest, &sha);

	for (i = 0; i < 20; i++)
	{
		if ((i % 4) == 0) printf(" ");
		printf("%02x", digest[i]);
	}
	printf("\n");
	printf(" %s <= correct\n", dig3);

	return 0;
}

#endif

/* endian.c */

#if 0

void endianTest(int *endian_ness)
{
	if((*(unsigned short *) ("#S") >> 8) == '#')
	{
		/* printf("Big endian = no change\n"); */
		*endian_ness = !(0);
	}
	else
	{
		/* printf("Little endian = swap\n"); */
		*endian_ness = 0;
	}
}
#endif