/* MSX trivial dropbox file operations manager 1.1
   By Konamiman 2/2014

   Compilation command line:
   
   sdcc --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.rel
          asm.lib dbfops.c
   hex2bin -e com dbfops.ihx
   
   ASM.LIB, SHA1.LIB, BASE64.LIB, MSXCHAR.LIB and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com
*/


/*
I wanted to implement automatic time zone adjustment
for the dates returned by the "dir" command...
but I just ran out of space (the application grows beyond 32K!) :-/
Anyway I have prepared a few supporting routines
in case I find a solution in the future.
Uncomment the define below to compile them.
*/
//#define ADJUST_TIMEZONE


//#define DEBUG

#ifdef DEBUG
#define debug(x) {print("--- ");print(x);PrintNewLine();}
#define debug2(x,y) {print("--- ");printf(x,y);PrintNewLine();}
#define debug3(x,y,z) {print("--- ");printf(x,y,z);PrintNewLine();}
#define debug4(x,y,z,a) {print("--- ");printf(x,y,z,a);PrintNewLine();}
#define debug5(x,y,z,a,b) {print("--- ");printf(x,y,z,a,b);PrintNewLine();}
#else
#define debug(x)
#define debug2(x,y)
#define debug3(x,y,z)
#define debug4(x,y,z,a)
#define debug5(x,y,z,a,b)
#endif


/* Includes */

#define malloc _malloc //override library functions
#define mfree _mfree
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#undef malloc
#undef mfree

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

typedef struct {
    byte remoteIP[4];
    uint remotePort;
    uint localPort;
    int userTimeout;
    byte flags;
} t_TcpConnectionParameters;

typedef struct {
    byte alwaysFF;
    char filename[13];
    byte attributes;
    byte timeOfModification[2];
    byte dateOfModification[2];
    unsigned int startCluster;
    unsigned long fileSize;
    byte logicalDrive;
    byte internal[38];
} t_FileInfoBlock;

typedef struct {
    bool isDir;
    long sizeBytes;
    char* size;
    char* modifiedDate;
    char* path;
} t_RemoteFileInfo;

typedef struct
{
    int year;
    byte month;
    byte day;
    byte hour;
    byte minute;
    byte second;
} t_Date;

/* Defines */

#define MALLOC_BASE ((void*)0x8000)

#define false (0)
#define true (!false)
#define null ((void*)0)

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
#define _DUP 0x47
#define _SEEK 0x4A
#define _READ 0x48
#define _WRITE 0x49
#define _IOCTL 0x4B
#define _HDELETE 0x52
#define _PARSE 0x5B
#define _TERM 0x62
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

#define STANDARD_OUTPUT 1
#define STANDARD_ERROR 2

#define SYSTIMER ((uint*)0xFC9E)

enum TcpipUnapiFunctions {
    UNAPI_GET_INFO = 0,
    TCPIP_GET_CAPAB = 1,
    TCPIP_NET_STATE = 3,
    TCPIP_DNS_Q = 6,
    TCPIP_DNS_S = 7,
    TCPIP_TCP_OPEN = 13,
    TCPIP_TCP_CLOSE = 14,
    TCPIP_TCP_ABORT = 15,
    TCPIP_TCP_STATE = 16,
    TCPIP_TCP_SEND = 17,
    TCPIP_TCP_RCV = 18,
    TCPIP_WAIT = 29
};

enum TcpipErrorCodes {
    ERR_OK = 0,			    
    ERR_NOT_IMP,		
    ERR_NO_NETWORK,		
    ERR_NO_DATA,		
    ERR_INV_PARAM,		
    ERR_QUERY_EXISTS,	
    ERR_INV_IP,		    
    ERR_NO_DNS,		    
    ERR_DNS,		    
    ERR_NO_FREE_CONN,	
    ERR_CONN_EXISTS,	
    ERR_NO_CONN,		
    ERR_CONN_STATE,		
    ERR_BUFFER,		    
    ERR_LARGE_DGRAM,	
    ERR_INV_OPER
};

#define PrintNewLine() print(strCRLF)
#define LetTcpipBreathe() UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE)

#define TICKS_TO_WAIT (20*60)
#define SYSTIMER ((uint*)0xFC9E)
#define TCP_BUFFER_SIZE (1024)
#define TCPOUT_STEP_SIZE (512)
#define JSON_BUF_SIZE (4096)

typedef enum {
    JSON_NONE,
    JSON_DATA,
    JSON_OBJECT_START,
    JSON_OBJECT_END,
    JSON_ARRAY_START,
    JSON_ARRAY_END
} JsonType;

typedef enum {
    FILEOP_SINGLE_ARG,
    FILEOP_COPY_MOVE,
    FILEOP_REN
} FileopType;


//#define BK_PTR 0xBFFE

/* Strings */

const char* strTitle=
    "MSX trivial dropbox file operations manager 1.1\r\n"
    "By Konamiman, 2/2014\r\n"
    "\r\n";
    
const char* strUsage=
    "Usage: dbfops dir <path> [nlen=<max names length>] [show={files|dirs|all}]\r\n"
    "                         [format={full|simple|raw}] [s[earch]=<pattern>]\r\n"
    "       dbfops mkdir <directory path>\r\n"
    "       dbfops del <file or directory path>\r\n"
    "       dbfops move <old path> <new path>\r\n"
    "       dbfops copy <source path> <destination path>\r\n"
    "       dbfops ren <file or directory path> <new name>\r\n"
    "\r\n"
    "You can supply paths by using a text file (useful for very long paths).\r\n"
    "Use the syntax 'file:<path filename>' for this.\r\n"
    "\r\n"
    "Non-standard ASCII chars in received paths are converted to UTF8.\r\n"
    "Conversely, you can supply paths with non-standard ASCII char\r\n"
    "if you supply them in an UTF8 encoded file (with 'file:<path filename>'.)\r\n"
    "\r\n"
    "You can use the asterisk  '*' to represent spaces on remote paths.\r\n"
    "It also works as the fragment separator in the search pattern.\r\n"
    "\r\n"
    "Please read the user's manual for more details.\r\n";
    
const char* strInvParam = "Invalid parameter";
const char* strNoNetwork = "No network connection available";
const char* strInvJson = "Invalid JSON data received";
const char* strCRLF = "\r\n";
const char* strBadUsrFile = "Invalid user authorization file. Please run DBACC.COM with the \"auth\" parameter.";
const char* strErrorWritingFile = "Error when writing to file: ";
const char* strWritingFile = "Writing data to file... ";
const char* strOk = "Ok\r\n";
const char* strErrReadTemp = "Error when reading from temporary file: ";
const char* strInvalidTimeZone = "Invalid time zone (expected format: +hh:mm or -hh:mm)";

const char* strConsumerKey = "PutYourDropboxConsumerKeyHere";
const char* strConsumerSecret = "PutYourDropboxConsumerSecretHere";

/* Global variables */

Z80_registers regs;
unapi_code_block codeBlock;
t_TcpConnectionParameters* TcpConnectionParameters;
byte conn = 0;
int ticksWaited;
int sysTimerHold;
int remainingInputData = 0;
byte* inputDataPointer;
byte* TcpInputData;
#define TcpOutputData TcpInputData;
char** arguments;
int argumentsCount;
char* userAgent;
bool directoryChanged;
int emptyLineReaded;
long contentLength;
int isChunkedTransfer = false;
long currentChunkSize = 0;
byte* headerLine;
byte* responseStatus;
char* statusLine;
int responseStatusCode;
int responseStatusCodeFirstDigit;
char* headerTitle;
char* headerContents;
long receivedLength = 0;
bool requestingToken = false;
char* jsonPointer;
char* jsonUpperLimit;
byte jsonNestLevel;
JsonType jsonLastItemType;
char* dataDirectory;
char* token;
char* tokenSecret;
byte fileHandle = 0;
char* JsonBuffer;
char* remotePathBuffer;
char* remotePath;
byte* malloc_ptr;
int displayNameLen = 12;
byte standardOutputDuplicate;
byte standardErrorDuplicate;
bool outputIsRedirectedToFile;
char* dropboxUrl;
bool usingTempFile = false;
bool terminating = false;
int timeZoneMinutes = 0;
bool hasTimeZone = false;
bool isDir = false;
char apiUrl[256];
char apiContentUrl[256];
int apiPort;
int apiContentPort;
bool useApiContent;
enum {
    DIR_SHOW_FILES,
    DIR_SHOW_DIRS,
    DIR_SHOW_ALL,
} dirShowType = DIR_SHOW_ALL;
enum {
    DIR_FORMAT_SIMPLE,
    DIR_FORMAT_FULL,
    DIR_FORMAT_RAW
} dirFormatType = DIR_FORMAT_FULL;


    /* Some handy code defines */

#define PrintNewLine() print(strCRLF)
#define LetTcpipBreathe() UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE)
#define SkipCharsWhile(pointer, ch) {while(*pointer == ch) pointer++;}
#define SkipCharsUntil(pointer, ch) {while(*pointer != ch) pointer++;}
#define SkipLF() GetInputByte()
#define ToLowerCase(ch) {ch |= 32;}
#define StringIs(a, b) (strcmpi(a,b)==0)
#define CheckExpectedJsonType(real, expected) {if(real!=expected) Terminate(strInvJson);}


    /* Function prototypes */

char* PercentEncode(char* src, char* dest, byte encodingType);
void Terminate(const char* errorMessage);
void print(char* s);
void GenerateHttpRequest(bool useGet, char* resourceRequested, char* params, char* destination);
void InitializeTcpipUnapi();
void ResolveServerName();
void AbortIfEscIsPressed();
int EscIsPressed();
void OpenTcpConnection();
void CloseTcpConnection();
void SendTcpData(byte* data, int dataSize);
void EnsureThereIsTcpDataAvailable();
void EnsureTcpConnectionIsStillOpen();
void ReadAsMuchTcpDataAsPossible();
void DisableAutoAbort();
void RestoreDefaultAbortRoutine();
void CheckDosVersion();
char* GetDosVersionString(char* destination);
char* GetUnapiImplementationName(char* destination);
void ComposeUserAgentString();
void TerminateWithCtrlCOrCtrlStop();
int strcmpi(const char *a1, const char *a2);
void ReadResponseHeaders();
void ReadResponseStatus();
void ReadNextHeader();
void ProcessNextHeader();
void ProcessResponseStatus();
void TerminateWithHttpError();
byte GetInputByte();
void InitializeHttpVariables();
void ExtractHeaderTitleAndContents();
void DownloadHttpContents();
void DoDirectDatatransfer();
void DoChunkedDataTransfer();
void copy(byte* to, byte* from, int len);
void ResetTcpBuffer();
long GetNextChunkSize();
JsonType JsonInit(bool extractFirstItem);
bool JsonDataAvailable();
JsonType JsonGetNextItem(char* name, char* value);
void JsonExtractValue(char* destination, bool isString);
void JsonSkipWhitespaceCharsAndCommas();
void CheckJsonCharIs(char c);
void IncreaseJsonPointer();
void GetDataDirectory();
void GetDataFilePath(char* fileName, char* destination);
byte CreateFile(char* path, char* errorMessage);
void WriteToFile(byte handle, byte* data, int length, char* errorMessage);
void CloseFile(byte handle);
void TerminateWithDosErrorCode(char* message, byte errorCode);
char* ExplainDosErrorCode(byte code, char* destination);
byte OpenFile(char* path, char* errorMessage);
int ReadFromFile(byte fileHandle, byte* destination, int length, char* errorMessage);
void ReadTokenFromFile();
void ParseFileLine(byte** src, byte* dest, int maxLength);
void PrintSize(unsigned long size);
bool HasOnlyAsciiChars(char* string);
bool FileExists(char* path);
void minit();
void* malloc_core(unsigned int size);
void mfree(void* address);
void* malloc(unsigned int size);
void DoGetDirectory();
void ProcessRemoteDirectoryData(bool withSearch);
bool GetCurrentFileData(t_RemoteFileInfo* fileInfo, char* itemNameBuffer, char* itemContentBuffer);
void RewindFile(byte fileHandle);
void ReadRemotePath(char* source);
void DoCreateDirectory();
void ReplaceChars(char* string, char charSource, char charDestination);
void DoHttpTransaction(bool useGet, char* resourceName, char* params);
void OpenTempFilename();
void AppendSlashIfNecessary(char* string);
t_RemoteFileInfo* New_RemoteFileInfo();
void Delete_RemoteFileInfo(t_RemoteFileInfo* pointer);
void ShowFileInformation(t_RemoteFileInfo* fileInfo);
void ShowDirContentsInformation(t_RemoteFileInfo* fileInfo, char* itemNameBuffer, char* itemContentBuffer, bool isSearch);
bool PrintShortFileInformation(t_RemoteFileInfo* fileInfo);
char* AdjustString(char* name, int maxLen, bool skipToLastSlash, bool appendSlash);
bool StringIsTrue(char* string);
int StringStartsWith(const char* stringToCheck, const char* startingToken);
int strncmpi(const char *a1, const char *a2, unsigned size);
byte DuplicateFileHandle(byte fileHandle);
void RedirectOutputToStandardError();
void RestoreStandardOutput();
bool OutputIsRedirectedToFile();
void DoFileOperation(char* operationName, FileopType type);
void GetFilenamePart(char* source, char* destination);
void DeleteFile(byte fileHandle);
void PrintFileContents(byte fileHandle);
bool StringEndsWith(char* s, char c);
void SubstituteName(char* pathAndOldName, char* newName);
int IndexOf(char* s, char c);
int LastIndexOf(char* s, char c);
bool GetEnvironmentItem(char* name, char* value, int maxLen);
int ParseTimeZone(char* timeZoneString);
void DecreaseJsonNestLevel();
void CheckExactArgumentsCount(int count);
void CheckHasOnlyAsciiHars(char* string);
byte FourByteHexToUTF8(byte* string, byte* dest);
byte ParseNibble(char nibble);
void GetUrlsFromEnvironmentItems();
void ExtractUrlEnvironmentItem(char* itemName, char* urlDestination, int* portDestination);
char NibbleToHex(byte value);
void ByteToHex(byte value, char* buffer);


int main(char** argv, int argc)
{
    void* pointer;
    
    outputIsRedirectedToFile = OutputIsRedirectedToFile();
    standardOutputDuplicate = DuplicateFileHandle(STANDARD_OUTPUT);
    standardErrorDuplicate = DuplicateFileHandle(STANDARD_ERROR);
    
    if((argc > 0) && (StringIs(argv[0], "dir"))) {
        isDir = true;
        RedirectOutputToStandardError();
    }
    
    minit();
    TcpInputData = malloc(1024);
    debug2("TcpInputData: %x", TcpInputData);
    
    arguments = argv;
    argumentsCount = argc;

    print(strTitle);

    if(argumentsCount == 0) {
        print(strUsage);
        return 0;
    }
    
    CheckDosVersion();
    InitializeTcpipUnapi();
    DisableAutoAbort();
    ComposeUserAgentString();
    GetDataDirectory();
    GetUrlsFromEnvironmentItems();
    
    useApiContent = false;
    if(StringIs(arguments[0], "dir")) {
	DoGetDirectory();
    } else if(StringIs(arguments[0], "mkdir")) {
        CheckExactArgumentsCount(2);
    	DoFileOperation("create_folder", FILEOP_SINGLE_ARG);
    } else if(StringIs(arguments[0], "del")) {
    	DoFileOperation("delete", FILEOP_SINGLE_ARG);
    } else if(StringIs(arguments[0], "move")) {
    	DoFileOperation("move", FILEOP_COPY_MOVE);
    } else if(StringIs(arguments[0], "copy")) {
    	DoFileOperation("copy", FILEOP_COPY_MOVE);
    } else if(StringIs(arguments[0], "ren")) {
    	DoFileOperation("move", FILEOP_REN);
    } else {
        Terminate(strInvParam);
    }

    Terminate(null);
    return 0;
}


void GenerateHttpRequest(bool useGet, char* resourceRequested, char* params, char* destination)
{
    if(useGet) {
        sprintf(destination, 
            "GET %s?%s HTTP/1.1\r\n"
            "Host: api.dropbox.com\r\n"
            "User-Agent: %s\r\n"
            "Authorization: OAuth oauth_version=\"1.0\", oauth_signature_method=\"PLAINTEXT\", oauth_consumer_key=\"%s\", oauth_token=\"%s\", oauth_signature=\"%s&%s\"\r\n"
            "\r\n",
            resourceRequested,
            params,
            userAgent,
            strConsumerKey,
            token,
            strConsumerSecret,
            tokenSecret
        );
    } else {
        sprintf(destination, 
            "POST %s HTTP/1.1\r\n"
            "Host: api.dropbox.com\r\n"
            "Content-Length: %i\r\n"
            "Content-Type: application/x-www-form-urlencoded\r\n"
            "User-Agent: %s\r\n"
            "Authorization: OAuth oauth_version=\"1.0\", oauth_signature_method=\"PLAINTEXT\", oauth_consumer_key=\"%s\", oauth_token=\"%s\", oauth_signature=\"%s&%s\"\r\n"
            "\r\n"
            "%s\r\n",
            resourceRequested,
            strlen(params)+2,
            userAgent,
            strConsumerKey,
            token,
            strConsumerSecret,
            tokenSecret,
            params
        );
    }

    debug2("HTTP request:\r\n%s", destination);
}


//encodingType values:
//0: simple (nonsafe chars are encoded as '%'+hex value)
//1: standard (same as simple, but space is encoded as '+')
//2: double (simple over simple: nonsafe chars are encoded as '%25'+hex value)
//3: Simple, but '/' is preserved
char* PercentEncode(char* src, char* dest, byte encodingType)
{
    char value;

    while((value = *src) != '\0') {
        if(value==' ' && encodingType == 1) {
            *dest++ = '+';
        } else if(islower(value) || isupper(value) || isdigit(value) || value=='-' || value=='.' || value=='_' || value=='~') {
            *dest++ = value;
        } else if(value=='/' && encodingType == 3) {
            *dest++ = '/';
        } else {
            *dest++ = '%';
            if(encodingType == 2) {
                *dest++ = '2';
                *dest++ = '5';
            }
            ByteToHex(value, dest);
            dest += 2;
        }
        src++;
    }
    *dest = '\0';
    return dest+1;
}


void Terminate(const char* errorMessage)
{
    terminating = true;
    if(isDir) {
        RedirectOutputToStandardError();
    }

    if(errorMessage != NULL) {
        printf("\r\x1BK*** %s\r\n", errorMessage);
    }
    
    CloseTcpConnection();
    if(fileHandle != 0) {
        if(usingTempFile) {
#ifdef DEBUG
            CloseFile(fileHandle);
#else
            DeleteFile(fileHandle);
#endif
        } else {
            CloseFile(fileHandle);
        }
    }
    RestoreDefaultAbortRoutine();
    
    regs.Bytes.B = (errorMessage == NULL ? 0 : 1);
    DosCall(_TERM, &regs, REGS_MAIN, REGS_NONE);
}


void print(char* s) __naked
{
    __asm
    push    ix
    ld     ix,#4
    add ix,sp
    ld  l,(ix)
    ld  h,1(ix)
loop:
    ld  a,(hl)
    or  a
    jr  z,end
    ld  e,a
    ld  c,#2
    push    hl
    call    #5
    pop hl
    inc hl
    jr  loop
end:
    pop ix
    ret
    __endasm;    
}


void InitializeTcpipUnapi()
{
    int i;

    i = UnapiGetCount("TCP/IP");
    if(i==0) {
        Terminate("No TCP/IP UNAPI implementations found");
    }
    UnapiBuildCodeBlock(NULL, 1, &codeBlock);
    
    regs.Bytes.B = 1;
    UnapiCall(&codeBlock, TCPIP_GET_CAPAB, &regs, REGS_MAIN, REGS_MAIN);
    if((regs.Bytes.L & (1 << 3)) == 0) {
        Terminate("This TCP/IP implementation does not support active TCP connections.");
    }
    
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_MAIN);

    TcpConnectionParameters = malloc(sizeof(t_TcpConnectionParameters));
    TcpConnectionParameters->localPort = 0xFFFF;
    TcpConnectionParameters->userTimeout = 0;
    TcpConnectionParameters->flags = 0;
    debug2("TCP/IP UNAPI ok, %x", TcpConnectionParameters);
}


void ResolveServerName()
{
    char* Buffer = malloc(256);
    char* url = malloc(32);
    strcpy(url, useApiContent ? apiContentUrl : apiUrl);

    print("Resolving server name...");
    regs.Words.HL = (int)url;
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_DNS_Q, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == ERR_NO_NETWORK) {
        Terminate(strNoNetwork);
    } else if(regs.Bytes.A == ERR_NO_DNS) {
        Terminate("There are no DNS servers configured.");
    } else if(regs.Bytes.A == ERR_NOT_IMP) {
        Terminate("This TCP/IP UNAPI implementation does not support resolving host names.");
    } else if(regs.Bytes.A != (byte)ERR_OK) {
        sprintf(Buffer, "Unknown error when resolving the host name (code %i)", regs.Bytes.A);
        Terminate(Buffer);
    }
    
    do {
        AbortIfEscIsPressed();
        LetTcpipBreathe();
        regs.Bytes.B = 0;
        UnapiCall(&codeBlock, TCPIP_DNS_S, &regs, REGS_MAIN, REGS_MAIN);
    } while (regs.Bytes.A == 0 && regs.Bytes.B == 1);
    
    if(regs.Bytes.A != 0) {
        if(regs.Bytes.B == 2) {
            Terminate("DNS server failure");
        } else if(regs.Bytes.B == 3) {
            Terminate("Unknown host name");
        } else if(regs.Bytes.B == 5) {
            Terminate("DNS server refused the query");
        } else if(regs.Bytes.B == 16 || regs.Bytes.B == 17) {
            Terminate("DNS server did not reply");
        } else if(regs.Bytes.B == 19) {
            Terminate(strNoNetwork);
        } else if(regs.Bytes.B == 0) {
            Terminate("DNS query failed");
        } else {
            sprintf(Buffer, "Unknown error returned by DNS server (code %i)", regs.Bytes.B);
            Terminate(Buffer);
        }
    }
    
    TcpConnectionParameters->remoteIP[0] = regs.Bytes.L;
    TcpConnectionParameters->remoteIP[1] = regs.Bytes.H;
    TcpConnectionParameters->remoteIP[2] = regs.Bytes.E;
    TcpConnectionParameters->remoteIP[3] = regs.Bytes.D;

    TcpConnectionParameters->remotePort = useApiContent ? apiContentPort : apiPort;
    
    print(" Ok\r\n");
    mfree(Buffer);
}


void AbortIfEscIsPressed()
{
    if(EscIsPressed()) {
        PrintNewLine();
        Terminate("Operation cancelled.");
    }
}


int EscIsPressed()
{
    return (*((byte*)0xFBEC) & 4) == 0;
}


void OpenTcpConnection()
{
    char* Buffer = malloc(256);

    regs.Words.HL = (int)TcpConnectionParameters;
    UnapiCall(&codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == (byte)ERR_NO_FREE_CONN) {
        regs.Bytes.B = 0;
        UnapiCall(&codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_NONE);
        regs.Words.HL = (int)TcpConnectionParameters;
        UnapiCall(&codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    }
    
    if(regs.Bytes.A == (byte)ERR_NO_NETWORK) {
        Terminate(strNoNetwork);
    } else if(regs.Bytes.A != 0) {
        sprintf(Buffer, "Unexpected error when opening TCP connection (%i)", regs.Bytes.A);
        Terminate(Buffer);
    }
    conn = regs.Bytes.B;
    
    ticksWaited = 0;
    do {
        AbortIfEscIsPressed();
        sysTimerHold = *SYSTIMER;
        LetTcpipBreathe();
        while(*SYSTIMER == sysTimerHold);
        ticksWaited++;
        if(ticksWaited >= TICKS_TO_WAIT) {
            Terminate("Connection timeout");
        }
        regs.Bytes.B = conn;
        regs.Words.HL = 0;
        UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    } while((regs.Bytes.A) == 0 && (regs.Bytes.B != 4));
    
    if(regs.Bytes.A != 0) {
        Terminate("Could not establish a connection to the server");
    }
    
    mfree(Buffer);
}


void CloseTcpConnection()
{
    if(conn != 0) {
        regs.Bytes.B = conn;
        UnapiCall(&codeBlock, TCPIP_TCP_CLOSE, &regs, REGS_MAIN, REGS_NONE);
        conn = 0;
    }
}


void SendTcpData(byte* data, int dataSize)
{
    char* Buffer;

    do {
        do {
            regs.Bytes.B = conn;
            regs.Words.DE = (int)data;
            regs.Words.HL = dataSize > TCPOUT_STEP_SIZE ? TCPOUT_STEP_SIZE : dataSize;
            regs.Bytes.C = 1;
            UnapiCall(&codeBlock, TCPIP_TCP_SEND, &regs, REGS_MAIN, REGS_AF);
            if(regs.Bytes.A == ERR_BUFFER) {
                LetTcpipBreathe();
                regs.Bytes.A = ERR_BUFFER;
            }
        } while(regs.Bytes.A == ERR_BUFFER);
        dataSize -= TCPOUT_STEP_SIZE;
        data += regs.Words.HL;   //Unmodified since REGS_AF was used for output
    } while(dataSize > 0 && regs.Bytes.A == 0);
    
    if(regs.Bytes.A == ERR_NO_CONN) {
        Terminate("Connection lost while sending data");
    } else if(regs.Bytes.A != 0) {
        Buffer = malloc(256);
        sprintf(Buffer, "Unexpected error when sending TCP data (%i)", regs.Bytes.A);
        Terminate(Buffer);
    }
}


void EnsureThereIsTcpDataAvailable()
{
    ticksWaited = 0;

    while(remainingInputData == 0) {
        sysTimerHold = *SYSTIMER;
        LetTcpipBreathe();
        while(*SYSTIMER == sysTimerHold);
        ticksWaited++;
        if(ticksWaited >= TICKS_TO_WAIT) {
            Terminate("No more data received");
        }
        
        ReadAsMuchTcpDataAsPossible();
        if(remainingInputData == 0) {
            EnsureTcpConnectionIsStillOpen();
        }
    }
}


void EnsureTcpConnectionIsStillOpen()
{
    regs.Bytes.B = conn;
    regs.Words.HL = 0;
    UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0 || regs.Bytes.B != 4) {
        Terminate("Connection lost");
    }
}


void ReadAsMuchTcpDataAsPossible()
{
    char* Buffer;

    AbortIfEscIsPressed();
    regs.Bytes.B = conn;
    regs.Words.DE = (int)(TcpInputData);
    regs.Words.HL = TCP_BUFFER_SIZE;
    UnapiCall(&codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        Buffer = malloc(256);
        sprintf(Buffer, "Unexpected error when reading TCP data (%i)", regs.Bytes.A);
        Terminate(Buffer);
    }
    remainingInputData = regs.UWords.BC;
    inputDataPointer = TcpInputData;
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


char* GetDosVersionString(char* destination)
{
    DosCall(_DOSVER, &regs, REGS_NONE, REGS_MAIN);
    sprintf(destination, "%i.%i%i", regs.Bytes.B, (regs.Bytes.C >> 4) & 0xF, regs.Bytes.C & 0xF);
    return destination;
}


char* GetUnapiImplementationName(char* destination)
{
    byte readChar;
    byte versionMain;
    byte versionSec;
    uint nameAddress;
    char* pointer = destination;
    
    UnapiCall(&codeBlock, UNAPI_GET_INFO, &regs, REGS_NONE, REGS_MAIN);
    versionMain = regs.Bytes.B;
    versionSec = regs.Bytes.C;
    nameAddress = regs.UWords.HL;
    
    while(1) {
        readChar = UnapiRead(&codeBlock, nameAddress);
        if(readChar == 0) {
            break;
        }
        *pointer++ = readChar;
        nameAddress++;
    }
    
    sprintf(pointer, " v%u.%u", versionMain, versionSec);
    return destination;
}


void ComposeUserAgentString()
{
    char* pointer;
    debug("Composing user agent");
    userAgent = malloc(130);
    debug2("malloc 1: %x", userAgent);
    pointer = malloc(128);
    sprintf(userAgent, "MSX trivial dropbox/1.1 (MSX-DOS %s; TCP/IP UNAPI; %s)", GetDosVersionString(pointer), GetUnapiImplementationName(pointer + 16));
    mfree(pointer);
    debug2("User agent: %s", userAgent);
}


void TerminateWithCtrlCOrCtrlStop()
{
    Terminate("Operation cancelled");
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


void ReadResponseHeaders()
{
    headerLine = malloc(256);
    responseStatus = malloc(256);
    statusLine = malloc(256);

    emptyLineReaded = 0;
    
    ReadResponseStatus();
    
    while(!emptyLineReaded) {
        ReadNextHeader();
        ProcessNextHeader();
    }
    
    ProcessResponseStatus();
    
    mfree(statusLine);
    mfree(responseStatus);
    mfree(headerLine);
}


void ReadResponseStatus()
{
    char* pointer;
    ReadNextHeader();
    strcpy(statusLine, headerLine);
    pointer = statusLine;
    SkipCharsUntil(pointer, ' ');
    SkipCharsWhile(pointer, ' ');
    responseStatusCode = atoi(pointer);
    responseStatusCodeFirstDigit = (byte)*pointer - (byte)'0';
}


void ReadNextHeader()
{
    char* pointer;
    byte data;
    pointer = headerLine;

    data = GetInputByte();
    if(data == 13) {
        SkipLF();
        emptyLineReaded = 1;
        return;
    }
    *pointer = data;
    pointer++;
    
    do {
        data = GetInputByte();
        if(data == 13) {
            *pointer = '\0';
            SkipLF();
        } else {
            *pointer = data;
            pointer++;
        }
    } while(data != 13);
    
    debug(headerLine);
}


void ProcessNextHeader()
{
    if(emptyLineReaded) {
        return;
    }

    ExtractHeaderTitleAndContents();
    
    if(StringIs(headerTitle, "Content-Length")) {
        contentLength = atol(headerContents);
        return;
    }
    
    if(StringIs(headerTitle, "Transfer-Encoding")) {
        if(StringIs(headerContents, "Chunked")) {
            isChunkedTransfer = true;
            debug("Chunked encoding");
        } else {
            printf("WARNING: Unknown transfer encoding: '%s'\r\n\r\n", headerContents);
        }
        return;
    }
}


void ProcessResponseStatus()
{
    if(responseStatusCode == 507) {
        Terminate("Your Dropbox account is full. Can't add new files.");
    } else if(responseStatusCode == 401) {
        Terminate("Bad authentication token.\r\n    Please reauthenticate by using DBACC.COM with the \"auth\" option.");
/*    } else if(responseStatusCode == 404) {
        Terminate("File not found on server, or invalid HTTP request"); */
    } else if(responseStatusCode == 406) {
        Terminate("Too many files in the directory (more than 10000)");
    } else if(responseStatusCode == 304) {
        directoryChanged = false;
        return;
    } else if(responseStatusCodeFirstDigit != 2) {
        TerminateWithHttpError();
    }
}


void TerminateWithHttpError()
{
    char* pointer = statusLine;
    JsonType type;
    char* temp = malloc(512);

    SkipCharsUntil(pointer, ' ');
    SkipCharsWhile(pointer, ' ');
    printf("\r\x1BK*** Error returned by server: %s\r\n", pointer);

    if(fileHandle !=0) {
        CloseFile(fileHandle);
        fileHandle = 0;
    }
    
    JsonBuffer = malloc(2048);
    DownloadHttpContents();
    debug2("JsonBuffer: %s", JsonBuffer);
    JsonInit(true);
    while(JsonDataAvailable())
    {
        type = JsonGetNextItem(temp, temp + 256);
        if(type == JSON_DATA) {
            printf("%s: %s\r\n", temp, temp + 256);
        }
    }
    
    Terminate(NULL);
}


void InitializeHttpVariables()
{
    directoryChanged = true;
    isChunkedTransfer = false;
}


byte GetInputByte()
{
    byte data;
    EnsureThereIsTcpDataAvailable();
    data = *inputDataPointer;
    inputDataPointer++;
    remainingInputData--;
    return data;
}


void ExtractHeaderTitleAndContents()
{
    char* pointer;
    pointer = headerLine;
    
    SkipCharsWhile(pointer, ' ');
    headerTitle = headerLine;
    SkipCharsUntil(pointer, ':');
    
    *pointer = '\0';
    pointer++;
    SkipCharsWhile(pointer, ' ');
    
    headerContents = pointer;
}


void DownloadHttpContents()
{
    if(isChunkedTransfer) {
        DoChunkedDataTransfer();
    } else {
        DoDirectDatatransfer();
    }
}


void DoDirectDatatransfer()
{
    char* pointer = JsonBuffer;

    receivedLength = 0;
    while(contentLength == 0 || receivedLength < contentLength) {
        EnsureThereIsTcpDataAvailable();
        receivedLength += remainingInputData;
        if(fileHandle == 0) {
            copy(pointer, inputDataPointer, remainingInputData);
            pointer += remainingInputData;
        } else {
            WriteToFile(fileHandle, inputDataPointer, remainingInputData, strErrorWritingFile);
        }
        ResetTcpBuffer();
    }
    *pointer = '\0';
}


void DoChunkedDataTransfer()
{
    int chunkSizeInBuffer;
    char* pointer = JsonBuffer;
    contentLength = 0;

    currentChunkSize = GetNextChunkSize();

    while(1) {
        if(currentChunkSize == 0) {
            GetInputByte(); //Chunk data is followed by an extra CRLF
            GetInputByte();
            currentChunkSize = GetNextChunkSize();
            if(currentChunkSize == 0) {
                break;
            }
        }

        if(remainingInputData == 0) {
            EnsureThereIsTcpDataAvailable();
        }

        chunkSizeInBuffer = currentChunkSize > remainingInputData ? remainingInputData : currentChunkSize;
        receivedLength += chunkSizeInBuffer;
        if(fileHandle == 0) {
            copy(pointer, inputDataPointer, (int)chunkSizeInBuffer);
            pointer += chunkSizeInBuffer;
            contentLength += chunkSizeInBuffer;
        } else {
            WriteToFile(fileHandle, inputDataPointer, (int)chunkSizeInBuffer, strErrorWritingFile);
        }
        inputDataPointer += chunkSizeInBuffer;
        currentChunkSize -= chunkSizeInBuffer;
        remainingInputData -= chunkSizeInBuffer;
    }
    *pointer = '\0';
}


//For some reason memcpy hangs the computer,
//so I crafted my own version
void copy(byte* to, byte* from, int len) __naked
{
    __asm
    
    push ix
    ld ix,#4
    add ix,sp
    ld e,(ix)
    ld d,1(ix)
    ld l,2(ix)
    ld h,3(ix)
    ld c,4(ix)
    ld b,5(ix)
    ldir
    pop ix
    ret
    
    __endasm;
}


void ResetTcpBuffer()
{
    remainingInputData = 0;
    inputDataPointer = TcpInputData;
}


long GetNextChunkSize()
{
    byte validHexDigit = 1;
    char data;
    long value = 0;
    
    while(validHexDigit) {
        data = (char)GetInputByte();
        ToLowerCase(data);
        if(data >= '0' && data <= '9') {
            value = value*16 + data - '0';
        } else if(data >= 'a' && data <= 'f') {
            value = value*16 + data - 'a' + 10;
        } else {
            validHexDigit = 0;
        }
    }
    
    do {
        data = GetInputByte();
    } while(data != 10);

    return value;
}


JsonType JsonInit(bool extractFirstItem)
{
    JsonType type;
    char* pointer;

    debug2("JsonInit, fileHandle = %i", fileHandle);

    jsonUpperLimit = JsonBuffer + JSON_BUF_SIZE;
    jsonNestLevel = 0;
    jsonLastItemType = JSON_NONE;
    
    if(fileHandle == 0) {
        jsonPointer = JsonBuffer;
    } else {
        jsonPointer = jsonUpperLimit - 1;
        IncreaseJsonPointer();
    }
    
    if(extractFirstItem) {
        pointer = malloc(256);
        type = JsonGetNextItem(pointer, pointer + 128);
        mfree(pointer);
        CheckExpectedJsonType(type, JSON_OBJECT_START);
        return type;
    } else {
        return JSON_NONE;
    }
    
}


bool JsonDataAvailable()
{
    return !(jsonNestLevel == 0 && jsonLastItemType != (JsonType)JSON_NONE);
}


JsonType JsonGetNextItem(char* name, char* value)
{
    char theChar;
    bool isString;

    JsonSkipWhitespaceCharsAndCommas();
    theChar = *jsonPointer;
    IncreaseJsonPointer();
    
    if(theChar == '{') {
        jsonNestLevel++;
        jsonLastItemType = JSON_OBJECT_START;
        *name = '\0';
        *value = '\0';
        return JSON_OBJECT_START;
    } else if(theChar == '}') {
        DecreaseJsonNestLevel();
        jsonLastItemType = JSON_OBJECT_END;
        *name = '\0';
        *value = '\0';
        return JSON_OBJECT_END;
    } else if(theChar == '[') {
        jsonNestLevel++;
        jsonLastItemType = JSON_ARRAY_START;
        *name = '\0';
        *value = '\0';
        return JSON_ARRAY_START;
    } else if(theChar == ']') {
        if(!(jsonLastItemType == JSON_ARRAY_START || jsonLastItemType == JSON_OBJECT_END)) {
            Terminate(strInvJson);
        }
        DecreaseJsonNestLevel();
        jsonLastItemType = JSON_ARRAY_END;
        *name = '\0';
        *value = '\0';
        return JSON_ARRAY_END;
    } else if(theChar != '"') {
        Terminate(strInvJson);
    }

    //At this point we are sure Json type is a name-value data pair

    JsonExtractValue(name, true);
    JsonSkipWhitespaceCharsAndCommas();
    CheckJsonCharIs(':');
    JsonSkipWhitespaceCharsAndCommas();
    
    if(*jsonPointer == '[') {
        IncreaseJsonPointer();
        *value = '\0';
        jsonNestLevel++;
        jsonLastItemType = JSON_ARRAY_START;
        return JSON_ARRAY_START;
    } else if(*jsonPointer == '{') {
        IncreaseJsonPointer();
        *value = '\0';
        jsonNestLevel++;
        jsonLastItemType = JSON_OBJECT_START;
        return JSON_OBJECT_START;
    }

    JsonSkipWhitespaceCharsAndCommas();

    theChar = *jsonPointer;
    if(theChar == '"') {
        isString = true;
        IncreaseJsonPointer();
    } else {
        isString = false;
    }

    JsonExtractValue(value, isString);
    return JSON_DATA;
}


void JsonExtractValue(char* destination, bool isString)
{
    char value;
    char escape;
    char utf8Buffer[4];
    
    while(true) {
        if((value = *jsonPointer) == '\\') {
            IncreaseJsonPointer();
            escape = *jsonPointer;
            IncreaseJsonPointer();
            if(escape == '\\' || escape == '"' || escape == '/') {
                *destination++ = escape;
            } else if(escape == 'b') {
                *destination++ = 8;
            } else if(escape == 'f') {
                *destination++ = 12;
            } else if(escape == 'n') {
                *destination++ = 10;
            } else if(escape == 'r') {
                *destination++ = 13;
            } else if(escape == 't') {
                *destination++ = 9;
            } else if(escape == 'u') {
                //Non-standard ASCII is converted to UTF8
                utf8Buffer[0] = *jsonPointer;
                IncreaseJsonPointer();
                utf8Buffer[1] = *jsonPointer;
                IncreaseJsonPointer();
                utf8Buffer[2] = *jsonPointer;
                IncreaseJsonPointer();
                utf8Buffer[3] = *jsonPointer;
                IncreaseJsonPointer();
                
                destination += FourByteHexToUTF8(utf8Buffer, destination);
            }
        } else {
            if((isString && value == '"') || (!isString && value == ',')) {
                IncreaseJsonPointer();
                *destination = '\0';
                return;
            } else if(!isString && value == '}') {
                *destination = '\0';
                return;
            } else {
                IncreaseJsonPointer();
                *destination++ = value;
            }
        }
    }
}


void JsonSkipWhitespaceCharsAndCommas()
{
    while(*jsonPointer == ' ' || *jsonPointer == '\r' || *jsonPointer == '\n' || *jsonPointer == ',') {
        IncreaseJsonPointer();
    }
}


void CheckJsonCharIs(char c)
{
    if(*jsonPointer != c) {
        Terminate(strInvJson);
    }
    IncreaseJsonPointer();
}


void IncreaseJsonPointer()
{
    int readed;

    jsonPointer++;
    if(fileHandle != 0 && jsonPointer == jsonUpperLimit) {
        debug2("Going to read %i bytes from temporary file", JSON_BUF_SIZE);
        readed = ReadFromFile(fileHandle, JsonBuffer, JSON_BUF_SIZE, strErrReadTemp);
        debug2("Got %i bytes from temporary file", readed);
        if(readed != JSON_BUF_SIZE) {
            JsonBuffer[readed] = '\0';
        }
        jsonPointer = JsonBuffer;
    }
}


void GetDataDirectory()
{
    //byte len;
    dataDirectory = malloc(64);
    dataDirectory[0] = '\0';

/*    
    regs.Words.HL = (int)"DROPBOX_DATA_DIR";
    regs.Words.DE = (int)dataDirectory;
    regs.Bytes.B = 128;
    DosCall(_GENV, &regs, REGS_MAIN, REGS_NONE);
    if(dataDirectory[0] != '\0') {
        len = strlen(dataDirectory);
        if(dataDirectory[len-1] != '\\') {
            dataDirectory[len] = '\\';
            dataDirectory[len+1] = '\0';
        }
        debug2("Data directory: %s", dataDirectory);
        return;
    }
*/

    GetEnvironmentItem("PROGRAM", dataDirectory, 128);

    regs.Bytes.B = 0;
    DosCall(_PARSE, &regs, REGS_MAIN, REGS_MAIN);
    *((char*)regs.Words.HL) = '\0';
    debug2("Data directory: %s", dataDirectory);
}


void GetDataFilePath(char* fileName, char* destination)
{
    strcpy(destination, dataDirectory);
    strcat(destination, fileName);
}


byte CreateFile(char* path, char* errorMessage)
{
    regs.Bytes.A = 0;
    regs.Bytes.B = 0;
    regs.Words.DE = (int)path;
    DosCall(_CREATE, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode(errorMessage, regs.Bytes.A);
    }
    return regs.Bytes.B;
}


void WriteToFile(byte handle, byte* data, int length, char* errorMessage)
{
    byte error;
    regs.Bytes.B = handle;
    regs.Words.DE = (int)data;
    regs.Words.HL = length;
    DosCall(_WRITE, &regs, REGS_MAIN, REGS_AF);
    if(regs.Bytes.A != 0) {
        error = regs.Bytes.A;
        CloseFile(handle);
        fileHandle = 0;
        TerminateWithDosErrorCode(errorMessage, error);
    }
}


void CloseFile(byte handle)
{
    regs.Bytes.B = handle;
    DosCall(_CLOSE, &regs, REGS_MAIN, REGS_AF);
}


void TerminateWithDosErrorCode(char* message, byte errorCode)
{
    char* pointer = MALLOC_BASE;

    strcpy(pointer, message);
    pointer += strlen(message);
    ExplainDosErrorCode(errorCode, pointer);
    Terminate(MALLOC_BASE);
}


char* ExplainDosErrorCode(byte code, char* destination)
{
    regs.Bytes.B = code;
    regs.Words.DE = (int)destination;
    DosCall(_EXPLAIN, &regs, REGS_MAIN, REGS_NONE);
    return destination;
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


void ReadTokenFromFile()
{
    byte fileHandle;
    char* pointer;
    int readed;
    byte* temp;

    token = malloc(64);
    tokenSecret = malloc(64);
    temp = malloc(256);
    
    GetDataFilePath("dropbox.usr", temp);
    if(!FileExists(temp)) {
        Terminate("User authorization file not found.\r\n    Please run the application with the \"auth\" parameter.");
    }
    
    fileHandle = OpenFile(temp, "Error when opening the user data file: ");
    readed = ReadFromFile(fileHandle, temp, 256, "Error when reading from the user data file: ");
    temp[readed]='\0';
    debug(temp);
    CloseFile(fileHandle);
    fileHandle = 0;
    
    ParseFileLine(&temp, NULL, 128);
    ParseFileLine(&temp, token, 64);
    ParseFileLine(&temp, tokenSecret, 64);
    mfree(temp);
    debug3("I got from file: token = %s, tokenSecret = %s", token, tokenSecret);
}


void ParseFileLine(byte** src, byte* dest, int maxLength)
{
    byte* pnt = *src;

    if(*pnt == 13) {
        Terminate(strBadUsrFile);
    }

    while(*pnt != 13) {
        if(maxLength == 0 || *pnt < 33 || *pnt > 126) {
            Terminate(strBadUsrFile);
        }
        if(dest != NULL) {
            *dest++ = *pnt;
        }
        pnt++;
        maxLength--;
    }
    if(dest != NULL) {
        *dest = 0;
    }
    pnt += 2;    //Skip CR and LF
    *src = pnt;
}


void PrintSize(unsigned long size)
{
    int remaining;

    if(size < 1024) {
        printf("%i bytes", size);
        return;
    }

    remaining = size & 1023;
    if(remaining > 1000) {
        remaining = 999;
    }
    size >>= 10;
    if(size < 1024) {
        printf("%i.%iKB", (int)size, remaining/100);
        return;
    }
    
    remaining = size & 1023;
    if(remaining > 1000) {
        remaining = 999;
    }
    size >>= 10;
    printf("%i.%iMB", (int)size, remaining/100);
}


bool HasOnlyAsciiChars(char* string)
{
    char value;
    while((value = *string) != '\0') {
        if(value < 32 || value > 126) {
            return false;
        }
        string++;
    }
    return true;
}


bool FileExists(char* path)
{
    byte* pointer = malloc(sizeof(t_FileInfoBlock));
    
    regs.Words.DE = (int)path;
    regs.Bytes.B = 0;
    regs.Words.IX = (int)pointer;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
    
    mfree(pointer);
    return (regs.Bytes.A == 0);
}


void minit() __naked
{
	__asm

    ld  hl,#0xC000-2
    ld  (_malloc_ptr),hl

	ld	hl,#0x8000
	ld	de,#0x8001
	ld	bc,#0x4000-1
	ld	(hl),#0
	ldir

    ;ld  hl,#0x4000-2
    ;ld  (#0x8000),hl

	;ld	hl,#3	;2 byte block, bit 0 set to mark allocated block
	;ld	(BK_PTR-2),hl
	;ld	hl,#BK_PTR-2
	;ld	(BK_PTR),hl
	ret

	__endasm;
}


void* malloc_core(unsigned int size) __naked
{
	__asm

	push	ix
	ld	ix,#4
	add	ix,sp
	ld	l,(ix)
	ld	h,1(ix)	;HL = requested size

	push	de
	push	bc
	inc	hl			;Round the request up to
	res	0,l			; an even number of bytes
	ld	b,h			; and put the value in BC.
	ld	c,l
;
	ld	hl,(_malloc_ptr)		;Point to start of chain
fr_chain_loop:	ld	e,(hl)
	inc	hl			;DE := size of this block
	ld	d,(hl)
	inc	hl
	ld	a,d
	or	e			;Exit loop if size=0 which
	jr	z,fr_chain_end		; indicates end of chain.
	bit	0,e
	jr	nz,fr_chain_next	;Loop if block is allocated
	ex	de,hl			;If block is free then see if
	sbc	hl,bc			; it is big enough and if not
	jr	nc,fr_chain_fit		; then loop to try next one
;
	add	hl,bc			;Gt this block size back
	ex	de,hl			; into DE.
fr_chain_next:	res	0,e
	add	hl,de			;HL -> next block and loop
	jr	fr_chain_loop		;      to try this one.
;
;
fr_chain_fit:	ex	de,hl
	dec	hl
	dec	hl
	jr	z,init_new_block	;Skip if fit is exact
	dec	de
	dec	de			;Subtract 2 from extra size
	ld	a,d			; to account for new size
	or	e			; entry and skip if it is zero
	jr	z,near_exact_fit	; (zero block not allowed)
;
	ld	(hl),e			;Store the extra size as the
	inc	hl			; size of the remaining
	ld	(hl),d			; free block block.
	inc	hl			;HL -> start of new block
	add	hl,de
	jr	init_new_block		;Jump to zero the block.
;
near_exact_fit:	inc	bc			;If only 2 extra bytes then
	inc	bc			; increase the block size
	jr	init_new_block		; to include them.
;
;
fr_chain_end:	ld	a,#1		;Anticipate error code (was: .NORAM)
	inc	bc			;Allow space for the block
	inc	bc			; size to be stored.
;
	ld	hl,(_malloc_ptr)		;Get current RAM limit
	or	a			;Work out what new limit
	sbc	hl,bc			; would be after allocation.
	jr	c,not_enuf_ram		;Moan if below zero.
	jp	p,not_enuf_ram		;Also moan if below 8000h.
;
	ld	(_malloc_ptr),hl		;OK so record new limit
	dec	bc
	dec	bc			;Adjust block size back
;
;
init_new_block:	ld	(hl),c			;Store the block size in the
	set	0,(hl)			; first word of the newly
	inc	hl			; allocated block, and set
	ld	(hl),b			; the bottom bit to mark it
	inc	hl			; as allocated.
;
	push	hl
zero_ram_loop:	ld	(hl),#0			;Zero the allocated RAM.
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,zero_ram_loop	;Loop will exit with A=0
	pop	hl			; which becomes return code.
;
not_enuf_ram:	pop	bc
	pop	de
	or	a			;Set success/fail flag

	pop	ix
	ret	z
	ld	hl,#0
	ret

	__endasm;
}


void mfree(void* address) __naked
{
	__asm

	push	ix
	ld	ix,#4
	add	ix,sp
	ld	l,(ix)
	ld	h,1(ix)	;HL = address

	dec	hl			;Mark the memory block as
	dec	hl			; free now.
	res	0,(hl)
	;
	push	de
	push	bc
	ld	hl,(_malloc_ptr)		;Start at beginning of
ram_ptr_loop:	ld	c,(hl)			; memory block chain and
	bit	0,c			; walk through it util we
	jr	nz,first_alloc_blk	; find the first block which
	inc	hl			; is allocated.
	ld	b,(hl)
	inc	hl
	add	hl,bc
	jr	ram_ptr_loop
	;
first_alloc_blk:ld	(_malloc_ptr),hl		;Record new start address
	;
chk_blk_loop:	ld	e,(hl)
	inc	hl			;Get size of next block in
	ld	d,(hl)			; the chain.
	inc	hl
	ld	a,d
	or	e			;Exit if end of chain.
	jr	z,free_p2_ret
	bit	0,e			;Dont try to join together
	jr	nz,chk_next_blk		; if block is allocated.
	;
join_blk_loop:	push	hl			;Record start address of block
	add	hl,de
	ld	c,(hl)			;Point to next block and get
	inc	hl			; its size into BC.
	ld	b,(hl)
	pop	hl			;Restore main block pointer
	bit	0,c
	jr	nz,not_free_blk		;Jump if new block is not free
	inc	bc			;New block is free so add its
	inc	bc			; size onto the size of the
	ex	de,hl			; main block in DE, and add
	add	hl,bc			; 2 extra bytes for size word.
	ex	de,hl
	jr	join_blk_loop		;Loop for next block.
	;
not_free_blk:	dec	hl			;Record new size of the main
	ld	(hl),d			; block at its start.
	dec	hl
	ld	(hl),e
	inc	hl
	inc	hl
	;
chk_next_blk:	res	0,e			;Add size of this block to
	add	hl,de			; get pointer to next one
	jr	chk_blk_loop		; and loop back.
	;
	;
free_p2_ret:	pop	bc
	pop	de
	pop ix
	ret

	__endasm;
}


void* malloc(unsigned int size)
{
    void* pointer = malloc_core(size);
    if(pointer == null) {
        Terminate("Out of memory");
    }
    return pointer;
}


void DoGetDirectory()
{
    bool useSearchCommand;
    int i;
    int searchArgumentIndex;
    char* resourceName = malloc(512);
    char* encodedRemotePath = malloc(1024);
    char* paramsBuffer = malloc(512);
    char* searchString = malloc(128);

    useSearchCommand = false;
    searchArgumentIndex = 0;

#ifdef ADJUST_TIMEZONE    
    char* timeZoneString;
#endif

    if(argumentsCount < 2) {
        Terminate(strInvParam);
    }

    for(i=2; i<argumentsCount; i++) {
        if(StringStartsWith(arguments[i], "nlen=")) {
            displayNameLen = atoi(arguments[i] + 5);
            if(displayNameLen < 3 || displayNameLen > 256) {
                Terminate(strInvParam);
            }
        } else if(StringStartsWith(arguments[i], "show=")) {
            if(StringIs(arguments[i]+5, "dirs")) {
                dirShowType = DIR_SHOW_DIRS;
            } else if(StringIs(arguments[i]+5, "files")) {
                dirShowType = DIR_SHOW_FILES;
            } else if(!StringIs(arguments[i]+5, "all")) {
                Terminate(strInvParam);
            }
        } else if(StringStartsWith(arguments[i], "format=")) {
            if(StringIs(arguments[i]+7, "simple")) {
                dirFormatType = DIR_FORMAT_SIMPLE;
            } else if(StringIs(arguments[i]+7, "raw")) {
                dirFormatType = DIR_FORMAT_RAW;
            } else if(!StringIs(arguments[i]+7, "full")) {
                Terminate(strInvParam);
            }
        } else if(StringStartsWith(arguments[i], "search=") || StringStartsWith(arguments[i], "s=")) {
            useSearchCommand = true; 
            strcpy(searchString, strchr(arguments[i],(int)'=')+1);
            if(*searchString == '\0') {
                Terminate("'search' parameter can't be empty");
            }
        } else {
            Terminate(strInvParam);
        }
    }

#ifdef ADJUST_TIMEZONE

    timeZoneString = malloc(7);
    if(GetEnvironmentItem("TIMEZONE", timeZoneString, 7)) {
        timeZoneString[6] = '\0';
        timeZoneMinutes = ParseTimeZone(timeZoneString);
        hasTimeZone = true;
        printf("*** tzmin: %i\r\n", timeZoneMinutes);
        Terminate(null);
    }
    mfree(timeZoneString);
    
#endif

    ReadRemotePath(arguments[1]);
    ReadTokenFromFile();
    
    OpenTempFilename();
    
    if(useSearchCommand) {
        strcpy(resourceName, "/1/search/dropbox");
    } else {
        strcpy(resourceName, "/1/metadata/dropbox");
    }
    
    PercentEncode(remotePath, encodedRemotePath, 3);
    strcat(resourceName, encodedRemotePath);
    if(useSearchCommand) {
        ReplaceChars(searchString, '*', ' ');
        PercentEncode(searchString, encodedRemotePath, 0);
        sprintf(paramsBuffer, "file_limit=10000&query=%s", encodedRemotePath);
    } else {
        strcpy(paramsBuffer, "file_limit=10000&list=true");
    }

    mfree(encodedRemotePath);
    DoHttpTransaction(true, resourceName, paramsBuffer);
    mfree(resourceName);
    mfree(paramsBuffer);
    mfree(searchString);

    if(outputIsRedirectedToFile) {
        print(strWritingFile);
        ProcessRemoteDirectoryData(useSearchCommand);
        print(strOk);
    } else {
        ProcessRemoteDirectoryData(useSearchCommand);
    }
}


void ProcessRemoteDirectoryData(bool withSearch)
{
    t_RemoteFileInfo* fileInfo;
    char* itemName;
    char* itemContent;
    JsonType type;
    bool ok;
    
    RewindFile(fileHandle);
    JsonInit(false);

    RestoreStandardOutput();    
    if(dirFormatType == DIR_FORMAT_RAW) {
        RewindFile(fileHandle);
        PrintFileContents(fileHandle);
    } else {
        fileInfo = New_RemoteFileInfo();
        itemName = malloc(256);
        itemContent = malloc(256);
    
        if(withSearch) {
            JsonGetNextItem(itemName, itemContent);
        }

        ok = GetCurrentFileData(fileInfo, itemName, itemContent);
        if(withSearch && !ok) {
            RedirectOutputToStandardError();
            print("\r\nNo files or directories found with the specified search pattern.\r\n");
            return;
        }
    
        if(fileInfo->isDir || withSearch) {
            ShowDirContentsInformation(fileInfo, itemName, itemContent, withSearch);
        } else {
            ShowFileInformation(fileInfo);
        }
        
        mfree(itemContent);
        mfree(itemName);
        Delete_RemoteFileInfo(fileInfo);
    }

    RedirectOutputToStandardError();    
}


bool GetCurrentFileData(t_RemoteFileInfo* fileInfo, char* itemNameBuffer, char* itemContentBuffer)
{
    JsonType type = JsonGetNextItem(itemNameBuffer, itemContentBuffer);
    
    if(type != JSON_OBJECT_START) {
        return false;
    }

    while((type = JsonGetNextItem(itemNameBuffer, itemContentBuffer)) == JSON_DATA) {
        if(StringIs(itemNameBuffer, "is_dir")) {
            fileInfo->isDir = StringIsTrue(itemContentBuffer);
        } else if(StringIs(itemNameBuffer, "size")) {
            strcpy(fileInfo->size, itemContentBuffer);
        } else if(StringIs(itemNameBuffer, "modified")) {
            strcpy(fileInfo->modifiedDate, itemContentBuffer);
        } else if(StringIs(itemNameBuffer, "bytes")) {
            fileInfo->sizeBytes = atol(itemContentBuffer);            
        } else if(StringIs(itemNameBuffer, "path")) {
            strcpy(fileInfo->path, itemContentBuffer);
            if(fileInfo->path[0] == '\0') {
                fileInfo->path[0] = '/';
                fileInfo->path[1] = '\0';
            }
        }
    }
    return true;
}


void ShowFileInformation(t_RemoteFileInfo* fileInfo)
{
    printf("\r\n");
    printf("File path: %s\r\n", fileInfo->path);
    printf("Modified:  %s\r\n", fileInfo->modifiedDate);
    printf("Size:      %s\r\n", fileInfo->size);
}


void ShowDirContentsInformation(t_RemoteFileInfo* fileInfo, char* itemNameBuffer, char* itemContentBuffer, bool isSearch)
{
    unsigned long totalSize = 0;
    int fileCount = 0;
    int dirCount = 0;
    bool showFirst = isSearch;

    if(dirFormatType == DIR_FORMAT_FULL) {
        if(isSearch) {
            print("\r\nSearch results:\r\n\r\n");
        } else {
            printf("\r\nDirectory contents of %s:\r\n\r\n", fileInfo->path);
        }
    }
    
    while(showFirst || GetCurrentFileData(fileInfo, itemNameBuffer, itemContentBuffer)) {
        showFirst = false;
        if(dirShowType == DIR_SHOW_FILES && fileInfo->isDir) {
            continue;
        } else if(dirShowType == DIR_SHOW_DIRS && !fileInfo->isDir) {
            continue;
        }
    
        if(PrintShortFileInformation(fileInfo)) {
            dirCount++;
        } else {
            fileCount++;
            totalSize += fileInfo->sizeBytes;
        }
    }
    
    if(dirFormatType == DIR_FORMAT_FULL) {
        if(dirShowType == DIR_SHOW_FILES && fileCount == 0) {
            print("Directory has no files.");
        } else if(dirShowType == DIR_SHOW_DIRS && dirCount == 0) {
            print("Directory has no subdirectories.");
        } else if(dirShowType == DIR_SHOW_ALL && fileCount+dirCount == 0) {
            print("Directory is empty.");
        } else {
            PrintNewLine();
            if(dirShowType != DIR_SHOW_DIRS) {
                PrintSize(totalSize);
                printf(" in %i files\r\n", fileCount);
            }
            if(!(dirShowType == DIR_SHOW_FILES)) {  //weird compiler warning if != is used (???)
                printf("%i subdirectories\r\n", dirCount);
            }
        }
    }
}


bool PrintShortFileInformation(t_RemoteFileInfo* fileInfo)
{
    char* path;
    
    if(dirFormatType == DIR_FORMAT_SIMPLE) {
        printf("%s%s\r\n", fileInfo->path, fileInfo->isDir ? "/" : "");
        return fileInfo->isDir;
    } else {
        path = AdjustString(fileInfo->path, displayNameLen, true, false);
        fileInfo->modifiedDate[7] = '-';
        fileInfo->modifiedDate[11] = '-';
        fileInfo->modifiedDate[22] = '\0';
        printf("%s   %s   %s\r\n", path, fileInfo->modifiedDate + 5, fileInfo->isDir ? "<dir>" : fileInfo->size);
    }
    return fileInfo->isDir;
}


char* AdjustString(char* name, int maxLen, bool skipToLastSlash, bool appendSlash)
{
    int len;
    char* pointer;

    if(skipToLastSlash) {
        name += strlen(name);
        while(*name != '/') {
            name--;
        }
        name++;
    }
    if(appendSlash) {
        strcat(name, "/");
    }
    
    len = strlen(name);
    pointer = name;
    if(len > maxLen) {
        strcpy(name + maxLen - 3, "...");
    } else {
        name = name + len;
        while(len < maxLen) {
            *name++ = ' ';
            len++;
        }
        *name = '\0';
    }
    
    return pointer;
}


bool StringIsTrue(char* string)
{
    return StringIs(string, "true");
}


void RewindFile(byte fileHandle)
{
    regs.Bytes.A = 0;
    regs.Bytes.B = fileHandle;
    regs.Words.HL = 0;
    regs.Words.DE = 0;
    DosCall(_SEEK, &regs, REGS_MAIN, REGS_AF);
    debug2("File rewinded, error = %i", regs.Bytes.A);
}


void ReadRemotePath(char* source)
{
    char* pointer;
    int readed;

    remotePathBuffer = malloc(261);
    remotePath = remotePathBuffer + 1;
    if(StringStartsWith(source, "file:")) {
        fileHandle = OpenFile(source + 5, "Error when opening URL file: ");
        readed = ReadFromFile(fileHandle, remotePath, 260, "Error when reading from URL file: ");
        if(readed == 260) {
            Terminate("URL file is too long (maximum is 256 characters)");
        }
        remotePath[readed] = '\0';
        pointer = remotePath;
        while(*pointer != 13 && *pointer != 10 && *pointer != 0x1A && *pointer != 0) {
            pointer++;
        }
        *pointer = '\0';
        CloseFile(fileHandle);
        fileHandle = 0;
    } else {
        strcpy(remotePath, source);    
    }
    
    #if 0
    CheckHasOnlyAsciiHars(remotePath);
    #endif
    ReplaceChars(remotePath, '*', ' ');
    ReplaceChars(remotePath, '\\', '/');
    
    if(*remotePath != '/') {
        remotePath--;
        *remotePath = '/';
    }
}


void ReplaceChars(char* string, char charSource, char charDestination)
{
    char value;
    while((value = *string) != '\0') {
        if(value == charSource) {
            *string = charDestination;
        }
        string++;
    }
}


void DoHttpTransaction(bool useGet, char* resourceName, char* params)
{
    char* httpRequest;

    ResolveServerName();
    print("Connecting to server... ");
    OpenTcpConnection();
    print(strOk);
    
    print("Sending request... ");
    httpRequest = malloc(1024);
    GenerateHttpRequest(useGet, resourceName, params, httpRequest);
    SendTcpData(httpRequest, strlen(httpRequest));
    mfree(httpRequest);
    print(strOk);
    
    print("Waiting response... ");
    ReadResponseHeaders();
    print(strOk);
    
    JsonBuffer = malloc(JSON_BUF_SIZE);
    if(!isChunkedTransfer && contentLength!=0) {
        print("File size: ");
        PrintSize(contentLength);
        PrintNewLine();
    }
    print("Receiving data... ");
    DownloadHttpContents();
    print(strOk);
}


void OpenTempFilename()
{
    char* path = malloc(128);

    usingTempFile = true;
    if(!GetEnvironmentItem("TEMP", path, 128)) {
        strcpy(path, dataDirectory);
    }
    
    AppendSlashIfNecessary(path);
    strcat(path, "DBFILE.$$$");
    
    debug2("Temporary file is: %s", path);
    
    fileHandle = CreateFile(path, "Error when creating temporary file: ");
}


void AppendSlashIfNecessary(char* string)
{
    int len = strlen(string);
    if(string[len-1] != '\\') {
        string[len] = '\\';
        string[len+1] = '\0';
    }
}


t_RemoteFileInfo* New_RemoteFileInfo()
{
    t_RemoteFileInfo* pointer = malloc(sizeof(t_RemoteFileInfo));
    pointer->size = malloc(32);
    pointer->path = malloc(512);
    pointer->modifiedDate = malloc(40);
    pointer->size[0] = '\0';
    pointer->path[0] = '\0';
    pointer->modifiedDate[0] = '\0';
    return pointer;
}


void Delete_RemoteFileInfo(t_RemoteFileInfo* pointer)
{
    mfree(pointer->modifiedDate);
    mfree(pointer->path);
    mfree(pointer->size);
    mfree(pointer);
}



int StringStartsWith(const char* stringToCheck, const char* startingToken)
{
    int len;
    len = strlen(startingToken);
    return strncmpi(stringToCheck, startingToken, len) == 0;
}


int strncmpi(const char *a1, const char *a2, unsigned size) {
	char c1, c2;
	/* Want both assignments to happen but a 0 in both to quit, so it's | not || */
	while((size > 0) && (c1=*a1) | (c2=*a2)) {
		if (!c1 || !c2 || /* Unneccesary? */
			(islower(c1) ? toupper(c1) : c1) != (islower(c2) ? toupper(c2) : c2))
			return (c1 - c2);
		a1++;
		a2++;
		size--;
	}
	return 0;
}


byte DuplicateFileHandle(byte fileHandle)
{
    regs.Bytes.B = fileHandle;
    DosCall(_DUP, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when duplicating file handle: ", regs.Bytes.A);
    }
    return regs.Bytes.B;
}


void RedirectOutputToStandardError()
{
    CloseFile(STANDARD_OUTPUT);
    DuplicateFileHandle(standardErrorDuplicate);   
}


void RestoreStandardOutput()
{
    CloseFile(STANDARD_OUTPUT);
    DuplicateFileHandle(standardOutputDuplicate);   
}


bool OutputIsRedirectedToFile()
{
    regs.Bytes.A = 0;
    DosCall(_REDIR, &regs, REGS_AF, REGS_MAIN);
    return ((regs.Bytes.B & 2) != 0);
}


void DoFileOperation(char* operationName, FileopType type)
{
    char* resourceName = malloc(32);
    char* escapedPath1 = malloc(512);
    char* escapedPath2 = null;
    char* params = null;
    char* remotePath2 = null;
    
    if(type == FILEOP_SINGLE_ARG) {
        CheckExactArgumentsCount(2);
    } else {
        CheckExactArgumentsCount(3);
    }
    
    ReadTokenFromFile();
    strcpy(resourceName, "/1/fileops/");
    strcat(resourceName, operationName);
    
    if(!(type == FILEOP_SINGLE_ARG)) {
        remotePath2 = malloc(257);
        ReadRemotePath(arguments[2]);
        strcpy(remotePath2, remotePath);
    }
    ReadRemotePath(arguments[1]);
    
    if(StringIs(operationName, "delete") && StringIs(remotePath, "/")) {
        print("This will delete ALL the contents of your Dropbox account!!\r\nAre you sure? (y/n) ");
        DosCall(_CONIN, &regs, REGS_NONE, REGS_AF);
        ToLowerCase(regs.Bytes.A);
        if(regs.Bytes.A != (byte)'y') {
            Terminate("Operation cancelled");
        } 
        PrintNewLine();
        PrintNewLine();
    }
   
    if(type == FILEOP_COPY_MOVE) {
        if(StringEndsWith(remotePath2, '/')) {
            GetFilenamePart(remotePath, remotePath2 + strlen(remotePath2));
        }
    } else if(type == FILEOP_REN) {
        SubstituteName(remotePath + 1, remotePath2 + 1);
    }
    
    ReplaceChars(remotePath, '*', ' ');
    PercentEncode(remotePath, escapedPath1, 0);
    if(remotePath2 == null) {
        params = malloc(2048);
        sprintf(params, "path=%s&root=dropbox", escapedPath1);
    } else {
        ReplaceChars(remotePath2, '*', ' ');
        escapedPath2 = malloc(512);
        PercentEncode(remotePath2, escapedPath2, 0);
        params = malloc(4096);
        sprintf(params, "from_path=%s&root=dropbox&to_path=%s", escapedPath1, escapedPath2);
    }

    DoHttpTransaction(false, resourceName, params);
    printf("\r\nOperation completed successfully.\r\n");
    
    //Program terminates right after this, so no mfrees necessary
}


void GetFilenamePart(char* source, char* destination)
{
    int len = strlen(source);
    char* pointer = source + len - 1;

    if(*pointer == '/') {
        Terminate("Invalid remote file name");
    }
    
    while(true) {
        if(*pointer == '/' || len == 0) {
            pointer++;
            break;
        }
        pointer--;
        len--;
    }
    
    strcpy(destination, pointer);
    return;
}


void DeleteFile(byte fileHandle)
{
    regs.Bytes.B = fileHandle;
    DosCall(_HDELETE, &regs, REGS_MAIN, REGS_AF);
    if(!terminating && regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when deleting file: ", regs.Bytes.A);
    }
}


void PrintFileContents(byte fileHandle)
{
    int readed;

    do {
        readed = ReadFromFile(fileHandle, JsonBuffer, JSON_BUF_SIZE, strErrReadTemp);
        if(readed != 0) {
            WriteToFile(STANDARD_OUTPUT, JsonBuffer, readed, strErrorWritingFile);
        }
    } while(readed == JSON_BUF_SIZE);
}


bool StringEndsWith(char* s, char c)
{
    return s[strlen(s)-1] == c;
}


int IndexOf(char* s, char c)
{
    int index = 0;
    while(*s != c) {
        s++;
        if(*s == 0) {
            return -1; 
        }
    }
    return index;
}


int LastIndexOf(char* s, char c)
{
    int index = strlen(s) - 1;
    s += index;
    
    while(index >= 0 && *s != c) {
        s--;
        index--;
    }
    return index;
}


void SubstituteName(char* pathAndOldName, char* newName)
{
    char* buffer;
    int sourceLastSlashIndex = LastIndexOf(pathAndOldName, '/');
    int sourceLen = strlen(pathAndOldName);
    if(sourceLastSlashIndex == sourceLen - 1) {
        pathAndOldName[sourceLen - 1] = '\0';
        sourceLastSlashIndex = LastIndexOf(pathAndOldName, '/');
    }

    if(IndexOf(newName, '/') != -1) {
        Terminate("The new name can't contain path information");
    }

    if(sourceLastSlashIndex == -1) {
        return;
    }

    buffer = malloc(256);
    strcpy(buffer, newName);
    strcpy(newName, pathAndOldName);
    newName[sourceLastSlashIndex + 1] = '\0';
    strcat(newName, buffer);
    mfree(buffer);
}


bool GetEnvironmentItem(char* name, char* value, int maxLen)
{
    regs.Words.HL = (int)name;
    regs.Words.DE = (int)value;
    regs.Bytes.B = maxLen;
    *value = '\0';
    DosCall(_GENV, &regs, REGS_MAIN, REGS_AF);
    return (*value != '\0');
}


#ifdef ADJUST_TIMEZONE

int ParseTimeZone(char* timeZoneString)
{
    int hours, minutes, totalMinutes;

    hours = (((byte)(timeZoneString[1])-'0')*10) + (byte)(timeZoneString[2]-'0');
    if(hours > 12) {
        Terminate(strInvalidTimeZone);
    }
        
    minutes = (((byte)(timeZoneString[4])-'0')*10) + (byte)(timeZoneString[5]-'0');
    if(minutes > 59) {
        Terminate(strInvalidTimeZone);
    }
    
    totalMinutes = minutes + (hours * 60);
    
    if(timeZoneString[0] == '-') {
        totalMinutes *= -1;
    } else if(timeZoneString[0] != '+') {
        Terminate(strInvalidTimeZone);
    }
    return totalMinutes;
}


void SecondsToDate(unsigned long seconds, int* year, byte* month, byte* day, byte* hour, byte* minute, byte* second)
{
    int IsLeapYear = 0;
    unsigned long SecsInCurrentMoth;

    if((seconds & 0x80000000) == 0) {
        *year = 2036;
        seconds += SECS_2036_TO_2036;
    }
    else {
        *year = 2010;
        seconds -= SECS_1900_TO_2010;
    }

    //* Calculate year

    while(1) {
        IsLeapYear = ((*year & 3) == 0);
        if((!IsLeapYear && (seconds < SECS_IN_YEAR)) || (IsLeapYear && (seconds < SECS_IN_LYEAR))) {
            break;
        }
        seconds -= (IsLeapYear ? SECS_IN_LYEAR : SECS_IN_YEAR);
        *year = *year+1;
    }

    //* Calculate month

    *month = 1;

    while(1) {
        if(*month == 2 && IsLeapYear) {
            SecsInCurrentMoth = SECS_IN_MONTH_29;
        }
        else {
            SecsInCurrentMoth = SecsPerMonth[*month - 1];
        }

        if(seconds < SecsInCurrentMoth) {
            break;
        }

        seconds -= SecsInCurrentMoth;
        *month = (byte)(*month + 1);
    }

    //* Calculate day

    *day = 1;

     while(seconds > SECS_IN_DAY) {
         seconds -= SECS_IN_DAY;
         *day = (byte)(*day + 1);
     }

     //* Calculate hour

     *hour = 0;

     while(seconds > SECS_IN_HOUR) {
         seconds -= SECS_IN_HOUR;
         *hour = (byte)(*hour + 1);
     }

     //* Calculate minute

     *minute = 0;

     while(seconds > SECS_IN_MINUTE) {
         seconds -= SECS_IN_MINUTE;
         *minute = (byte)(*minute + 1);
     }

     //* The remaining are the seconds

     *second = (byte)seconds;
}


unsigned long DateToSeconds(t_Date* date)
{
    unsigned long seconds = SECS_1970_TO_2010;
    byte isLeapYear;
    int loopValue;

    seconds = SECS_1970_TO_2010;

    //* Years

    loopValue = 2010;
    while(loopValue < date->year) {
        isLeapYear = (loopValue & 3) == 0;
        seconds += (isLeapYear ? SECS_IN_LYEAR : SECS_IN_YEAR);
        loopValue++;
    }
    
    //* Months
    
    isLeapYear = (date->year & 3) == 0;
    loopValue = 1;
    while(loopValue < date->month) {
        if(isLeapYear && (loopValue == 2)) {
            seconds += SECS_IN_MONTH_29;
        } else {
            seconds += SecsPerMonth[loopValue-1];
        }
        loopValue++;
    }
    
    //* Rest of parameters
    
    seconds += (SECS_IN_DAY) * (date->day-1);
    seconds += (SECS_IN_HOUR) * date->hour;
    seconds += (SECS_IN_MINUTE) * date->minute;
    seconds += date->second;
    
    return seconds;
}

#endif

void DecreaseJsonNestLevel()
{
    if(jsonNestLevel == 0) {
        Terminate(strInvJson);
    } else {
        jsonNestLevel--;
    }
}


void CheckExactArgumentsCount(int count)
{
    if(argumentsCount != count) {
        Terminate(strInvParam);
    }
}

#if 0
void CheckHasOnlyAsciiHars(char* string)
{
    char c;
    while((c = *string++) != '\0') {
        if(c < 32 || c > 126) {
            Terminate("Filenames with non-standard ASCII characters are not supported.");
        }
    }
}
#endif


byte FourByteHexToUTF8(byte* string, byte* dest)
{
    unsigned int number;
    byte char0, char1;
    
    number = ParseNibble(string[3])
             + (ParseNibble(string[2]) << 4)
             + (ParseNibble(string[1]) << 8)
             + (ParseNibble(string[0]) << 12);
    char0 = ((byte*)&number)[1];
    char1 = ((byte*)&number)[0];
    
    if((char0 & 0xF8) == 0) {
        dest[0] = (byte)(0xC0 | ((char0 & 7) << 2) | ((char1 & 0xC0) >> 6));
        dest[1] = (byte)(0x80 | (char1 & 0x3F));
        return 2;
    }
    else {
        dest[0] = (byte)(0xE0 | ((char0 & 0xF0) >> 4));
        dest[1] = (byte)(0x80 | ((char0 & 0x0F) << 2) | ((char1 & 0xC0) >> 6));
        dest[2] = (byte)(0x80 | (char1 & 0x3F));
        return 3;
    }
}


byte ParseNibble(char nibble)
{
    ToLowerCase(nibble);
    if(nibble >= 'a') {
        return nibble - 'a' + 10;
    } else {
        return nibble - '0';
    }
}


void GetUrlsFromEnvironmentItems()
{
    ExtractUrlEnvironmentItem("DROPBOX_API_URL", apiUrl, &apiPort);
    //ExtractUrlEnvironmentItem("DROPBOX_API_CONTENT_URL", apiContentUrl, &apiContentPort);

    debug2("API url: %s", apiUrl);
}


void ExtractUrlEnvironmentItem(char* itemName, char* urlDestination, int* portDestination)
{
    char* colonPos;

    regs.Words.HL = (int)itemName;
    regs.Words.DE = (int)urlDestination;
    regs.Bytes.B = 255;
    DosCall(_GENV, &regs, REGS_MAIN, REGS_NONE);
    if(urlDestination[0] == '\0') {
        sprintf(urlDestination, "Environment variable %s is not set.", itemName);
        Terminate(urlDestination);
    }

    colonPos = strchr(urlDestination, (int)':');
    if(colonPos == null) {
        *portDestination = 80;
    } else {
        *colonPos = '\0';
        *portDestination = atoi(colonPos+1);
        if(*portDestination == 0) {
            sprintf(urlDestination, "Environment variable %s has an invalid port number.", itemName);
            Terminate(urlDestination);
        }
    }

    debug4("Env item: %s = %s, %i", itemName, urlDestination, *portDestination);
}


char NibbleToHex(byte value)
{
    if(value<10) {
        return value+'0';
    } else {
        return value-10+'A';
    }
}


void ByteToHex(byte value, char* buffer)
{
    byte lowNibble;
    byte highNibble;
    
    lowNibble = value & 0x0F;
    highNibble = (value >> 4) & 0x0F;
    
    buffer[0] = NibbleToHex(highNibble);
    buffer[1] = NibbleToHex(lowNibble);
}
