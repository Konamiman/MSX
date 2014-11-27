/* Get URL 1.0
   By Konamiman 1/2011

   Compilation command line:
   
   sdcc --code-loc 0x170 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.lin asm.lib geturl.c
   hex2bin -e com geturl.ihx
   
   ASM.LIB, MSXCHAR.LIB and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com
*/

//#define DEBUG

#ifdef DEBUG
#define print(x) SendToStandardErr(x)
#define debug(x) {print("--- ");print(x);print("\r\n");}
#define debug2(x,y) {print("--- ");printf(x,y);print("\r\n");}
#define debug3(x,y,z) {print("--- ");printf(x,y,z);print("\r\n");}
#define debug4(x,y,z,a) {print("--- ");printf(x,y,z,a);print("\r\n");}
#define debug5(x,y,z,a,b) {print("--- ");printf(x,y,z,a,b);print("\r\n");}
#else
#define debug(x)
#define debug2(x,y)
#define debug3(x,y,z)
#define debug4(x,y,z,a)
#define debug5(x,y,z,a,b)
#endif


/* Includes */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

//These are available at www.konamiman.com
#include "asm.h"


/* Typedefs */

typedef unsigned char bool;

typedef struct {
    int Year;
    byte Month;
    byte Day;
    byte Hour;
    byte Minute;
    byte Second;
} date;


/* Defines */

#define false (0)
#define true (!false)
#define null ((void*)0)

#define STANDARD_OUTPUT (1)
#define STANDARD_ERROR (2)

#define _TERM0 0
#define _CONIN 1
#define _INNOE 8
#define _BUFIN 0x0A
#define _GDATE 0x2A
#define _GTIME 0x2C
#define _FFIRST 0x40
#define _OPEN 0x43
#define _CREATE 0x44
#define _CLOSE 0x45
#define _SEEK 0x4A
#define _READ 0x48
#define _WRITE 0x49
#define _IOCTL 0x4B
#define _PARSE 0x5B
#define _DEFAB 0x63
#define _DEFER 0x64
#define _EXPLAIN 0x66
#define _GENV 0x6B
#define _DOSVER 0x6F
#define _REDIR 0x70

#define _CTRLC 0x9E
#define _STOP 0x9F
#define _NOFIL 0x0D7
#define _EOF 0x0C7

#define PrintNewLine() print(strCRLF)

#define BUFFER_BASE ((void*)(0x8000))
#define FILE_BUFFER_LENGTH (4096)
#define MAX_LINE_LENGTH (256)

/* Strings */

const char* strTitle=
    "GETURL 1.0\r\n"
    "By Konamiman, 1/2011\r\n"
    "\r\n";
    
const char* strUsage=
    "Usage: geturl <file> <url name>\r\n"
    "\r\n"
    "Searches inside <file> a line that begins with <url name> enclosed\r\n"
    "in brackets (\"[ ]\"), then sends the remaining of the line to\r\n"
    "the standard output (the screen, or a file if redirection is used).\r\n"
    "\r\n"
    "Example:\r\n"
    "File named \"urls.txt\", containing the line \"[knm] http://www.konamiman.com\"\r\n"
    "The following is executed: \"geturl urls.txt knm\"\r\n"
    "Then the output is: \"http://www.konamiman.com\"\r\n"
    "\r\n"
    "You can use this together with HGET in order to easily download files\r\n"
    "from a list of URLs: \"geturl urls.txt name | hget con\"\r\n";
    
const char* strInvParam = "Invalid parameter";


    /* Global variables */

Z80_registers regs;
byte fileHandle = 0;
char* line;
char* lineName;
char* lineValue;
byte* fileBufferBase;
byte* fileBufferPointer;
int fileBufferRemaining;
int lineLength;

    /* Some handy code defines */

#define PrintNewLine() print(strCRLF)
#define SkipCharsWhile(pointer, ch) {while(*pointer == ch) pointer++;}
#define SkipCharsUntil(pointer, ch) {while(*pointer != ch) pointer++;}
#define ToLowerCase(ch) {ch |= 32;}
#define StringIs(a, b) (strcmpi(a,b)==0)
#define SendToStandardErr(str) SendStringToFileHandle(STANDARD_ERROR, str)
#define SendToStandardOut(str) SendStringToFileHandle(STANDARD_OUTPUT, str)


    /* Function prototypes */

void DisableAutoAbort();
void RestoreDefaultAbortRoutine();
void CheckDosVersion();
void TerminateWithCtrlCOrCtrlStop();
void TerminateWithDosErrorCode(char* message, byte errorCode);
char* ExplainDosErrorCode(byte code, char* destination);
void Terminate(const char* errorMessage);
byte OpenFile(char* path, char* errorMessage);
void CloseFile(byte handle);
int ReadFromFile(byte fileHandle, byte* destination, int length, char* errorMessage);
void SendStringToFileHandle(byte fileHandle, char* string);
void DoMainProcessing(char* fileName, char* urlName);
void ReadNextLine();
byte GetNextFileByte();
void EnsureThereIsFileDataAvailable();
char* ExtractLineName();
void ExtractLineValue(char* source);
int strcmpi(const char *a1, const char *a2);


int main(char** argv, int argc)
{
    fileBufferBase = BUFFER_BASE;
    line = fileBufferBase + FILE_BUFFER_LENGTH + 1;
    lineName = line + MAX_LINE_LENGTH;
    lineValue = lineName + MAX_LINE_LENGTH;
    
    SendToStandardErr(strTitle);

    if(argc == 0) {
        SendToStandardErr(strUsage);
        return 0;
    }
    
    CheckDosVersion();
    DisableAutoAbort();

    if(argc != 2) {
        Terminate(strInvParam);
    }

    DoMainProcessing(argv[0], argv[1]);

    Terminate(null);
    return 0;
}


/*
This routine prevents the program from terminating abruptely
when the user selects "Abort" after a disk error occurs,
or when the user presses Ctrl-C or Ctrl-STOP.

Instead, an error code will be returned to the code
that invoked the disk access operation, and this
will in turn cause the Terminate function to be invoked.

Pressing Ctrl-C or Ctrl-STOP is handled in a special way,
since there is no disk access routine to return control to
in these cases.
*/

void DisableAutoAbort() __naked
{
    __asm
    
    push    ix
    ld  de,#ABORT_CODE
    ld  c,#_DEFAB
    call    #5
    pop ix
    ret

    ;Input:  A = Primary error code
    ;        B = Secondary error code, 0 if none
    ;Output: A = Actual error code to use
ABORT_CODE:
    cp  #_CTRLC
    jp  z,_TerminateWithCtrlCOrCtrlStop
    cp  #_STOP
    jp  z,_TerminateWithCtrlCOrCtrlStop

    pop hl  ;This causes the program to continue instead of terminating
    
    ld  c,a ;Return the secondary error code if present,
    ld  a,b ;instead of the generic "Operation aborted" error
    or  a
    ret nz
    ld  a,c
    ret

    __endasm;
}


void RestoreDefaultAbortRoutine()
{
    regs.Words.DE = 0;
    DosCall(_DEFAB, &regs, REGS_MAIN, REGS_NONE);
}


void CheckDosVersion()
{
    DosCall(_DOSVER, &regs, REGS_NONE, REGS_MAIN);
    if(regs.Bytes.B < 2) {
        Terminate("This program is for MSX-DOS 2 only.");
    }
}


void TerminateWithCtrlCOrCtrlStop()
{
    Terminate("Operation cancelled");
}


void TerminateWithDosErrorCode(char* message, byte errorCode)
{
    char* pointer = fileBufferBase + 1024;

    debug2("DOS error code: %x\r\n", errorCode);
    strcpy(pointer, message);
    pointer += strlen(message);
    ExplainDosErrorCode(errorCode, pointer);
    Terminate(fileBufferBase + 1024);
}


char* ExplainDosErrorCode(byte code, char* destination)
{
    regs.Bytes.B = code;
    regs.Words.DE = (int)destination;
    DosCall(_EXPLAIN, &regs, REGS_MAIN, REGS_NONE);
    return destination;
}


void Terminate(const char* errorMessage)
{
    if(errorMessage != NULL) {
        sprintf(fileBufferBase, "\r\x1BK*** %s\r\n", errorMessage);
        SendToStandardErr(fileBufferBase);
    }
    
    RestoreDefaultAbortRoutine();
    if(fileHandle != 0) {
        CloseFile(fileHandle);
    }
    
    DosCall(_TERM0, &regs, REGS_NONE, REGS_NONE);
}


byte OpenFile(char* path, char* errorMessage)
{
    regs.Bytes.A = 0;
    regs.Bytes.B = 0;
    regs.Words.DE = (int)path;
    DosCall(_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode(errorMessage, regs.Bytes.A);
    }
    return regs.Bytes.B;
}


void CloseFile(byte handle)
{
    regs.Bytes.B = handle;
    DosCall(_CLOSE, &regs, REGS_MAIN, REGS_AF);
}


int ReadFromFile(byte fileHandle, byte* destination, int length, char* errorMessage)
{
    regs.Bytes.B = fileHandle;
    regs.Words.DE = (int)destination;
    regs.Words.HL = length;
    DosCall(_READ, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0 && regs.Bytes.A != _EOF) {
        TerminateWithDosErrorCode(errorMessage, regs.Bytes.A);
    }
    return regs.Words.HL;
}


void SendStringToFileHandle(byte fileHandle, char* string)
{
    regs.Bytes.B = fileHandle;
    regs.Words.DE = (int)string;
    regs.Words.HL = strlen(string);
    DosCall(_WRITE, &regs, REGS_MAIN, REGS_NONE);
}


void DoMainProcessing(char* fileName, char* urlName)
{
    char* bracketEndPointer;
    fileBufferRemaining = 0;

    debug3("DoMain, filename: %s, urlname: %s\r\n", fileName, urlName);

    fileHandle = OpenFile(fileName, "Error when opening file: ");
    
    while(true) {
        ReadNextLine();
        debug2("line: %s\r\n", line);
        if(line[0] == '[') {
            bracketEndPointer = ExtractLineName();
            debug3("linename: %s, bracketendpointer: %x\r\n", lineName, bracketEndPointer);
            if(bracketEndPointer != null && StringIs(lineName, urlName)) {
                ExtractLineValue(bracketEndPointer + 1);
                SendToStandardOut(lineValue);
                return;
            }
        }
    }
}


void ReadNextLine()
{
    byte nextChar;
    char* pointer = line;
    lineLength = 0;
    
    while(true) {
        nextChar = GetNextFileByte();
        if(nextChar == 0x1A) {
            Terminate("Name not found in the file");
        } else if(nextChar == 10) {
            continue;
        }
        *pointer = nextChar;
        
        if(nextChar == 13) {
            *pointer = 0;
            return;
        }
        
        lineLength++;
        if(lineLength > MAX_LINE_LENGTH) {
            Terminate("File line too long");
        }
        pointer++;
    }
}


byte GetNextFileByte()
{
    EnsureThereIsFileDataAvailable();
    fileBufferRemaining--;
    return *fileBufferPointer++;
}


void EnsureThereIsFileDataAvailable()
{
    if(fileBufferRemaining == 0) {
        fileBufferRemaining = ReadFromFile(fileHandle, fileBufferBase, FILE_BUFFER_LENGTH, "Error when reading file: ");
        debug2("Got %i bytes from file\r\n", fileBufferRemaining);
        fileBufferPointer = fileBufferBase;
        if(fileBufferRemaining != FILE_BUFFER_LENGTH) {
            fileBufferBase[fileBufferRemaining] = 0x1A;
        }
        debug2("From file: %s\r\n", fileBufferPointer);
    }
}


char* ExtractLineName()
{
    char* srcPointer = line + 1;
    char* dstPointer = lineName;
    
    while(*srcPointer != ']') {
        if(*dstPointer == 13) {
            debug("Incomplete line!");
            return null;
        }
        *dstPointer++ = *srcPointer++;
    }
    *dstPointer = '\0';
    return srcPointer + 1;
}


void ExtractLineValue(char* source)
{
    char* pointer = lineValue;
    SkipCharsWhile(source, ' ');
    while(*pointer++ = *source++);
    pointer[-1] = 13;
    pointer[0] = 10;
    pointer[1] = 0;
}


int strcmpi(const char *a1, const char *a2) {
	char c1, c2;
	/* Want both assignments to happen but a 0 in both to quit, so it's | not || */
	while((c1=*a1) | (c2=*a2)) {
		if (!c1 || !c2 || /* Unneccesary? */
			(islower(c1) ? toupper(c1) : c1) != (islower(c2) ? toupper(c2) : c2))
			return (c1 - c2);
		a1++;
		a2++;
	}
	return 0;
}
