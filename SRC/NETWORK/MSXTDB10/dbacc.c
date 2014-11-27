/* MSX trivial dropbox account manager 1.0
   By Konamiman 1/2011

   Compilation command line:
   
   sdcc --code-loc 0x170 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.rel base64.lib
          sha1.lib asm.lib dbacc.c
   hex2bin -e com dbacc.ihx
   
   ASM.LIB, SHA1.LIB, BASE64.LIB, MSXCHAR.LIB and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com
*/


/*
NOTE: If you want to compile this code and actually use it,
you will need to register a new application in the Dropbox site
and then put the supplied application key token and secret
in the strConsumerKey and strConsumerSecret variables.
It is not allowed to share the keys of an existing application
so I had to remove them from the published source.
*/


//#define DEBUG

#ifdef DEBUG
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
#include "sha1.h"
#include "hmac-sha1.h"
#include "base64.h"


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


/* Defines */

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
#define _SEEK 0x4A
#define _READ 0x48
#define _WRITE 0x49
#define _IOCTL 0x4B
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
#define TCP_BUFFER_SIZE (1024)
#define TCPOUT_STEP_SIZE (512)

//#define Buffer ((void*)0x8000)
#define JsonBuffer ((void*)(0x8000 + TCP_BUFFER_SIZE))

typedef enum {
    JSON_NONE,
    JSON_DATA,
    JSON_OBJECT_START,
    JSON_OBJECT_END,
    JSON_ARRAY_START,
    JSON_ARRAY_END
} JsonType;


/* Strings */

const char* strTitle=
    "MSX trivial dropbox account manager 1.0\r\n"
    "By Konamiman, 1/2011\r\n"
    "\r\n";
    
const char* strUsage=
    "Usage: dbacc auth <email> <password>\r\n"
    "       dbacc new <first name> <last name> <email> <password>\r\n"
    "       dbacc info [raw]\r\n"
    "\r\n"
    "It is necessary to create a user authorization file with 'auth' in order\r\n"
    "to perform any other operation with the MSX trivial dropbox suite.\r\n"
    "\r\n"
    "You can use \"@\" to represent spaces in the first and last names\r\n"
    "when creating a new Dropbox account with 'new'.\r\n"
    "\r\n"
    "Please ensure that your MSX clock is up to date.\r\n"
    "\r\n"
    "Please read the user's manual for more details.\r\n";
    
const char* strInvParam = "Invalid parameter";
const char* strNoNetwork = "No network connection available";
const char* strInvJson = "Invalid JSON data received";
const char* strCRLF = "\r\n";
const char* strBadUsrFile = "Invalid user authorization file. Please run the application with the \"auth\" parameter.";

const char* strConsumerKey = "[YOUR_APP_KEY_HERE]";
const char* strConsumerSecret = "[YOUR_APP_SECRET_HERE]";


/* Global variables */

Z80_registers regs;
unapi_code_block codeBlock;
t_TcpConnectionParameters TcpConnectionParameters;
byte conn = 0;
int ticksWaited;
int sysTimerHold;
int remainingInputData = 0;
byte* inputDataPointer;
byte* TcpInputData;
#define TcpOutputData TcpInputData;
char** arguments;
int argumentsCount;
char userAgent[130];
bool directoryChanged;
int emptyLineReaded;
long contentLength;
int isChunkedTransfer;
long currentChunkSize = 0;
byte headerLine[256];
byte responseStatus[256];
char statusLine[256];
int responseStatusCode;
int responseStatusCodeFirstDigit;
char* headerTitle;
char* headerContents;
long receivedLength = 0;
bool requestingToken = false;
char* jsonPointer;
byte jsonNestLevel;
JsonType jsonLastItemType;
char dataDirectory[64];
char token[64];
char tokenSecret[64];
byte* Buffer;
byte ParseAndDivideBy1024Buffer[5];

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
#define CheckJsonCharIs(c) {if(*jsonPointer++ != c) Terminate(strInvJson);}
#define DecreaseJsonNestLevel() {if(jsonNestLevel == 0) Terminate(strInvJson); else jsonNestLevel--;}
#define CheckExpectedJsonType(real, expected) {if(real!=expected) Terminate(strInvJson);}


    /* Function prototypes */

void CreateSignatureBaseString(char* verb, char* resourceRequested, char* paramsBeforeO, char* paramsAfterO, char* destination, char* nonce, char* timestamp);
char* PercentEncode(char* src, char* dest, byte encodingType);
char* GenerateTimestamp(date* currentDate, char* destination);
void GetDateAndTime(date* destination);
char* GenerateNonce(date* currentDate, char* destination);
char NibbleToHex(byte value);
void ByteToHex(byte value, char* buffer);
void Terminate(const char* errorMessage);
void print(char* s);
char* CopyAndUpdatePointer(char* pointer, char* strToAppend);
void GenerateHttpRequest(char* verb, char* resourceRequested, char* paramsBeforeO, char* paramsAfterO, char* destination, char* workArea);
void InitializeTcpipUnapi();
void ResolveServerName(bool apiContentName);
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
void DoAuthorization();
void DoAuthorizationCore(char* email, char* password);
void ProcessAuthorizationData();
int ComposeAuthHttpRequest(char* email, char* password);
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
void ResetTcpBuffer();
long GetNextChunkSize();
JsonType JsonInit();
bool JsonDataAvailable();
JsonType JsonGetNextItem(char* name, char* value);
void JsonExtractValue(char* destination, bool isString);
void JsonSkipWhitespaceCharsAndCommas();
void GetDataDirectory();
void GetDataFilePath(char* fileName, char* destination);
byte CreateFile(char* path, char* errorMessage);
void WriteToFile(byte handle, byte* data, int length, char* errorMessage);
void CloseFile(byte handle);
void TerminateWithDosErrorCode(char* message, byte errorCode);
char* ExplainDosErrorCode(byte code, char* destination);
void DoGetAccountInfo();
void ProcessInfoData();
byte OpenFile(char* path, char* errorMessage);
int ReadFromFile(byte fileHandle, byte* destination, int length, char* errorMessage);
void ReadTokenFromFile();
void ParseFileLine(byte** src, byte* dest, int maxLength);
long ParseAndDivideBy1024(char* numberString);
void PrintSize(char* size);
void PrintSizeInK(unsigned long size);
void ChangeAtsToSpaces(char* string);
void DoNewAccount();
bool HasOnlyAsciiChars(char* string);
int ComposeNewAccountHttpRequest();
bool FileExists(char* path);

int main(char** argv, int argc)
{
    Buffer = ((byte*)0x8000);
    TcpInputData = Buffer;
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
    
    if(StringIs(arguments[0], "auth")) {
        DoAuthorization();
    } else if(StringIs(arguments[0], "new")) {
        DoNewAccount();
    } else if(StringIs(arguments[0], "info")) {
        DoGetAccountInfo();
    } else {
        Terminate(strInvParam);
    }

    Terminate(null);
    return 0;
}



void CreateSignatureBaseString(char* verb, char* resourceRequested, char* paramsBeforeO, char* paramsAfterO, char* destination, char* nonce, char* timestamp)
{
    char* pointer = destination;
    
    pointer = CopyAndUpdatePointer(pointer, verb);
    pointer = CopyAndUpdatePointer(pointer, "&http%3A%2F%2Fapi.dropbox.com");

    PercentEncode(resourceRequested, pointer, 0);
    pointer += strlen(pointer);
    
    *pointer = '&';
    pointer++;

    if(paramsBeforeO != null) {
        PercentEncode(paramsBeforeO, pointer, 0);
        pointer += strlen(pointer);
        pointer = CopyAndUpdatePointer(pointer, "%26");
    }

    pointer = CopyAndUpdatePointer(pointer, "oauth_consumer_key%3D");
    pointer = CopyAndUpdatePointer(pointer, strConsumerKey);

    pointer = CopyAndUpdatePointer(pointer, "%26oauth_nonce%3D");
    pointer = CopyAndUpdatePointer(pointer, nonce);
   
    pointer = CopyAndUpdatePointer(pointer, "%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D");
    pointer = CopyAndUpdatePointer(pointer, timestamp);
    
    if(*token != '\0') {
        pointer = CopyAndUpdatePointer(pointer, "%26oauth_token%3D");
        pointer = CopyAndUpdatePointer(pointer, token);
    }
    pointer = CopyAndUpdatePointer(pointer, "%26oauth_version%3D1.0");
    
    if(paramsAfterO != null) {
        strcpy(pointer, "%26");
        pointer += 3;
        PercentEncode(paramsAfterO, pointer, 0);
        pointer += strlen(pointer);
    }

    *pointer= '\0';
}


void GenerateHttpRequest(char* verb, char* resourceRequested, char* paramsBeforeO, char* paramsAfterO, char* destination, char* workArea)
{
    #define tempPointer unencodedSignature
    
    char *timestamp, *signatureBaseString, *signatureKey, *unencodedSignature, *base64Signature, *percentEncodedSignature, *requestParameters;
    int signatureKeyLength, baseStringLength, encodedSignatureLength;
    date currentDate;
    
    GetDateAndTime(&currentDate);
    
    GenerateNonce(&currentDate, workArea);
    timestamp = workArea + strlen(workArea) + 1;
    
    GenerateTimestamp(&currentDate, timestamp);
    signatureBaseString = timestamp + strlen(timestamp) + 1;

    CreateSignatureBaseString(verb, resourceRequested, paramsBeforeO, paramsAfterO, signatureBaseString, workArea, timestamp);
    debug(signatureBaseString);
    
    baseStringLength = strlen(signatureBaseString);
    signatureKey = signatureBaseString + baseStringLength + 1;

    sprintf(signatureKey, "%s&%s", strConsumerSecret, tokenSecret);
    signatureKeyLength = strlen(signatureKey);
    unencodedSignature = signatureKey + signatureKeyLength + 1;

    hmac_sha1(signatureKey, signatureKeyLength, signatureBaseString, baseStringLength, unencodedSignature);
    base64Signature = unencodedSignature + 20;

    Base64Init(0);
    encodedSignatureLength = Base64EncodeChunk(unencodedSignature, base64Signature, 20, 1);
    base64Signature[encodedSignatureLength] = '\0';

    percentEncodedSignature = base64Signature + encodedSignatureLength + 1;
    PercentEncode(base64Signature, percentEncodedSignature, 0);

    if((paramsBeforeO == null) && (paramsAfterO == null)) {
        requestParameters = "?";
    } else {
        requestParameters = percentEncodedSignature + strlen(percentEncodedSignature) + 1;
        tempPointer = requestParameters;
        *tempPointer++ = '?';
        if(paramsBeforeO != null) {
            tempPointer = CopyAndUpdatePointer(tempPointer, paramsBeforeO);
            if(paramsAfterO != null) {
                *tempPointer++ = '&';
                tempPointer = CopyAndUpdatePointer(tempPointer, paramsAfterO);
                *tempPointer++ = '&';
                *tempPointer = '\0';
            }
        } else if(paramsAfterO != null) {
            tempPointer = CopyAndUpdatePointer(tempPointer, paramsAfterO);
            *tempPointer++ = '&';
            *tempPointer = '\0';
        }
    }

    if(*token == '\0') {
        sprintf(destination,
            "%s %s%soauth_consumer_key=%s&oauth_nonce=%s&oauth_signature_method=HMAC-SHA1&oauth_timestamp=%s&oauth_signature=%s&oauth_version=1.0 HTTP/1.1\r\n"
            "Host: api.dropbox.com\r\n"
            "%s\r\n"
            "\r\n",
            
            verb,
            resourceRequested,
            requestParameters,
            
            strConsumerKey,
            workArea,
            timestamp,
            percentEncodedSignature,
            userAgent
            );
    } else {
        sprintf(destination,
            "%s %s%soauth_consumer_key=%s&oauth_token=%s&oauth_nonce=%s&oauth_signature_method=HMAC-SHA1&oauth_timestamp=%s&oauth_signature=%s&oauth_version=1.0 HTTP/1.1\r\n"
            "Host: api.dropbox.com\r\n"
            "%s\r\n"
            "\r\n",
            
            verb,
            resourceRequested,
            requestParameters,
            
            strConsumerKey,
            token,
            workArea,
            timestamp,
            percentEncodedSignature,
            userAgent
        );
    }
}


//encodingType values:
//0: simple (nonsafe chars are encoded as '%'+hex value)
//1: standard (same as simple, but space is encoded as '+')
//2: double (simple over simple: nonsafe chars are encoded as '%25'+hex value)
char* PercentEncode(char* src, char* dest, byte encodingType)
{
    char value;

    while((value = *src) != '\0') {
        if(value==' ' && encodingType == 1) {
            *dest++ = '+';
        } else if(islower(value) || isupper(value) || isdigit(value) || value=='-' || value=='.' || value=='_' || value=='~') {
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


char* GenerateTimestamp(date* currentDate, char* destination)
{
    unsigned long seconds = SECS_1970_TO_2010;
    byte isLeapYear;
    int loopValue;

    seconds = SECS_1970_TO_2010;

    //* Years

    loopValue = 2010;
    while(loopValue < currentDate->Year) {
        isLeapYear = (loopValue & 3) == 0;
        seconds += (isLeapYear ? SECS_IN_LYEAR : SECS_IN_YEAR);
        loopValue++;
    }
    
    //* Months
    
    isLeapYear = (currentDate->Year & 3) == 0;
    loopValue = 1;
    while(loopValue < currentDate->Month) {
        if(isLeapYear && (loopValue == 2)) {
            seconds += SECS_IN_MONTH_29;
        } else {
            seconds += SecsPerMonth[loopValue-1];
        }
        loopValue++;
    }
    
    //* Rest of parameters
    
    seconds += (SECS_IN_DAY) * (currentDate->Day-1);
    seconds += (SECS_IN_HOUR) * currentDate->Hour;
    seconds += (SECS_IN_MINUTE) * currentDate->Minute;
    seconds += currentDate->Second;
    
    _ultoa(seconds, destination, 10);
    return destination;
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
    if(errorMessage != NULL) {
        printf("\r\x1BK*** %s\r\n", errorMessage);
    }
    
    CloseTcpConnection();
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

    TcpConnectionParameters.remotePort = HTTP_PORT;
    TcpConnectionParameters.localPort = 0xFFFF;
    TcpConnectionParameters.userTimeout = 0;
    TcpConnectionParameters.flags = 0;
}


void ResolveServerName(bool apiContentName)
{
    print("Resolving server name...");
    regs.Words.HL = apiContentName ? (int)"api-content.dropbox.com" : (int)"api.dropbox.com";
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
    
    TcpConnectionParameters.remoteIP[0] = regs.Bytes.L;
    TcpConnectionParameters.remoteIP[1] = regs.Bytes.H;
    TcpConnectionParameters.remoteIP[2] = regs.Bytes.E;
    TcpConnectionParameters.remoteIP[3] = regs.Bytes.D;
    
    print(" Ok\r\n");
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
    memcpy(Buffer, &TcpConnectionParameters, sizeof(t_TcpConnectionParameters));

    regs.Words.HL = (int)Buffer;
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
    AbortIfEscIsPressed();
    regs.Bytes.B = conn;
    regs.Words.DE = (int)(TcpInputData);
    regs.Words.HL = TCP_BUFFER_SIZE;
    UnapiCall(&codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
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
    char* pointer = Buffer;
    sprintf(userAgent, "User-Agent: MSX trivial dropbox/1.0 (MSX-DOS %s; TCP/IP UNAPI; %s)\r\n", GetDosVersionString(Buffer), GetUnapiImplementationName(&pointer[10]));
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


void DoAuthorization()
{
    CheckExactArgumentsCount(3);
    
    ResolveServerName(false);
    print("Connecting to server... ");
    OpenTcpConnection();
    print("Ok\r\n");

    DoAuthorizationCore(arguments[1], arguments[2]);
}


void DoAuthorizationCore(char* email, char* password)
{
    int httpRequestLength;
#ifdef DEBUG
    char* pointer;
#endif

    *token = '\0';
    *tokenSecret = '\0';

    requestingToken = true;
    print("Sending request... ");
    httpRequestLength = ComposeAuthHttpRequest(email, password);
    SendTcpData(Buffer, httpRequestLength);
    InitializeHttpVariables();
    ResetTcpBuffer();
    ReadResponseHeaders();
    DownloadHttpContents();
    print("Ok\r\n");
    
#ifdef DEBUG
    pointer = JsonBuffer;
    pointer[contentLength] = '\0';
    print(JsonBuffer);
#endif
        
    ProcessAuthorizationData();
}


void ProcessAuthorizationData()
{
    char* name = Buffer;
    char* value = ((char*)(name + 128));
    char* token = ((char*)(value + 128));
    char* tokenSecret = ((char*)(token + 128));
    char* usrFileName = ((char*)(tokenSecret + 128));
    char* usrFileContents = ((char*)(usrFileName + 64));
    JsonType type;
    byte fileHandle;

    *token = '\0';
    *tokenSecret = '\0';

    type = JsonInit();

    while(JsonDataAvailable()) {
        type = JsonGetNextItem(name, value);
        if(type == JSON_OBJECT_END) {
            break;
        }
        debug3("Json: name = %s, value = %s", name, value);
        CheckExpectedJsonType(type, JSON_DATA);
        if(StringIs(name, "token")) {
            strcpy(token, value);
        } else if(StringIs(name, "secret")) {
            strcpy(tokenSecret, value);
        }
    }
    
    debug3("Token: %s, secret: %s", token, tokenSecret);
    if((*token == '\0') || (*tokenSecret == '\0')) {
        Terminate("The server did not return the expected data.");
    }
    
    GetDataFilePath("dropbox.usr", usrFileName);
    debug2("User file name: %s", usrFileName);
    fileHandle = CreateFile(usrFileName, "Error when creating the user data file: ");
    sprintf(usrFileContents, "%s\r\n%s\r\n%s\r\n", arguments[1], token, tokenSecret);
    WriteToFile(fileHandle, usrFileContents, strlen(usrFileContents), "Error when writing to the user data file: ");
    CloseFile(fileHandle);

    print(
    "\r\nYou have successfully authorized MSX trivial dropbox to manage\r\n"
    "your Dropbox account.\r\n"
    "\r\n"
    "A file named DROPBOX.USR has been created in the MSX trivial dropbox\r\n"
    "directory. If you delete this file, or if you want to use\r\n"
    "MSX trivial dropbox with another account, you will need to repeat\r\n"
    "the authorization process."
    );
}


int ComposeAuthHttpRequest(char* email, char* password)
{
    char* pointer = JsonBuffer;
    char* pointer2;
    char* paramsBeforeO = pointer;
    char* paramsAfterO = pointer + 256;
    
    pointer = CopyAndUpdatePointer(pointer, "email=");
    PercentEncode(email, pointer, 0);

    pointer2 = paramsAfterO;
    pointer2 = CopyAndUpdatePointer(pointer2, "password=");
    PercentEncode(password, pointer2, 0);
    
    GenerateHttpRequest("GET", "/0/token", paramsBeforeO, paramsAfterO, Buffer, (char*)0x9000);
    
    return strlen(Buffer);
}


void ReadResponseHeaders()
{
    emptyLineReaded = 0;
    
    ReadResponseStatus();
    
    while(!emptyLineReaded) {
        ReadNextHeader();
        ProcessNextHeader();
    }
    
    ProcessResponseStatus();
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
        }
        return;
    }
}


void ProcessResponseStatus()
{
    if(responseStatusCode == 507) {
        Terminate("Your Dropbox account is full. Can't add new files.");
    } else if(responseStatusCode == 401) {
        if(requestingToken) {
            Terminate("Invalid email or password.\r\nIf you don't have a Dropbox account yet, use the \"new\" option instead.");
        } else {
            Terminate("Bad authentication token. Please reauthenticate by using the \"auth\" option.");
        }
    } else if(responseStatusCode == 404) {
        Terminate("File not found on server, or invalid HTTP request");
    } else if(responseStatusCode == 406) {
        Terminate("Too many directory entries");
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

    SkipCharsUntil(pointer, ' ');
    SkipCharsWhile(pointer, ' ');
    printf("\r\x1BK*** Error returned by server: %s\r\n", pointer);
    
    DownloadHttpContents();
    JsonInit();
    while(JsonDataAvailable())
    {
        type = JsonGetNextItem(Buffer, Buffer + 256);
        if(type == JSON_DATA) {
            printf("%s: %s\r\n", Buffer, Buffer + 256);
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

    while(contentLength == 0 || receivedLength < contentLength) {
        EnsureThereIsTcpDataAvailable();
        receivedLength += remainingInputData;
        memcpy(pointer, inputDataPointer, remainingInputData);
        pointer += remainingInputData;
        ResetTcpBuffer();
    }
}


void DoChunkedDataTransfer()
{
    int chunkSizeInBuffer;
    char* pointer = JsonBuffer;
    contentLength = 0;

    currentChunkSize = GetNextChunkSize();

    while(1) {
        if(currentChunkSize == 0) {
            EnsureThereIsTcpDataAvailable();
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
        memcpy(pointer, inputDataPointer, chunkSizeInBuffer);
        pointer += chunkSizeInBuffer;
        contentLength += chunkSizeInBuffer;
        inputDataPointer += chunkSizeInBuffer;
        currentChunkSize -= chunkSizeInBuffer;
        remainingInputData -= chunkSizeInBuffer;
    }
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


JsonType JsonInit()
{
    JsonType type;
    char* pointer = Buffer;

    jsonPointer = JsonBuffer;
    jsonNestLevel = 0;
    jsonLastItemType = JSON_NONE;
    
    type = JsonGetNextItem(pointer, pointer + 128);
    CheckExpectedJsonType(type, JSON_OBJECT_START);
    return type;
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
    theChar = *jsonPointer++;
    
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
        jsonPointer++;
        *value = '\0';
        jsonNestLevel++;
        jsonLastItemType = JSON_ARRAY_START;
        return JSON_ARRAY_START;
    } else if(*jsonPointer == '{') {
        jsonPointer++;
        *value = '\0';
        jsonNestLevel++;
        jsonLastItemType = JSON_OBJECT_START;
        return JSON_OBJECT_START;
    }

    JsonSkipWhitespaceCharsAndCommas();

    theChar = *jsonPointer;
    if(theChar == '"') {
        isString = true;
        jsonPointer++;
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
    
    while(true) {
        if((value = *jsonPointer++) == '\\') {
            escape = *jsonPointer++;
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
                // We dont support unicode, so leave the escape sequence as is
                *destination++ = '\\';
                *destination++ = 'u';
            }
        } else {
            if((isString && value == '"') || (!isString && value == ',')) {
                *destination = '\0';
                return;
            } else if(!isString && value == '}') {
                *destination = '\0';
                jsonPointer--;
                return;
            } else {
                *destination++ = value;
            }
        }
    }
}


void JsonSkipWhitespaceCharsAndCommas()
{
    while(*jsonPointer == ' ' || *jsonPointer == '\r' || *jsonPointer == '\n' || *jsonPointer == ',') {
        jsonPointer++;
    }
}


void GetDataDirectory()
{
    //byte len;
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
    regs.Bytes.B = handle;
    regs.Words.DE = (int)data;
    regs.Words.HL = length;
    DosCall(_WRITE, &regs, REGS_MAIN, REGS_AF);
    if(regs.Bytes.A != 0) {
        CloseFile(handle);
        TerminateWithDosErrorCode(errorMessage, regs.Bytes.A);
    }
}


void CloseFile(byte handle)
{
    regs.Bytes.B = handle;
    DosCall(_CLOSE, &regs, REGS_MAIN, REGS_AF);
}


void TerminateWithDosErrorCode(char* message, byte errorCode)
{
    char* pointer = Buffer;

    strcpy(pointer, message);
    pointer += strlen(message);
    ExplainDosErrorCode(errorCode, pointer);
    Terminate(Buffer);
}


char* ExplainDosErrorCode(byte code, char* destination)
{
    regs.Bytes.B = code;
    regs.Words.DE = (int)destination;
    DosCall(_EXPLAIN, &regs, REGS_MAIN, REGS_NONE);
    return destination;
}


void DoGetAccountInfo()
{
    int httpRequestLength;
    bool raw = false;
    char* pointer;

    if(argumentsCount == 2 && StringIs(arguments[1], "raw")) {
        raw = true;
    } else {
        CheckExactArgumentsCount(1);
    }
    ReadTokenFromFile();
    
    ResolveServerName(false);
    print("Connecting to server... ");
    OpenTcpConnection();
    print("Ok\r\n");

    requestingToken = false;    
    print("Sending request... ");
    GenerateHttpRequest("GET", "/0/account/info", null, null, Buffer, (char*)0x9000);
    debug(Buffer);
    httpRequestLength = strlen(Buffer);
    SendTcpData(Buffer, httpRequestLength);
    InitializeHttpVariables();
    ResetTcpBuffer();
    ReadResponseHeaders();
    DownloadHttpContents();
    print("Ok\r\n");
    
#ifdef DEBUG
    pointer = JsonBuffer;
    pointer[contentLength] = '\0';
    print(JsonBuffer);
#endif

    if(raw) {
        PrintNewLine();
        pointer = JsonBuffer;
        pointer[contentLength] = '\0';
        print(JsonBuffer);
    } else {
        ProcessInfoData();
    }
}


void ProcessInfoData()
{
    JsonType type;
    char* name = Buffer;
    char* value = ((char*)(name + 128));

    type = JsonInit();

    PrintNewLine();
    while(JsonDataAvailable()) {
        type = JsonGetNextItem(name, value);
        if(type == JSON_OBJECT_START || type == JSON_OBJECT_END) {  //quota info has its own json object but we don't care about that
            debug2("JSON_START or END found: %i", type);
            continue;
        }
        debug4("Json: name = %s, value = %s, next = %c", name, value, *jsonPointer);
        CheckExpectedJsonType(type, JSON_DATA);
        if(StringIs(name, "display_name")) {
            printf("User name:   %s\r\n", value);
        } else if(StringIs(name, "email")) {
            printf("User email:  %s\r\n", value);
        } else if(StringIs(name, "uid")) {
            printf("User ID:     %s\r\n", value);
        } else if(StringIs(name, "quota")) {
            print("Total quota: ");
            PrintSize(value);
        } else if(StringIs(name, "normal")) {
            printf("Used quota:  ");
            PrintSize(value);
        }
    }
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
    if(regs.Bytes.A != 0) {
        CloseFile(fileHandle);
        TerminateWithDosErrorCode(errorMessage, regs.Bytes.A);
    }
    return regs.Words.HL;
}


void ReadTokenFromFile()
{
    byte fileHandle;
    char* pointer;
    int readed;
    
    GetDataFilePath("dropbox.usr", Buffer);
    if(!FileExists(Buffer)) {
        Terminate("User authorization file not found.\r\n    Please run the application with the \"auth\" parameter.");
    }
    
    fileHandle = OpenFile(Buffer, "Error when opening the user data file: ");
    readed = ReadFromFile(fileHandle, Buffer, 256, "Error when reading from the user data file: ");
    Buffer[readed]='\0';
    debug(Buffer);
    CloseFile(fileHandle);
    
    pointer = Buffer;
    ParseFileLine(&pointer, NULL, 128);
    ParseFileLine(&pointer, token, 64);
    ParseFileLine(&pointer, tokenSecret, 64);
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


long ParseAndDivideBy1024(char* numberString) __naked
{
    __asm
    
    push    ix
    ld  ix,#4
    add ix,sp
    ld  l,(ix)
    ld  h,1(ix) ;HL = source
    ;ld  e,2(ix)
    ;ld  d,3(ix)
    ;push    de
    ;pop iy  ;IY = result
    ld  ix,#_ParseAndDivideBy1024Buffer
    ld  (ix),#0
    ld  1(ix),#0
    ld  2(ix),#0
    ld  3(ix),#0
    ld  4(ix),#0
    
pdiv_loop:
    ld  a,(hl)
    or  a
    jr  z,pdiv_divideby1024
    
    push    hl
    push    af
    call    pdiv_multby10
    pop af
    sub a,#48  ;"0"
    ld  e,a
    ld  d,#0
    ld  hl,#0
    ld  c,#0
    call    pdiv_add_chlde
    pop hl
    inc hl
    jr  pdiv_loop
    
pdiv_divideby1024:
    ld  b,#10
pdiv_divloop:
    sra 4(ix)
    rr  3(ix)
    rr  2(ix)
    rr  1(ix)
    rr  (ix) 
    djnz    pdiv_divloop
    
    ld  l,(ix)
    ld  h,1(ix)
    ld  e,2(ix)
    ld  d,3(ix)
    
    pop ix
    ret

pdiv_multby10:
    ld  e,(ix)
    ld  d,1(ix)
    ld  l,2(ix)
    ld  h,3(ix)
    ld  c,4(ix)
    ld  b,#3
    call    pdiv_multby2    ;Mult by 8
    call    pdiv_add_chlde
    jp  pdiv_add_chlde

pdiv_add_chlde:
    ld  a,e
    add a,(ix)
    ld  (ix),a
    ld  a,d
    adc a,1(ix)
    ld  1(ix),a
    ld  a,l
    adc a,2(ix)
    ld  2(ix),a
    ld  a,h
    adc a,3(ix)
    ld  3(ix),a
    ld  a,c
    adc a,4(ix)
    ld  4(ix),a
    ret
    
pdiv_multby2:
    sla (ix)
    rl  1(ix)
    rl  2(ix)
    rl  3(ix)
    rl  4(ix)
    djnz    pdiv_multby2
    ret

    __endasm;
}


void PrintSize(char* size)
{
    long sizeInK;

    if(strlen(size) < 4) {
        printf("%s bytes\r\n", size);
        return;
    }
    
    sizeInK = ParseAndDivideBy1024(size);
    PrintSizeInK(sizeInK);
    PrintNewLine();
}


void PrintSizeInK(unsigned long size)
{
    int remaining;

    if(size < 1024) {
        printf("%i K", size);
        return;
    }

    remaining = size & 1023;
    if(remaining > 1000) {
        remaining = 999;
    }
    size >>= 10;
    if(size < 1024) {
        printf("%i.%i Mbytes", (int)size, remaining/100);
        return;
    }
    
    remaining = size & 1023;
    if(remaining > 1000) {
        remaining = 999;
    }
    size >>= 10;
    printf("%i.%i Gbytes", (int)size, remaining/100);
}


void ChangeAtsToSpaces(char* string)
{
    char value;
    while((value = *string) != '\0') {
        if(value == '@') {
            *string = ' ';
        }
        string++;
    }
}


void DoNewAccount()
{
    int httpRequestLength;
    int i;

    CheckExactArgumentsCount(5);
    ChangeAtsToSpaces(arguments[1]);
    ChangeAtsToSpaces(arguments[2]);
    
    for(i=1; i<=4; i++) {
        if(!HasOnlyAsciiChars(arguments[i])) {
            Terminate("Please use only standard ASCII characters for the name, email and password.");
        }
    }
    
    *token = '\0';
    *tokenSecret = '\0';
    
    ResolveServerName(false);
    print("Connecting to server... ");
    OpenTcpConnection();
    print("Ok\r\n");

    requestingToken = true;
    print("Sending request... ");
    httpRequestLength = ComposeNewAccountHttpRequest();
    SendTcpData(Buffer, httpRequestLength);
    InitializeHttpVariables();
    ResetTcpBuffer();
    ReadResponseHeaders();
    print("Ok\r\n");
        
    print("\r\nThe account has been created. Now beginning the authorization process.\r\n\r\n");
    DoAuthorizationCore(arguments[3], arguments[4]);
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


int ComposeNewAccountHttpRequest()
{
    char* firstName = JsonBuffer;
    char* lastName =  (char*)(firstName + 256);
    char* email = (char*)(lastName + 256);
    char* password = (char*)(email + 256);
    char* paramsBeforeO = (char*)(password + 256);
    char* paramsAfterO = (char*)(paramsBeforeO + 256);
    
    PercentEncode(arguments[1], firstName, 0);
    PercentEncode(arguments[2], lastName, 0);
    PercentEncode(arguments[3], email, 0);
    PercentEncode(arguments[4], password, 0);
    
    sprintf(paramsBeforeO, "email=%s&first_name=%s&last_name=%s", email, firstName, lastName);
    sprintf(paramsAfterO, "password=%s", password);

    GenerateHttpRequest("GET", "/0/account", paramsBeforeO, paramsAfterO, Buffer, (char*)0x9000);

/*
    sprintf(Buffer,
        "GET /0/account?first_name=%s&last_name=%s&email=%s&password=%s&oauth_consumer_key=%s HTTP/1.1\r\n"
        "Host: api.dropbox.com\r\n"
        "%s"
        "\r\n",
        
        firstName,
        lastName,
        email,
        password,
        strConsumerKey,
        userAgent
    );
*/
    
    return strlen(Buffer);
}


bool FileExists(char* path)
{
    regs.Words.DE = (int)path;
    regs.Bytes.B = 0;
    regs.Words.IX = (int)JsonBuffer;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
    return (regs.Bytes.A == 0);
}
