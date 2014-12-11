/* NASM.H
   C routines to perform machine code routines call
   By Konami Man, 2-2001
*/

#ifndef ASM_H
#define ASM_H

#ifndef uint
#define uint unsigned int
#endif
#ifndef uchar
#define uchar unsigned char
#endif
#ifndef ulong
#define ulong unsigned long
#endif
#define address char*

/* Register structures */

typedef struct{
	uchar f;
	uchar a;
	uint bc;
	uint de;
	uint hl;
	uint ix;
	uint iy;
} regset;

typedef struct{
	uchar f;
	uchar a;
	uchar c;
	uchar b;
	uchar e;
	uchar d;
	uchar l;
	uchar h;
	uchar ixl;
	uchar ixh;
	uchar iyl;
	uchar iyh;
} regset8;

#define high(r) ((r & 0xFF00) >> 8)
#define low(r) (r & 0xFF)
#ifndef NULL
#define NULL 0
#endif

/*** Routines ***/

extern void asmcall (void *, regset *);
extern void doscall (uchar, regset *);
extern void bioscall (void *, regset *);
extern void subcall (void *, regset *);
extern void extcall (uchar, uchar, regset *);

#endif
