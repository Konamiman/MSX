/* Example of application using ASMLIB, the SDCC ASM interop library
   By Konamiman 2/2010
   
   This application displays the contents of the file specified at command line,
   much like the COMMAND.COM command TYPE, but replacing non-printable
   control characters into dots.
   
   Accessing the file and the screen is done exclusively via MSX-DOS
   function calls, the C standard libraries are not used
   (the whole point of this example is showing how to interop with asm code).
   
   To keep things simple it works on MSX-DOS 2 only.
  
   Needs to be linked with ASM.LIB (available at www.konamiman.com)
   and crt0msx_msxdos_advanced.s (available at Avelino Herrera's page,
   http://msx.atlantes.org/index_en.html)
   
   Comments are welcome: konamiman@konamiman.com
*/

#include "asm.h"


#define Buffer ((byte*)0x8000)
#define BufferSize ((uint)16384)

#define CR 13
#define LF 10
#define TAB 8
#define BS 127

#define EOF  0xC7


/**********************************
 ***  MSX-DOS functions to use  ***
 **********************************/

//* Terminate program (compatible MSX-DOS 1)

#define _TERM0 0x00


//* Console output.
//  Input: E = Character to print

#define _CONOUT 0x02


//* Open file handle.
//  Input:  DE = File path
//          A = Open mode. b0 set => no write
//                         b1 set => no read
//                         b2 set => inheritable
//  Output: A = Error
//          B = File handle number

#define _OPEN 0x43


//* Close file handle.
//  Input:  B = File handle
//  Output: A = Error

#define _CLOSE 0x45


//* Read from file handle.
//  Input:  B = File handle
//          DE = Buffer address
//          HL = Number of bytes to read
//  Output: A = Error
//          HL = Number of bytes actually read

#define _READ 0x48


//* Terminate with error code.
//  Input: B = Error code

#define _TERM 0x62


//* Get MSX-DOS version number.
//  Output:  A = Error (always zero)
//           BC = MSX-DOS kernel version
//           DE = MSXDOS2.SYS version number

#define _DOSVER 0x6F


/*********************
 ***  Global data  ***
 *********************/

const char* strInfo=
    "Print file using SDCC ASMLIB 1.0\r\n"
    "By Konamiman, 2/2010\r\n"
    "\r\n"
    "Usage: c-type <filename>\r\n";

const char* strNeedsDOS2=
    "\r\n*** This program requires MSX-DOS 2 to run.\r\n";

byte fileHandle;
Z80_registers regs;


/*********************
 ***  Subroutines  ***
 *********************/

//* Print a character on the screen

void PrintChar(char theChar)
{
    regs.Bytes.E = theChar;
    DosCall(_CONOUT, &regs, REGS_MAIN, REGS_NONE);
}


//* Print a string on the screen

void PrintString(char* stringPointer)
{
    while(*stringPointer != NULL) {
        PrintChar(*stringPointer);
        stringPointer++;
    }
}


/**********************
 ***  MAIN program  ***
 **********************/
 
int main(char** argv, int argc)
{
    byte theChar;
    byte errorCode;
    uint chunkSize;
    int i;

    //* Print information, terminate if no parameters

    if(argc == 0) {
        PrintString(strInfo);
        DosCall(_TERM0, &regs, REGS_NONE, REGS_NONE);
    }
    
    //* Check the MSX-DOS version
    
    DosCall(_DOSVER, &regs, REGS_NONE, REGS_MAIN);
    if(regs.Bytes.B < 2) {
        PrintString(strNeedsDOS2);
        DosCall(_TERM0, &regs, REGS_NONE, REGS_NONE);
    }
    
    //* Try to open the file, terminate on error
    
    regs.UWords.DE = (uint)argv[0];
    regs.Bytes.A = 1;   //We will not write on the file
    DosCall(_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(!regs.Flags.Z) {
        regs.Bytes.B = regs.Bytes.A;
        DosCall(_TERM, &regs, REGS_MAIN, REGS_NONE);
    }
    
    fileHandle = regs.Bytes.B;
    
    //* Process the file
    
    while(1) {
        
        //* Read file chunk
        
        regs.Bytes.B = fileHandle;
        regs.UWords.DE = (uint)Buffer;
        regs.UWords.HL = BufferSize;
        DosCall(_READ, &regs, REGS_MAIN, REGS_MAIN);
        
        //* Break the loop on read error, or when no more data is available
        
        if(!regs.Flags.Z || regs.Words.HL == 0) {
            errorCode = (regs.Bytes.A == EOF ? 0 : regs.Bytes.A); //Ignore "End of file" error
            break;
        }
        
        //* Print all characters, replacing non-printable characters by a dot
        
        chunkSize = regs.UWords.HL;
        
        for(i=0; i<chunkSize; i++) {
            theChar = Buffer[i];
            if(theChar == CR || theChar == LF || theChar == TAB || (theChar >= 32 && theChar != BS)) {
                PrintChar(theChar);
            } else {
                PrintChar('.');
            }
        }
    }
    
    //* Error when reading the file, or no more data available:
    //  close the file and terminate program.

    regs.Bytes.B = fileHandle;
    DosCall(_CLOSE, &regs, REGS_MAIN, REGS_NONE);

    regs.Bytes.B = errorCode;
    DosCall(_TERM, &regs, REGS_MAIN, REGS_NONE);
    
    //* This point will never be reached, but main function needs a return code.
    
    return 0;
}
