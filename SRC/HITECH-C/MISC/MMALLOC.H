/* MMALLOC: Rutinas para memoria dinamica */

#ifndef _MMALLOC_H_
#define _MMALLOC_H_

typedef struct
{
	unsigned char segment;
	unsigned int address;
} mblock;

int InitMem();
void FinishMem();
int mmalloc(mblock*);
void mmfree(mblock*);
int GetSegP2();
void SetSegP2(int);
char* GetSegInfo();

#endif
