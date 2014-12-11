/* MEMC.C:
   C version of MEM.COM.
   Shows information about system memory.
   Needs DOS 2.
*/

#include "asm.h"
#include "doscodes.h"

#define terminate() doscall(0,NULL)

static void slot2str (char, char, char*);

regset regs;	    /* Register set for DOS calls */
int mappers=0;      /* Number of mappers found */
address vartable;   /* Address of the mapper variables table */

/*
--- Mapper information structure ---
*/
struct{
            uchar slot;              /* Mapper slot */
            uchar subslot;           /* Mapper subslot */
            uchar mtotal;            /* Total memory */
            uchar msystem;           /* System reserved memory */
            uchar muser;             /* User reserved memory */
            uchar mfree;             /* Free memory */
} mapper[16]; /* Up to 16 mappers supported */

char bufer[3]; /* For the slot printing routine */

main()
{

int i;
int total_all=0;    /* Agregated total, free and reserved memory for all mappers */
int free_all=0;
int reserved_all=0;

/***** Show initial message *****/

printf("\n\rMemorytestator (the judgement byte) - C version\n\r");
printf("By Konami Man, 27-12-2000\n\n\r");

/***** Checks for DOS 2 *****/

doscall (_DOSVER, &regs);
if (regs.bc < 0x0220)
{
   printf("Sorry, this program needs MSX-DOS 2.20 or higher.\n\r");
   terminate();
}

/***** Obtain mapper variables table via extended BIOS *****/

regs.a = 0;
extcall (4, 1, &regs);
if (regs.a == 0)
{
   printf("ERROR: No mapper support routines!\r\n");
   terminate();
}

vartable = (address) regs.hl;

/***** Obtain total, reserved and free memory for all mappers *****/

for (i=0; i<16; i++)
{
   mappers++;
   mapper[i].slot = (*(char*)vartable) & 3;
   mapper[i].subslot = ((*(char*)vartable++) & 12) >> 2;
   mapper[i].mtotal = (*(char*)vartable++);
   mapper[i].mfree = (*(char*)vartable++);
   mapper[i].msystem = (*(char*)vartable++);
   mapper[i].muser = (*(char*)vartable++);

   vartable = vartable+3;
   if ((*(char*)vartable) == 0) break;
}

/***** Show information for each mapper *****/

printf("Mappers found: %d\r\n\n",mappers);

printf("          Slot            Memory            Reserved            Free\n\r");
printf("          ----            ------            --------            ----\r\n\n");

for (i=0; i<mappers; i++)
{
   slot2str (mapper[i].slot, mapper[i].subslot, &bufer);
   printf("           %s            %5dK              %5dK          %5dK\n\r",
         bufer,
         mapper[i].mtotal*16,
         (mapper[i].muser + mapper[i].msystem)*16,
         (mapper[i].mfree)*16
         );
   total_all = total_all+(mapper[i].mtotal)*16; /* Agregated info calculation */
   free_all = free_all+(mapper[i].mfree)*16;
   reserved_all = reserved_all+(mapper[i].muser + mapper[i].msystem)*16;
}

printf("\n\r");     /* Agregated information print */
printf("Total:                    %5dK              %5dK          %5dK\n\n\r",
     total_all, reserved_all, free_all);

/***** Show information about RAM disk *****/

regs.bc = 0xFF00;
doscall(_RAMD, &regs);
if (high(regs.bc) == 0)
   printf ("RAM disk not installed\n\r");
else
   printf ("RAM disk size: %dK\n\r", high(regs.bc)*16);

/***** Show information about TPA size *****/

printf ("TPA end address: &H%x - TPA size is %dK\n\r",
        *(uint *)0x006,
        ((*(uint *)0x006)-256)/1024
       );

terminate();

} /* End of main() */


/***** This subroutine puts "  x" or "x-x" in the char buffer "bufer"
       depending on the given slot and subslot numbers *****/

static void slot2str (char slot, char subslot, char* bufer)
{
    if ((*(char *)(0xFCC1+slot)) & 128)  /* Is the slot expanded? */
     {
        sprintf (bufer, "%d-%d", slot, subslot);
     }
     else
     {
        sprintf (bufer, "  %d", slot);
     }
}
