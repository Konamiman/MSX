/* Note: see sha1.c for implementation notes and the copyright stuff */

#ifndef _SHA_H_
#define _SHA_H_ 1

#ifndef byte
#define byte unsigned char
#endif

/* The structure for storing SHS info */

typedef struct 
{
	unsigned long digest[ 5 ];            /* Message digest */
	unsigned long countLo, countHi;       /* 64-bit bit count */
	unsigned long thedata[ 16 ];             /* SHS data buffer */
} SHA_CTX;

/* Message digest functions */

void SHAInit(SHA_CTX *);
void SHAUpdate(SHA_CTX *, unsigned char *buffer, unsigned long count);
void SHAFinal(unsigned char *output, SHA_CTX *);

#endif /* end _SHA_H_ */
