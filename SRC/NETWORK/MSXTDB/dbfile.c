/* MSX trivial dropbox file transfer manager 1.1
   By Konamiman 2/2014

   Compilation command line:
   
   sdcc --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.rel
          asm.lib dbfile.c
   hex2bin -e com dbfile.ihx
   
   ASM.LIB, SHA1.LIB, BASE64.LIB, MSXCHAR.LIB and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com
*/

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
#define _FNEXT 0x41
#define _OPEN 0x43
#define _CREATE 0x44
#define _CLOSE 0x45
#define _DUP 0x47
#define _SEEK 0x4A
#define _READ 0x48
#define _WRITE 0x49
#define _IOCTL 0x4B
#define _ATTR 0x50
#define _HDELETE 0x52
#define _HATTR 0x55
#define _GETCD 0x59
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

#define READ_ONLY_ATTRIBUTE (1)
#define DIRECTORY_ATTRIBUTE (1 << 4)
#define ARCHIVE_ATTRIBUTE (1 << 5)

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

#define SECS_IN_MINUTE ((unsigned long)(60))
#define SECS_IN_HOUR ((unsigned long)(SECS_IN_MINUTE * 60))
#define SECS_IN_DAY ((unsigned long)(SECS_IN_HOUR * 24))
#define SECS_IN_MONTH_28 ((unsigned long)(SECS_IN_DAY * 28))
#define SECS_IN_MONTH_29 ((unsigned long)(SECS_IN_DAY * 29))
#define SECS_IN_MONTH_30 ((unsigned long)(SECS_IN_DAY * 30))
#define SECS_IN_MONTH_31 ((unsigned long)(SECS_IN_DAY * 31))
#define SECS_IN_YEAR ((unsigned long)(SECS_IN_DAY * 365))
#define SECS_IN_LYEAR ((unsigned long)(SECS_IN_DAY * 366))
//Secs from 1970-1-1 to 2010-1-1
#define SECS_1970_TO_2010 ((unsigned long)(1262304000))

#define PrintNewLine() print(strCRLF)
#define LetTcpipBreathe() UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE)

#define HTTP_PORT (80)
#define TICKS_TO_WAIT (20*60)
#define SYSTIMER ((uint*)0xFC9E)
#define TCP_BUFFER_SIZE (2048)
#define TCPOUT_STEP_SIZE (512)
#define JSON_BUF_SIZE (1024)
#define FILE_BUF_SIZE (1024)

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
    "MSX trivial dropbox file transfer manager 1.1\r\n"
    "By Konamiman, 2/2014\r\n"
    "\r\n";
    
const char* strUsage=

    "Usage: dbfile get <remote path> [<local path>] [ex[isting]={skip|write}]\r\n"
    "       dbfile put <local path> <remote path> [a[rchiveonly]={yes|no}]\r\n"
    "\r\n"
    "You can supply paths by using a text file (useful for very long paths).\r\n"
    "Use the syntax 'file:<path filename>' for this.\r\n"
    "\r\n"
    "Non-standard ASCII chars in received paths are converted to UTF8.\r\n"
    "Conversely, you can supply paths with non-standard ASCII char\r\n"
    "if you supply them in an UTF8 encoded file (with 'file:<path filename>'.)\r\n"
    "\r\n"
    "You can use '*' to represent spaces on remote paths.\r\n"
    "\r\n"
    "Please read the user's manual for more details.\r\n";
    
const char* strInvParam = "Invalid parameter";
const char* strNoNetwork = "No network connection available";
const char* strInvJson = "Invalid JSON data received";
const char* strCRLF = "\r\n";
const char* strBadUsrFile = "Invalid user authorization file. Please run DBACC.COM with the \"auth\" parameter.";
const char* strErrorWritingFile = "Error when writing to file: ";
const char* strErrorReadingFile = "Error when reading from file: ";
const char* strWritingFile = "Writing data to file... ";
const char* strOk = "Ok\r\n";
const char* strErrReadTemp = "Error when reading from temporary file: ";
const char* strErrorSearchingFiles = "Error when searching files: ";

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
//char* jsonUpperLimit;
byte jsonNestLevel;
JsonType jsonLastItemType;
char* dataDirectory;
char* token;
char* tokenSecret;
byte fileHandle = 0;
long fileSize;
char* JsonBuffer;
byte* fileBuffer;
byte* fileBufferPointer;
byte* fileBufferUpperLimit;
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
char* ltoaBuffer;
byte listFileHandle;
char* multipartSeparator;
int originalFileNameLength;
bool isGetCommand = false;
bool skipExistingFiles = false;
bool sendArchiveFlaggedFilesOnly = false;
bool zeroContentLengthAnnounced;
char apiContentUrl[256];
int apiContentPort;
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

unsigned long SecsPerMonth[12] = {SECS_IN_MONTH_31, SECS_IN_MONTH_28, SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31, SECS_IN_MONTH_31, SECS_IN_MONTH_30,
    SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31};


    /* Some handy code defines */

#define PrintNewLine() print(strCRLF)
#define LetTcpipBreathe() UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE)
#define SkipCharsWhile(pointer, ch) {while(*pointer == ch) pointer++;}
#define SkipCharsUntil(pointer, ch) {while(*pointer != ch) pointer++;}
#define SkipLF() GetInputByte()
#define ToLowerCase(ch) {ch |= 32;}
#define StringIs(a, b) (strcmpi(a,b)==0)
#define CheckExactArgumentsCount(c) {if(argumentsCount!=c) Terminate(strInvParam);}
#define DecreaseJsonNestLevel() {if(jsonNestLevel == 0) Terminate(strInvJson); else jsonNestLevel--;}
#define CheckExpectedJsonType(real, expected) {if(real!=expected) Terminate(strInvJson);}
#define CheckExactArgumentsCount(c) {if(argumentsCount!=c) Terminate(strInvParam);}
#define IncreaseJsonPointer() jsonPointer++


    /* Function prototypes */

char* PercentEncode(char* src, char* dest, byte encodingType);
void GetDateAndTime(date* destination);
char* GenerateNonce(date* currentDate, char* destination);
char NibbleToHex(byte value);
void ByteToHex(byte value, char* buffer);
void Terminate(const char* errorMessage);
void print(char* s);
char* CopyAndUpdatePointer(char* pointer, char* strToAppend);
void GenerateHttpRequest(bool isDownload, char* resourceRequested, char* params, char* destination);
void Generate2ndPostHttpRequest(char* fileName, char* destination);
void GenerateMultipartSeparator();
void CalculateContentLegth(char* destination, int fileNameLength);
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
void ReadResponseHeaders(bool onlyStatus);
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
//void IncreaseJsonPointer();
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
void ProcessRemoteDirectoryData();
bool GetCurrentFileData(t_RemoteFileInfo* fileInfo, char* itemNameBuffer, char* itemContentBuffer);
void RewindFile(byte fileHandle);
void ReadRemotePath(char* source);
void DoCreateDirectory();
void ReplaceChars(char* string, char charSource, char charDestination);
void ConnectToServer(bool resolveToo);
void DoGetHttpTransaction(char* resourceName, char* fullLocalName);
void OpenTempFilename();
void AppendSlashIfNecessary(char* string);
t_RemoteFileInfo* New_RemoteFileInfo();
void Delete_RemoteFileInfo(t_RemoteFileInfo* pointer);
void ShowFileInformation(t_RemoteFileInfo* fileInfo);
void ShowDirContentsInformation(t_RemoteFileInfo* fileInfo, char* itemNameBuffer, char* itemContentBuffer);
bool PrintShortFileInformation(t_RemoteFileInfo* fileInfo);
char* AdjustString(char* name, int maxLen, bool skipToLastSlash, bool appendSlash);
bool StringIsTrue(char* string);
int StringStartsWith(const char* stringToCheck, const char* startingToken);
int strncmpi(const char *a1, const char *a2, unsigned size);
byte DuplicateFileHandle(byte fileHandle);
void RestoreStandardOutput();
bool OutputIsRedirectedToFile();
void DoFileOperation(char* operationName, FileopType type);
void DoGetFiles();
bool ParseExParameter(char* parameter);
void GetFilenamePart(char* source, char* destination, bool removeFilname);
void DeleteFile(byte fileHandle);
void PrintFileContents(byte fileHandle);
bool StringEndsWith(char* s, char c);
void SubstituteName(char* pathAndOldName, char* newName);
int IndexOf(char* s, char c);
int LastIndexOf(char* s, char c);
byte FourByteHexToUTF8(byte* string, byte* dest);
byte ParseNibble(char nibble);
void UpdateReceivingMessage();
void PrintLongLength(char* message, long length);
char* ltoa(unsigned long num, char *string);
void CombinePaths(char* basePath, char* appendPath, char* destination);
bool IsExistingDirectory(char* localPath);
void BeginReadFile();
bool ReadNextFileLine(char* destination);
void IncreaseFileReadPointer();
void GetOneFile(char* remotePath, char* localName, bool localNameIsDir);
bool IsReadOnlyFile(char* filePath);
void DoSendFiles();
bool ParseAOnlyParameter(char* parameter);
void SendOneFile(t_FileInfoBlock* fib, char* remotePath, bool remotePathIsDir);
void DoPostHttpTransaction(t_FileInfoBlock* fib, char* remoteName);
void ResetArchiveBit(byte attributes, byte fileHandle);
void SendFileData();
void SendMultipartTerminator();
void GetUrlsFromEnvironmentItems();
void ExtractUrlEnvironmentItem(char* itemName, char* urlDestination, int* portDestination);


int main(char** argv, int argc)
{
    void* pointer;
    
    minit();
    
    TcpInputData = malloc(2048);
    ltoaBuffer = malloc(12);
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
    
    if(StringIs(arguments[0], "get")) {
        isGetCommand = true;
        DoGetFiles();
    } else if(StringIs(arguments[0], "put")) {
        DoSendFiles();
    } else {
        Terminate(strInvParam);
    }

    Terminate(null);
    return 0;
}


void GenerateHttpRequest(bool isDownload, char* resourceRequested, char* params, char* destination)
{
    char *contentLengthString=null;

    if(isDownload) {
        sprintf(destination, 
            "GET %s HTTP/1.1\r\n"
            "Host: api-content.dropbox.com\r\n"
            "User-Agent: %s\r\n"
            "Authorization: OAuth oauth_version=\"1.0\", oauth_signature_method=\"PLAINTEXT\", oauth_consumer_key=\"%s\", oauth_token=\"%s\", oauth_signature=\"%s&%s\"\r\n"
            "\r\n",
            resourceRequested,
            userAgent,
            strConsumerKey,
            token,
            strConsumerSecret,
            tokenSecret
        );
    } else {
        contentLengthString = malloc(16);
        CalculateContentLegth(contentLengthString, originalFileNameLength);

        sprintf(destination, 
            "POST %s?%s HTTP/1.1\r\n"
            "Host: api-content.dropbox.com\r\n"
            "Content-Type: multipart/form-data; boundary=%s\r\n"
            "Content-Length: %s\r\n"
            "Expect: 100-continue\r\n"
            "Connection: close\r\n"
            "User-Agent: %s\r\n"
            "Authorization: OAuth oauth_version=\"1.0\", oauth_signature_method=\"PLAINTEXT\", oauth_consumer_key=\"%s\", oauth_token=\"%s\", oauth_signature=\"%s&%s\"\r\n"
            "\r\n",

            resourceRequested,
            params,
            multipartSeparator,
            contentLengthString,
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


void Generate2ndPostHttpRequest(char* fileName, char* destination)
{
    sprintf(destination,
        "--%s\r\n"
        "Content-Disposition: form-data; name=file; filename=%s\r\n"
        "Content-Type: application/octet-stream\r\n"
        "\r\n",
        
        multipartSeparator,
        fileName);
}


void CalculateContentLegth(char* destination, int fileNameLength)
{
    long contentLength;
    
    contentLength =
        //3 + strlen(multipartSeparator) +  //first separator is NOT included in the count!
        1 +   //CRLF after first multipart separator
        52 + fileNameLength + 1 + //"Content-Disposition" header, +1 for CRLF
        38 + 1 + //"Content-Type" header, +1 for CRLF
        1  + //Blank line
        fileSize +
        1 + 2 + strlen(multipartSeparator) + 2 + 1 //Include extra "--" and CRLF before and after
        + 2; //I have no idea where this comes from but it is necessary
    
    ltoa(contentLength, destination);
}


void GenerateMultipartSeparator()
{
    date currentDate;
    GetDateAndTime(&currentDate);
    
    strcpy(multipartSeparator, "----------MsX_tr1v1al_dropBOX---");
    GenerateNonce(&currentDate, &multipartSeparator[strlen(multipartSeparator)]);
}


//encodingType values:
//0: simple (nonsafe chars are encoded as '%'+hex value)
//1: standard (same as simple, but space is encoded as '+')
//2: double (simple over simple: nonsafe chars are encoded as '%25'+hex value)
//3: Simple, but '/' is preserved
//4: Simple, but '=' and '&' are preserved
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
        } else if((value=='=' || value=='&') && encodingType == 4) {
            *dest++ = value;
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


void GetDateAndTime(date* destination)
{
    /*
    destination->Year = 2020;
    destination->Month = 1;
    destination->Day = 1;
    destination->Hour = 0;
    destination->Minute = 0;
    destination->Second = 0;
    */
    
    DosCall(_GDATE, &regs, REGS_NONE, REGS_MAIN);
    destination->Year = regs.Words.HL;
    destination->Month = regs.Bytes.D;
    destination->Day = regs.Bytes.E;
    if(destination->Year < 2011) {
        Terminate("Your MSX seems to not have the clock properly adjusted.\r\n    Please adjust it and try again.");
    }

    DosCall(_GTIME, &regs, REGS_NONE, REGS_MAIN);
    destination->Hour = regs.Bytes.H;
    destination->Minute = regs.Bytes.L;
    destination->Second = regs.Bytes.D;
}


char* GenerateNonce(date* currentDate, char* destination)
{
    //strcpy(destination, "NONCE");
    sprintf(destination, "MSX-%i%i%i-%i%i%i-%i", currentDate->Year, currentDate->Month, currentDate->Day, currentDate->Hour, currentDate->Minute, currentDate->Second, *SYSTIMER);
    return destination;
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


void Terminate(const char* errorMessage)
{
    terminating = true;

    if(errorMessage != NULL) {
        printf("\r\x1BK*** %s\r\n", errorMessage);
    }
    
    CloseTcpConnection();
    if(fileHandle != 0) {
        if(isGetCommand) {
            DeleteFile(fileHandle);
        } else {
            CloseFile(fileHandle);
        }
    }
    if(listFileHandle != 0) {
        CloseFile(listFileHandle);
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


char* CopyAndUpdatePointer(char* pointer, char* strToAppend)
{
    strcpy(pointer, strToAppend);
    pointer += strlen(strToAppend);
    return pointer;
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
    char* url = malloc(256);
    strcpy(url, apiContentUrl);
    debug2("Resolving: %s", url);

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
    
    TcpConnectionParameters->remotePort = apiContentPort;

    print(" Ok\r\n");
    mfree(Buffer);
    mfree(url);
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
        minit();
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
        minit();
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


void ReadResponseHeaders(bool onlyStatus)
{
    headerLine = malloc(512);
    responseStatus = malloc(512);
    statusLine = malloc(512);

    emptyLineReaded = 0;
    zeroContentLengthAnnounced = false;
    
    ReadResponseStatus();
    
    if(!onlyStatus) {
        while(!emptyLineReaded) {
            ReadNextHeader();
            ProcessNextHeader();
        }
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
        if(contentLength == 0) {
            zeroContentLengthAnnounced = true;
        }
        return;
    }
    
    if(StringIs(headerTitle, "Transfer-Encoding") && StringIs(headerContents, "Chunked")) {
        isChunkedTransfer = true;
        debug("Chunked encoding");
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
        Terminate("Too many directory entries");
    } else if(responseStatusCode == 304) {
        directoryChanged = false;
        return;
    } else if(responseStatusCodeFirstDigit != 2 && responseStatusCodeFirstDigit != 1) {
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
    
    JsonBuffer = malloc(4096);
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

    if(zeroContentLengthAnnounced) {
        return;
    }

    receivedLength = 0;
    while(contentLength == 0 || receivedLength < contentLength) {
        EnsureThereIsTcpDataAvailable();
        receivedLength += remainingInputData;
        if(fileHandle == 0) {
            copy(pointer, inputDataPointer, remainingInputData);
            pointer += remainingInputData;
        } else {
            UpdateReceivingMessage();
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
            copy(pointer, inputDataPointer, chunkSizeInBuffer);
            pointer += chunkSizeInBuffer;
            contentLength += chunkSizeInBuffer;
        } else {
      	    UpdateReceivingMessage();
            WriteToFile(fileHandle, inputDataPointer, chunkSizeInBuffer, strErrorWritingFile);
        }
        inputDataPointer += chunkSizeInBuffer;
        currentChunkSize -= chunkSizeInBuffer;
        remainingInputData -= chunkSizeInBuffer;
    }
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

    //jsonUpperLimit = JsonBuffer + JSON_BUF_SIZE;
    jsonNestLevel = 0;
    jsonLastItemType = JSON_NONE;
    
    jsonPointer = JsonBuffer;
    
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


/*
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
*/


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

    regs.Words.HL = (int)"PROGRAM";
    regs.Words.DE = (int)dataDirectory;
    regs.Bytes.B = 128;
    DosCall(_GENV, &regs, REGS_MAIN, REGS_NONE);

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
	ld  a,h
	cp  #0x84    ;Also moan if below 8400h (ADDED FOR THIS PROGRAM!!)
	jp	c,not_enuf_ram		;Also moan if below 8000h.
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
        printf("File path: %s\r\n", remotePath);
        CloseFile(fileHandle);
        fileHandle = 0;
    } else {
        strcpy(remotePath, source);    
    }
    
    ReplaceChars(remotePath, '\\', '/');
    ReplaceChars(remotePath, '*', ' ');
    
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


void ConnectToServer(bool resolveToo)
{
    if(resolveToo) {
        ResolveServerName();
    }
    print("Connecting to server... ");
    OpenTcpConnection();
    print(strOk);
}


void DoGetHttpTransaction(char* resourceName, char* fullLocalName)
{
    char* httpRequest;
    
    print("Starting transfer... ");
    httpRequest = malloc(1024);
    GenerateHttpRequest(true, resourceName, null, httpRequest);
    SendTcpData(httpRequest, strlen(httpRequest));
    mfree(httpRequest);
    ReadResponseHeaders(false);
    print(strOk);
    
    fileHandle = CreateFile(fullLocalName, "Error when creating local file: ");
    
    if(!isChunkedTransfer && contentLength!=0) {
        print("File size: ");
        PrintSize(contentLength);
        PrintNewLine();
    }
    print("Receiving data... ");
    JsonBuffer = malloc(JSON_BUF_SIZE);
    DownloadHttpContents();
    print(strOk);
    CloseFile(fileHandle);
}


void AppendSlashIfNecessary(char* string)
{
    int len = strlen(string);
    if(string[len-1] != '\\') {
        string[len] = '\\';
        string[len+1] = '\0';
    }
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


void DoGetFiles()
{
    char* localName = malloc(64);
    char* remotePathOrFile = arguments[1];
    bool localNameIsDir;

    ReadTokenFromFile();
    ReplaceChars(remotePathOrFile, '\\', '/');
    ReplaceChars(remotePathOrFile, '*', ' ');
    
    if(argumentsCount == 2) {
        //0="get", 1=remote
        *localName='\0';
        //regs.Bytes.B = 0;
        //regs.Words.DE = (int)localName;
        //DosCall(_GETCD, &regs, REGS_MAIN, REGS_NONE);
    } else if(argumentsCount == 3) {
        if(ParseExParameter(arguments[2])) {
            //0="get", 1=remote, 2="ex=...";
            *localName='\0';
            //regs.Bytes.B = 0;
            //regs.Words.DE = (int)localName;
            //DosCall(_GETCD, &regs, REGS_MAIN, REGS_NONE);
        } else {
            //0="get", 1=remote, 2=local
            strcpy(localName, arguments[2]);
        }
    } else if(argumentsCount == 4) {
        //0="get", 1=remote, 2=local, 3="ex=...";
        strcpy(localName, arguments[2]);
        if(!ParseExParameter(arguments[3])) {
            Terminate(strInvParam);
        }
    } else {
        Terminate(strInvParam);
    }
    
    ReplaceChars(localName, '/', '\\');
    localNameIsDir = IsExistingDirectory(localName);
    
    remotePath = malloc(260);
    remotePath++;
    if(StringStartsWith(remotePathOrFile, "file:")) {
        listFileHandle = OpenFile(remotePathOrFile + 5, "Error when opening URLs file: ");
        BeginReadFile();
        if(ReadNextFileLine(remotePath)) {
            GetOneFile(remotePath, localName, localNameIsDir);
        }
        if(ReadNextFileLine(remotePath)) {
            if(!localNameIsDir) {
                Terminate("When using a URLs file, if the local path is not a directory,\r\n    only the first file in the list is downloaded.");
            }
            GetOneFile(remotePath, localName, localNameIsDir);
            while(ReadNextFileLine(remotePath)) {
                GetOneFile(remotePath, localName, localNameIsDir);
            }
        }
    } else {
        strcpy(remotePath, remotePathOrFile);
        GetOneFile(remotePath, localName, localNameIsDir);
    }
   
    //Program terminates right after this, so no mfrees necessary
}


bool ParseExParameter(char* parameter)
{
    char* value;

    if(StringStartsWith(parameter,"ex=")) {
        value = &parameter[3];
    } else if(StringStartsWith(parameter,"existing=")) {
        value = &parameter[9];
    } else {
        return false;
    }
    
    if(StringIs(value, "skip")) {
        skipExistingFiles = true;
    } else if(!StringIs(value, "write")) {
        Terminate(strInvParam);
    }
    
    return true;
}


void GetOneFile(char* remotePath, char* localName, bool localNameIsDir)
{
    char* fullLocalName = malloc(256);
    char* remoteFilenamePart = malloc(256);
    char* escapedPath = malloc(512);
    char* resourceName = malloc(512);
    bool fileExists;
    
    if(conn == 0) {
        ConnectToServer(true);
    }
    
    if(*remotePath != '/') {
        remotePath--;
        *remotePath = '/';
    }
    
    printf("\r\n>>> File '%s'", remotePath);
    
    if(*localName == '\0' || StringIs(localName, ".")) {
        GetFilenamePart(remotePath, remoteFilenamePart, false);
        strcpy(fullLocalName, remoteFilenamePart);
    } else if(localNameIsDir) {
        GetFilenamePart(remotePath, remoteFilenamePart, false);
        CombinePaths(localName, remoteFilenamePart, fullLocalName);
    } else {
        strcpy(fullLocalName, localName);
    }
    
    ReplaceChars(fullLocalName, '/', '\\');
    
    fileExists = FileExists(fullLocalName);
    if(fileExists && skipExistingFiles) {
        print(" - skipped (existing)\r\n");
    } else if(fileExists && IsReadOnlyFile(fullLocalName)) {
        print(" - skipped (read only file)\r\n");
    } else {
        PrintNewLine();
    
        ReplaceChars(remotePath, '\\', '/');
        ReplaceChars(remotePath, '*', ' ');
        
        PercentEncode(remotePath + 1, escapedPath, 3);
        strcpy(resourceName, "/1/files/dropbox/");
        strcat(resourceName, escapedPath);
        
        DoGetHttpTransaction(resourceName, fullLocalName);
    }
        
    mfree(resourceName);
    mfree(escapedPath);
    mfree(remoteFilenamePart);
    mfree(fullLocalName);
}


bool IsReadOnlyFile(char* filePath)
{
    regs.Words.DE = (int)filePath;
    regs.Bytes.A = 0;
    DosCall(_ATTR, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when checking file attributes: ", regs.Bytes.A);
    }
    
    return ((regs.Bytes.L & READ_ONLY_ATTRIBUTE) != 0);
}


void GetFilenamePart(char* source, char* destination, bool removeFilname)
{
    int len = strlen(source);
    char* pointer = source + len - 1;

    if(*pointer == '/' || *pointer == '\\') {
        Terminate("Invalid remote file name");
    }
    
    while(true) {
        if(*pointer == '/' || *pointer == '\\' || len == 0) {
            pointer++;
            break;
        }
        pointer--;
        len--;
    }
    
    strcpy(destination, pointer);
    if(removeFilname) {
        *pointer = '\0';
    }
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


void UpdateReceivingMessage()
{
    if(fileHandle != 0) {
        PrintLongLength("\rDownloading... ", receivedLength);
        print(" ");
    }
}


void PrintLongLength(char* message, long length)
{
    long kbytes;
    int bytes;
    
    print(message);
    
    kbytes = length / 1024;
    bytes = length % 1024;
    if(bytes >= 512) {
        kbytes++;
    }
    printf("%s KBytes", ltoa(kbytes, ltoaBuffer));
}


char* ltoa(unsigned long num, char *string)
{
    char* pointer = string;
    int nonZeroProcessed = 0;
    unsigned long power = 1000000000;
    unsigned char digit = 0;
    
    while(power > 0) {
        digit = num / power;
        num = num % power;
        if(digit == 0 && nonZeroProcessed) {
            *pointer++ = '0';
        } else if(digit !=0) {
            nonZeroProcessed = 1;
            *pointer++ = (char)digit + '0';
        }
        power /= 10;
    }
    
    if(!nonZeroProcessed) {
        *pointer++ = '0';
    }
    
    *pointer = '\0';
    
    return string;
}


void CombinePaths(char* basePath, char* appendPath, char* destination)
{
    int baseLen;
    char value;

    if(destination == null) {
        destination = basePath;
    } else {
        strcpy(destination, basePath);    
    }
    
    baseLen = strlen(destination);
    value = destination[baseLen - 1];
    if(value != '\\' && value != '/') {
        destination[baseLen] = '/';
        destination[baseLen+1] = '\0';
    }
    
    if(*appendPath == '\\' || *appendPath == '/') {
        appendPath++;
    }
    
    strcat(destination, appendPath);
}


bool IsExistingDirectory(char* localPath)
{
    bool isDir;
    t_FileInfoBlock* fib;
    char value;
    
    if(*localPath == '\0') {
        return true;
    }
    value = localPath[strlen(localPath) - 1];
    if(value == ':' || value == '/' || value == '\\') {
        return true;
    }
    
    fib = malloc(sizeof(t_FileInfoBlock));

    regs.Words.DE = (int)localPath;
    regs.Bytes.B = DIRECTORY_ATTRIBUTE;
    regs.Words.IX = (int)fib;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
    if(regs.Bytes.A == _NOFIL) {
        return false;
    } else if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when checking local directory: ", regs.Bytes.A);
    }
    
    isDir = (fib->attributes & DIRECTORY_ATTRIBUTE) != 0;
    mfree(fib);
    return isDir;
}


void BeginReadFile()
{
    fileBuffer = malloc(FILE_BUF_SIZE);
    fileBufferUpperLimit = fileBuffer + FILE_BUF_SIZE - 1;
    fileBufferPointer = fileBufferUpperLimit;
    IncreaseFileReadPointer();
}


bool ReadNextFileLine(char* destination)
{
    int len = 0;

    while(true) {
        *destination = *fileBufferPointer;
        IncreaseFileReadPointer();
        if(*destination =='\0') {
            return false;
        } else if(*destination == 13) {
            *destination = '\0';
            IncreaseFileReadPointer(); //skip LF
            return true;
        }
        destination++;
        len++;
        if(len > 256) {
            Terminate("Remote path too long, maximum supported is 256 characters");
        }
    }
}


void IncreaseFileReadPointer()
{
    int readed;
    
    if(fileBufferPointer == fileBufferUpperLimit) {
        readed = ReadFromFile(listFileHandle, fileBuffer, FILE_BUF_SIZE, strErrorReadingFile);
        if(readed != FILE_BUF_SIZE) {
            fileBuffer[readed] = '\0';
        }
        fileBufferPointer = fileBuffer;
    } else {
        fileBufferPointer++;
    }
}


void DoSendFiles()
{
    char* localFileMask = arguments[1];
    char* remotePathOrFile = arguments[2];
    t_FileInfoBlock* fib = malloc(64);
    bool localNameIsAmbiguous;
    bool remotePathIsDir;
    int cnt = 0;
    int i;
    long chksum1, chksum2;

    if(argumentsCount == 4) {
        ParseAOnlyParameter(arguments[3]);
    } else {
        CheckExactArgumentsCount(3);
    }
    ReadRemotePath(arguments[2]);

    ReadTokenFromFile();
    ReplaceChars(localFileMask, '/', '\\');

    regs.Bytes.B = 0;
    regs.Words.DE = (int)localFileMask;
    DosCall(_PARSE, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when parsing local path: ", regs.Bytes.A);
    }
    localNameIsAmbiguous = ((regs.Bytes.B & ARCHIVE_ATTRIBUTE) != 0);
    
    remotePathIsDir = StringEndsWith(remotePath, '/');
    
    if(localNameIsAmbiguous && !remotePathIsDir) {
        Terminate("When more than one file is sent, the remote path must represent a directory\r\n    (it must end with a slash, '/')");
    }
    
    regs.Words.DE = (int)localFileMask;
    regs.Bytes.B = 0;
    regs.Words.IX = (int)fib;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode(strErrorSearchingFiles, regs.Bytes.A);
    }
    
    multipartSeparator = malloc(64);
    GenerateMultipartSeparator();
    JsonBuffer = malloc(1024);
    ResolveServerName();
    do {
        SendOneFile(fib, remotePath, remotePathIsDir);

        regs.Words.IX = (int)fib;
        DosCall(_FNEXT, &regs, REGS_ALL, REGS_AF);
        if((regs.Bytes.A != 0) && (regs.Bytes.A != _NOFIL)) {
            TerminateWithDosErrorCode(strErrorSearchingFiles, regs.Bytes.A);
        }
    } while(regs.Bytes.A != _NOFIL);
  
    //Program terminates right after this, so no mfrees necessary
}


bool ParseAOnlyParameter(char* parameter)
{
    char* value;

    if(StringStartsWith(parameter,"a=")) {
        value = &parameter[2];
    } else if(StringStartsWith(parameter,"archiveonly=")) {
        value = &parameter[12];
    } else {
        return false;
    }
    
    if(StringIs(value, "yes")) {
        sendArchiveFlaggedFilesOnly = true;
    } else if(!StringIs(value, "no")) {
        Terminate(strInvParam);
    }
    
    return true;
}


void SendOneFile(t_FileInfoBlock* fib, char* remotePath, bool remotePathIsDir)
{
    char* fullRemoteName = malloc(256);
    char* escapedPath = malloc(512);
    char* resourceName = malloc(512);
    char* escapedLocalName = malloc(48);
    
    fileSize = fib->fileSize;
    PercentEncode(fib->filename, escapedLocalName, 0);

    printf("\r\n>>> File '%s'", fib->filename);
    
    if(sendArchiveFlaggedFilesOnly && ((fib->attributes & ARCHIVE_ATTRIBUTE) == 0)) {
        print(" - skipped (archive attribute not set)\r\n");
        mfree(escapedLocalName);
        mfree(resourceName);
        mfree(escapedPath);
        return;
    }
    PrintNewLine();
    
    ConnectToServer(false);
    ResetTcpBuffer();
    if(remotePathIsDir) {
        CombinePaths(remotePath, fib->filename, fullRemoteName);
    } else {
        strcpy(fullRemoteName, remotePath);
    }
    
    mfree(escapedLocalName);
    mfree(resourceName);
    mfree(escapedPath);
    DoPostHttpTransaction(fib, fullRemoteName);
    
    mfree(fullRemoteName);
    CloseTcpConnection();
}


void DoPostHttpTransaction(t_FileInfoBlock* fib, char* remoteName)
{
    char* httpRequest = malloc(2048);
    char* fileNamePart = malloc(256);
    char* paramsBeforeOauth = malloc(512);
    char* directoryName = malloc(512);
    char* resourceName = malloc(512);
    
    print("Starting transfer... ");
    GetFilenamePart(remoteName, fileNamePart, true);
    strcpy(paramsBeforeOauth, "file=");
    PercentEncode(fileNamePart, paramsBeforeOauth+5, 1);
    PercentEncode(remoteName, directoryName, 3);
    CombinePaths("/1/files/dropbox/", directoryName, resourceName);
    
    originalFileNameLength = strlen(fileNamePart);
    GenerateHttpRequest(false, resourceName, paramsBeforeOauth, httpRequest);
    SendTcpData(httpRequest, strlen(httpRequest));
    mfree(resourceName);
    mfree(directoryName);
    print(strOk);
    
    ReadResponseHeaders(false);  //We expect "100-continue" here
    Generate2ndPostHttpRequest(/*&paramsBeforeOauth[5]*/ fileNamePart, httpRequest);
    SendTcpData(httpRequest, strlen(httpRequest));
    mfree(paramsBeforeOauth);
    mfree(fileNamePart);
    mfree(httpRequest);
    
    fileHandle = OpenFile((char*)fib, "Error when opening file: ");
    
    print("File size: ");
    PrintSize(fileSize);
    PrintNewLine();
    print("Uploading... ");
    SendFileData();
    SendMultipartTerminator();
    print(strOk);
    
    print("Receiving response... ");
    ReadResponseHeaders(false);  //Now we should receive "200-ok"...
    //DownloadHttpContents(); //...followed by some funny but useless JSON data (ignored since connection is closed anyway)

    if(sendArchiveFlaggedFilesOnly) {
        ResetArchiveBit(fib->attributes, fileHandle);
    }
    
    CloseFile(fileHandle);
    fileHandle = 0;
    
    print(strOk);
}


void ResetArchiveBit(byte attributes, byte fileHandle)
{
    attributes &= ~ARCHIVE_ATTRIBUTE;

    regs.Bytes.B = (byte)fileHandle;
    regs.Bytes.A = 1;
    regs.Bytes.L = attributes;
    DosCall(_HATTR, &regs, REGS_MAIN, REGS_AF);

    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when changing file attributes: ", regs.Bytes.A);
    }
}


void SendFileData()
{
    int readed;
    long sent = 0;

    fileBuffer = malloc(FILE_BUF_SIZE);
    while(true) {
        readed = ReadFromFile(fileHandle, fileBuffer, FILE_BUF_SIZE, strErrorReadingFile);
        if(readed == 0) {
            break;
        }
        sent += readed;
        SendTcpData(fileBuffer, readed);
        PrintLongLength("\rUploading... ", sent);
        print(" ");
    }
    mfree(fileBuffer);
}


void SendMultipartTerminator()
{
    char* buffer = malloc(70);
    sprintf(buffer, "\r\n--%s--\r\n", multipartSeparator);
    SendTcpData(buffer, strlen(buffer));
    mfree(buffer);
}


void GetUrlsFromEnvironmentItems()
{
    //ExtractUrlEnvironmentItem("DROPBOX_API_URL", apiUrl, &apiPort);
    ExtractUrlEnvironmentItem("DROPBOX_API_CONTENT_URL", apiContentUrl, &apiContentPort);

    debug2("API url: %s", apiContentUrl);
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