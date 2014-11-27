/*-----------------------------------------------
    Base64 encoder/decoder for InterNestor Lite
    By Konami Man, 12/2004
  -----------------------------------------------*/

/* Note: This program is for DOS 2 only. */

/* Note: when compiling, ignore all the "function xxx must return value" and
"in function xxx unreferenced function argument yyy" warnings. */

#include "inl.h"
#include <stdio.h>

typedef byte FHandle;

#define SRC_BUFFER 0x8000
#define DEST_BUFFER 0x9000
#define BUF_SIZE 0x1000

byte DOSVersion() _naked;
FHandle OpenFile(char* name);
byte CloseFile(FHandle handle);
byte ReadWriteFile(FHandle handle, void* buffer, uint* size, byte doscode);
#define ReadFile(h,b,s) ReadWriteFile(h,b,s,0x48);
#define WriteFile(h,b,s) ReadWriteFile(h,b,s,0x49);
FHandle CreateFile(char* name);
byte GetPrevError() _naked;

#define DoB64(x) (argv[0][0]=='e' ? B64Encode(x) : B64Decode(x))


/* Main function */

int main(char** argv, int argc)
{
        byte ercode;
        byte FileHandleIN=0xFF;
        byte FileHandleOUT=0xFF;
        uint Pending;
        B64Info info;
        uint Cummulated; /* Can't use info.Cummulated, since it does not reset to zero at each source file read */

        puts("Base64 encoder/decoder for InterNestor Lite 1.0 using C functions\r\n");
        puts("By Konami Man, 12/2004\r\n\r\n");


        /* Check DOS version */
        
        if(DOSVersion()<2)
        {
                puts("*** This program requires MSX-DOS 2");
                return 0;
        }
        

	/* Initialize INL and check various conditions */

	if(INLInit()==0)
	{
		puts("*** INL is not installed.");
		return 0;
	}

	if(INLState(INLSTAT_QUERY)!=INLSTAT_ACTIVE)
        {
                puts("*** INL is paused.");
                return 0;
        }

        if(argc<3)
	{
		puts("Usage: c-b64 e|d <in-file> <out-file>");
		return 0;
	}
	
        argv[0][0] |= 32;    /* First argument ("e" or "d") to lower case */


	/* Open source file */
	
	FileHandleIN=OpenFile(argv[1]);
	if(FileHandleIN==255)
	{
	        return GetPrevError();
	}
	
	
	/* Create destination file */
	
	FileHandleOUT=CreateFile(argv[2]);
	if (FileHandleOUT==255)
	{
	        CloseFile(FileHandleIN);
	        return GetPrevError();
	}


        /* Main loop: process file in chunks of 4KBytes, which in turn
           are encoded in chunks of 512 bytes */
        
        puts("Processing... ");
        B64Init(76);
        
        while(1) {
        
        WaitInt();
        
        
        /* Read up to 4K from source file to source buffer */
        
        Pending=BUF_SIZE;
        ReadFile(FileHandleIN, SRC_BUFFER, &Pending);

        info.Src=(void*)SRC_BUFFER;
        info.Dest=(void*)DEST_BUFFER;
                
        if(Pending==0)
        {
		info.Final=1;
		info.Size=0;
		DoB64(&info);
		if(info.Size>0) WriteFile(FileHandleOUT, DEST_BUFFER, &info.Size);
		
                CloseFile(FileHandleIN);
                CloseFile(FileHandleOUT);
                puts("Done.");
                return 0;
        }
                
        
        /* Convert the read data, in chunks of 512 bytes */
        
        Cummulated=0;
	info.Final=0;
        
        while(Pending>0)
        {
                info.Size=(Pending>512 ? 512 : Pending);
                ercode=DoB64(&info);    /* Remember that this will update info.Src and info.Dest */
                if(ercode!=0)   /* Can happen only when decoding */
                {
                        puts("*** Error: illegal Base64 characters found.");
                        CloseFile(FileHandleIN);
                        CloseFile(FileHandleOUT);
                        return 0;
                }
                Cummulated+=info.Size;  /* Now info.Size is the size of the generated block */
                Pending-=(Pending>512 ? 512 : Pending);
        }
        
        
        /* Write the resulting data to the destination file */
        
        WriteFile(FileHandleOUT, DEST_BUFFER, &Cummulated);
        
        } /* Main loop end, now try to convert other 8K of the source file */
	
} /* End of main */


/***  Auxiliary functions  ***/

/*
Note: For functions that return a FHandle, the value 255 is returned in case of error;
GetPrevError() can then be used to obtain the error code.
All other functions except DOSVersion return an error code.
*/

byte DOSVersion() _naked
{
        _asm
        ld      c,#0x6F
        call    5
        ld      l,b
        _endasm;
}


FHandle OpenFile(char* name)
{
        _asm
	ld      e,4(ix)
	ld      d,5(ix)
	xor     a
	ld      c,#0x43
	call    5
	jr      z,OPF2
	ld      b,#255
OPF2:   ld      l,b
        _endasm;
}


byte CloseFile(FHandle handle)
{
        _asm
        ld      b,4(ix)
        ld      c,#0x45
        call    5
        ld      l,a
        _endasm;
}


byte ReadWriteFile(FHandle handle, void* buffer, uint* size, byte doscode)
{
        _asm
        ld      b,4(ix)
        ld      e,5(ix)
        ld      d,6(ix)
        ld      l,7(ix)
        ld      h,8(ix)
        push    hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      c,9(ix)
        call    5
        ex      de,hl
        pop     hl
        ld      (hl),e
        inc     hl
        ld      (hl),d
        ld      l,a
        _endasm;
}


FHandle CreateFile(char* name)
{
	_asm
	ld      e,4(ix)
	ld      d,5(ix)
	xor     a
	ld      bc,#0x44
	call    5
	jr      z,CRF2
	ld      b,#255
CRF2:   ld      l,b
	_endasm;
}


byte GetPrevError() _naked
{       
        _asm
        ld      c,#0x65
        call    5
        ld      l,b
        ret
        _endasm;
}
