/* MSX trivial tweeter 1.0
   By Konamiman 5/2010

   Compilation command line:
   
   sdcc --code-loc 0x170 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.rel base64.lib
          sha1.lib asm.lib tweeter.c
   hex2bin -e com tweeter.ihx
   
   ASM.LIB, SHA1.LIB, BASE64.LIB, MSXCHAR.LIB and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com
*/

//#define DEBUG

#ifdef DEBUG
#define debug(x) {print("--- ");print(x);print("\r\n");}
#define debug2(x,y) {print("--- ");printf(x,y);print("\r\n");}
#define debug3(x,y,z) {print("--- ");printf(x,y,z);print("\r\n");}
#define debug4(x,y,z,a) {print("--- ");printf(x,y,z,a);print("\r\n");}
#define debug5(x,y,z,a,b) {print("--- ");printf(x,y,z,a,b);print("\r\n");}
#define printhex(x,y,z) {print(x);PrintHex(y,z);print("\r\n");}
#else
#define debug(x)
#define debug2(x,y)
#define debug3(x,y,z)
#define debug4(x,y,z,a)
#define debug5(x,y,z,a,b)
#define printhex(x,y,z)
#endif

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

#define _TERM0 0
#define _CONIN 1
#define _INNOE 8
#define _BUFIN 0x0A
#define _GDATE 0x2A
#define _GTIME 0x2C
#define _OPEN 0x43
#define _CREATE 0x44
#define _CLOSE 0x45
#define _SEEK 0x4A
#define _READ 0x48
#define _WRITE 0x49
#define _PARSE 0x5B
#define _EXPLAIN 0x66
#define _GENV 0x6B
#define _DOSVER 0x6F
#define _REDIR 0x70

#define _NOFIL 0x0D7

#define TICKS_TO_WAIT (20*60)
#define SYSTIMER ((uint*)0xFC9E)

#define TCP_BUFFER_SIZE (4096)
#define TCPOUT_STEP_SIZE (512)

#define MESSAGE_MAX_SIZE (140)
#define USERNAME_MAX_SIZE (15)
#define USERID_MAX_SIZE (15)        //???
#define MAX_TOKEN_LENGTH (50)
#define MAX_PIN_LENGTH (7)

#define CHARMAP_CHUNK_SIZE (8192)

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

#define BUFFERS_BASE 0x8000

#define TcpInputData buffers->Temp1
#define TcpOutputData buffers->Temp1

typedef struct {
    byte Temp1[1024];
    byte Temp2[1024];
    byte Temp3[1024];
    byte Temp4[1024+1];
    byte ServerName[256];
    byte Nonce[40];
    byte Timestamp[16];
    byte UnencodedSignature[20];
    byte Base64Signature[32];
    byte Signature[128];
    byte Token[MAX_TOKEN_LENGTH+1];
    byte TokenSecret[MAX_TOKEN_LENGTH+1];
    byte SignatureKey[MAX_TOKEN_LENGTH*2 + 2];
    byte MaxMessageLength;
    byte MessageLength;
    byte Message[MESSAGE_MAX_SIZE*2 + 2];
    byte MessageUTF8[MESSAGE_MAX_SIZE*4 + 1];
    byte EncodedMessage[MESSAGE_MAX_SIZE*4*3 + 1];
    byte UserName[USERNAME_MAX_SIZE+1];
    byte UserId[USERID_MAX_SIZE+1];    
    byte MaxPinLength;
    byte PinLength;
    byte Pin[MAX_PIN_LENGTH+1];
    byte AuxFilePath[128+1];
    byte CharMapType;
    byte CharMap[CHARMAP_CHUNK_SIZE];
    struct {
        byte remoteIP[4];
        uint remotePort;
        uint localPort;
        int userTimeout;
        byte flags;
    } TcpConnectionParameters; 
} buffersStruct;

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

unsigned long SecsPerMonth[12] = {SECS_IN_MONTH_31, SECS_IN_MONTH_28, SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31, SECS_IN_MONTH_31, SECS_IN_MONTH_30,
    SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31};

const char* strPresentation=
    "MSX trivial tweeter 1.0\r\n"
    "By Konamiman, 5/2010\r\n"
    "\r\n"
    "Usage: tweeter <message>\r\n"
    "       tweeter /auth\r\n"
    "       tweeter /i\r\n"
    "\r\n"
    "<message>: Post the message specified directly by command line.\r\n"
    "\r\n"
    "/auth: Begin the authorization process\r\n"
    "    Before MSX trivial tweeter can tweet on your behalf,\r\n"
    "    you need to authorize it on the Twitter servers.\r\n"
    "    You will need access to a computer with a web browser\r\n"
    "    to complete the authorization process.\r\n"
    "\r\n"
    "/i: Run in interactive mode\r\n"
    "    In interactive mode, you will be prompted for the message to send.\r\n"
    "    This allows you to send 140 character messages\r\n"
    "    (command line is limited to 128 characters including the program name).\r\n"
    "    In this mode you can also redirect the output from another application\r\n"
    "    to generate the message, for example: echo Hello world | tweeter /i\r\n"
    "\r\n"
    "Non-standard ASCII characters can be send if a character map file\r\n"
    "named TWEETER.CHR is found in the application path.";

const char* strInvParam = "Invalid parameter";
const char* strNoNetwork = "No network connection available";
const char* strCancelled = "Operation cancelled.";

const char* strTwitterServerDefaultName = "twitter.com";

const char* strConsumerKey = "AZxGLKRLKgVcPebtT8x4EQ";
const char* strConsumerSecret = "Dqn4GxvIHUeRvR6OxbDCA9m4tqkADxA2lxRxDTo5Qw";

const char* strGET = "GET";
const char* strPOST = "POST";
const char* strEmpty = "";

const char* strUSR = "USR";
const char* strCHR = "CHR";

const char* strHttpRequestBase =
    "%s %s HTTP/1.1\r\n"
    "Host: twitter.com\r\n"
    "Connection: close\r\n"
    "User-Agent: MSX trivial tweeter/1.0\r\n"
    "Authorization: OAuth realm=\"\"\r\n"
    "   ,oauth_consumer_key=\"%s\"\r\n"
    "   ,oauth_nonce=\"%s\"\r\n"
    "   ,oauth_signature_method=\"HMAC-SHA1\"\r\n"
    "   ,oauth_timestamp=\"%s\"\r\n"
    "   ,oauth_signature=\"%s\"\r\n"
    "   ,oauth_version=\"1.0\"\r\n"
    "%s"
    "\r\n"
    "%s";

const char* strMessageHttpRequest =
    "POST /statuses/update.xml?status=%s HTTP/1.1\r\n"
    "Host: twitter.com\r\n"
    "Connection: close\r\n"
    "User-Agent: MSX trivial tweeter/1.0\r\n"
    "Authorization: OAuth realm=\"\"\r\n"
    "   ,oauth_consumer_key=\"%s\"\r\n"
    "   ,oauth_nonce=\"%s\"\r\n"
    "   ,oauth_signature_method=\"HMAC-SHA1\"\r\n"
    "   ,oauth_timestamp=\"%s\"\r\n"
    "   ,oauth_token=\"%s\"\r\n"
    "   ,oauth_signature=\"%s\"\r\n"
    "   ,oauth_version=\"1.0\"\r\n"
    "\r\n";

const char* strRequestTokenEncryptionBase =
    "oauth_consumer_key=%s&"
    "oauth_nonce=%s&"
    "oauth_signature_method=HMAC-SHA1&"
    "oauth_timestamp=%s&"
    "oauth_version=1.0";

const char* strAccessTokenEncryptionBase =
    "oauth_consumer_key=%s&"
    "oauth_nonce=%s&"
    "oauth_signature_method=HMAC-SHA1&"
    "oauth_timestamp=%s&"
    "oauth_token=%s&"
    "oauth_verifier=%s&"
    "oauth_version=1.0";
    
const char* strSendMessageEncryptionBase =
    "oauth_consumer_key=%s&"
    "oauth_nonce=%s&"
    "oauth_signature_method=HMAC-SHA1&"
    "oauth_timestamp=%s&"
    "oauth_token=%s&"
    "oauth_version=1.0&"
    "status=";


const char* strUserActionRequest =
    "Please open a web browser in another computer and navigate to this address:\r\n"
    "\r\n"
    "http://twitter.com/oauth/authorize?oauth_token=%s\r\n"
    "\r\n"
    "Follow the directions on the screen and take note of the PIN number.\r\n"
    "Then enter the PIN number here (or just hit ENTER to cancel): ";

const char* strBeginningAuth=
    "Beginning the authorization process.\r\n"
    "A small configuration file will be created,\r\n"
    "so ensure that the disk is not write protected.\r\n"
    "\r\n";

const char* strAuthorizationOk = 
    "You have successfully authorized MSX trivial tweeter to post messages\r\n"
    "on behalf of user %s.\r\n"
    "\r\n"
    "A file named TWEETER.USR has been created in the same directory of TWEETER.COM.\r\n"
    "If you delete this file, or if you want to post as another user,\r\n"
    "you will need to repeat the authorization process.";

const char* strNoConfig =
    "Configuration file not found or invalid.\r\n"
    "\r\n"
    "You need to run the application with the /auth parameter to begin the\r\n"
    "authorization process and create a configuration file.";

const char* strBadChar =
    "The message contains characters not mapped in the character mapping file\r\n    (character code: 0x%x).\r\n";

const char* strNotPrintable =    
    "Can't send non-printable ASCII characters";
    
const char* strTooLong =
    "Message is too long. Maximum message size is 140 characters.";

Z80_registers regs;
int i;
int param;
unapi_code_block codeBlock;

int year=2010;
byte month=1;
byte day=1;
byte hour=0;
byte minute=0;
byte second=0;

char paramLetter;
SHA_CTX ctx;
uint length;
byte error;
buffersStruct* buffers;
byte conn = 0;
byte authorizationRequested = 0;
byte* tempPointer;
int ticksWaited;
int sysTimerHold;
int dataReadCount;
int dataSize;
byte fileHandle = 0;
byte charmapFileHandle = 0;
uint charmapMin;
uint charmapMax;
byte lastCharmapChunkIndex;
byte numCharmapChunks;
int RealMessageLength;

//TODO: Move this to tweeter.h

void PrintUsageAndEnd();
void Terminate(const char* errorMessage);
int strcmpi(const char *a1, const char *a2);
int strncmpi(const char *a1, const char *a2, unsigned size);
char* PercentEncode(char* src, char* dest, byte encodingType);
void GenerateTimestamp();
void GenerateNonce();
void GetDateAndTime();
void CheckDosVersion();
void InitializeTcpipUnapi();
void CheckNetworkConnection();
void GetServername();
void ResolveServerName();
void OpenTcpConnection();
void CloseTcpConnection();
void ReceiveTcpData();
void SendTcpData();
void print(char* s);
void GenerateSignature(char* baseString);
void GenerateTokenRequest();
byte ArgumentIs(char* argument, char* argumentStart);
void DoAuthorizationProcess();
void RemoveExtraSpacesFromMessage();
void ReadMessageFromConsole();
int strlen2byte(byte* message);
void ReadMessageFromCommandLine();
void SendMessage();
int ReadWholeFile(char* fileExtension, char* destination, int maxLength);
void ReadConfigurationFile();
void ParseConfigFileLine(byte** src, byte* dest, int maxLength);
void CreateConfigurationFile();
void FindParameterInResponse(char* paramName, char* destination);
void DoCommonInitialization();
void GenerateAuthorizationRequest();
void FindError(char* destination);
void DoTcpTransaction();
void GetAuxiliaryFilePath(char* fileExtension);
void ExplainDosErrorCode(byte code, char* destination);
void GenerateMessageRequest();
void ConvertMessageToUTF8();
void ConvertMessageToUTF8_1byte();
void ConvertMessageToUTF8_2bytes();
void CollapseMessage();
void ReadCharMapChunk(byte chunkIndex);
void ReadCharMap();
void CloseFile(byte* fileHandle);
void UTF16toUTF8(byte* src, byte* dest);

#ifdef DEBUG
void PrintHex(byte* src, int leng);
#endif

#define LetTcpipBreathe() UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE)


/**********************
 ***  MAIN is here  ***
 **********************/
  
int main(char** argv, int argc)
{
    debug2("Buffers struct size: %i\r\n", sizeof(buffersStruct));

    buffers = (buffersStruct*)BUFFERS_BASE;

    //* Print presentation and check running conditions

    print("\r\n");
    if(argc==0) {
        PrintUsageAndEnd();
    }

    CheckDosVersion();
    InitializeTcpipUnapi();
    CheckNetworkConnection();

    //* Check parameters
    
    if(ArgumentIs(argv[0], "auth")) {
        DoAuthorizationProcess();
    } else if(ArgumentIs(argv[0],"i")) {
        ReadConfigurationFile();
        ReadCharMap();
        ReadMessageFromConsole();
        SendMessage();
    } else if(argv[0][0] != '/') {
        ReadConfigurationFile();
        ReadCharMap();
        ReadMessageFromCommandLine();
        SendMessage();
    } else {
        Terminate(strInvParam);
    }

    Terminate(NULL);
    return 0;    
}


/****************************
 ***  FUNCTIONS are here  ***
 ****************************/

void PrintUsageAndEnd()
{
    print(strPresentation);
    DosCall(0, &regs, REGS_MAIN, REGS_NONE);
}


void Terminate(const char* errorMessage)
{
    CloseTcpConnection();

    CloseFile(&fileHandle);
    CloseFile(&charmapFileHandle);

    if(errorMessage != NULL) {
        printf("\r\x1BK*** %s\r\n", errorMessage);
    }
    
    DosCall(_TERM0, &regs, REGS_NONE, REGS_NONE);
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
    return dest;
}


void GenerateTimestamp()
{
    unsigned long seconds = SECS_1970_TO_2010;
    byte isLeapYear;
    int loopValue;

    seconds = SECS_1970_TO_2010;

    //* Years

    loopValue = 2010;
    while(loopValue < year) {
        isLeapYear = (loopValue & 3) == 0;
        seconds += (isLeapYear ? SECS_IN_LYEAR : SECS_IN_YEAR);
        loopValue++;
    }
    
    //* Months
    
    isLeapYear = (year & 3) == 0;
    loopValue = 1;
    while(loopValue < month) {
        if(isLeapYear && (loopValue == 2)) {
            seconds += SECS_IN_MONTH_29;
        } else {
            seconds += SecsPerMonth[loopValue-1];
        }
        loopValue++;
    }
    
    //* Rest of parameters
    
    seconds += (SECS_IN_DAY) * (day-1);
    seconds += (SECS_IN_HOUR) * hour;
    seconds += (SECS_IN_MINUTE) * minute;
    seconds += second;
    
    _ultoa(seconds, buffers->Timestamp, 10);
}


void GenerateNonce()
{
    sprintf(buffers->Nonce, "MSX-%i%i%i-%i%i%i-%i", year, month, day, hour, minute, second, *SYSTIMER);
}


void GetDateAndTime()
{
    DosCall(_GDATE, &regs, REGS_NONE, REGS_MAIN);
    year = regs.Words.HL;
    month = regs.Bytes.D;
    day = regs.Bytes.E;
    if(year < 2010) {
        Terminate("Your MSX seems to not have the clock properly adjusted.\r\n    Please adjust it and try again.");
    }

    DosCall(_GTIME, &regs, REGS_NONE, REGS_MAIN);
    hour = regs.Bytes.H;
    minute = regs.Bytes.L;
    second = regs.Bytes.D;
}


void CheckDosVersion()
{
    DosCall(_DOSVER, &regs, REGS_NONE, REGS_MAIN);
    if(regs.Bytes.B < 2) {
        Terminate("This program is for MSX-DOS 2 only.");
    }
}


void InitializeTcpipUnapi()
{
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

    buffers->TcpConnectionParameters.remotePort = 80;
    buffers->TcpConnectionParameters.localPort = 0xFFFF;
    buffers->TcpConnectionParameters.userTimeout = 0;
    buffers->TcpConnectionParameters.flags = 0;
}


void CheckNetworkConnection()
{
    UnapiCall(&codeBlock, TCPIP_NET_STATE, &regs, REGS_NONE, REGS_MAIN);
    if(regs.Bytes.B == 0 || regs.Bytes.B == 3) {
        Terminate(strNoNetwork);
    }
}


void GetServername()
{
    regs.Words.HL = (int)"TWITTER_SERVER";
    regs.Words.DE = (int)buffers->ServerName;
    regs.Bytes.B = 255;
    DosCall(_GENV, &regs, REGS_MAIN, REGS_NONE);
    if(buffers->ServerName[0] == '\0') {
        strcpy(buffers->ServerName, strTwitterServerDefaultName);
    }
}


void ResolveServerName()
{
    print("Resolving server name...");
    regs.Words.HL = (int)buffers->ServerName;
    debug2("Server name: %s\r\n", (byte*)regs.Words.HL);
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_DNS_Q, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == ERR_NO_NETWORK) {
        Terminate(strNoNetwork);
    } else if(regs.Bytes.A == ERR_NO_DNS) {
        Terminate("There are no DNS servers configured");
    } else if(regs.Bytes.A == ERR_NOT_IMP) {
        Terminate("This TCP/IP UNAPI implementation does not support resolving host names.\r\n"
                  "    You can specify the IP address of twitter.com\r\n"
                  "    in the environment string TWITTER_SERVER.");
    } else if(regs.Bytes.A != (byte)ERR_OK) {
        sprintf(buffers->Temp1, "Unknown error when resolving the host name (code %i)", regs.Bytes.A);
        Terminate(buffers->Temp1);
    }
    
    do {
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
            sprintf(buffers->Temp1, "Unknown error returned by DNS server (code %i)", regs.Bytes.B);
            Terminate(buffers->Temp1);
        }
    }
    
    buffers->TcpConnectionParameters.remoteIP[0] = regs.Bytes.L;
    buffers->TcpConnectionParameters.remoteIP[1] = regs.Bytes.H;
    buffers->TcpConnectionParameters.remoteIP[2] = regs.Bytes.E;
    buffers->TcpConnectionParameters.remoteIP[3] = regs.Bytes.D;
    
    print(" Ok\r\n");
    
    #ifdef DEBUG
    printf("--- Server IP: %i.%i.%i.%i\r\n", buffers->TcpConnectionParameters.remoteIP[0], buffers->TcpConnectionParameters.remoteIP[1], buffers->TcpConnectionParameters.remoteIP[2], buffers->TcpConnectionParameters.remoteIP[3]);
    #endif
    
}


void OpenTcpConnection()
{
    regs.Words.HL = (int)&(buffers->TcpConnectionParameters);
    UnapiCall(&codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == (byte)ERR_NO_FREE_CONN) {
        regs.Bytes.B = 0;
        UnapiCall(&codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_NONE);
        regs.Words.HL = (int)&(buffers->TcpConnectionParameters);
        UnapiCall(&codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    }
    
    if(regs.Bytes.A == (byte)ERR_NO_NETWORK) {
        Terminate(strNoNetwork);
    } else if(regs.Bytes.A != 0) {
        sprintf(buffers->Temp1, "Unexpected error when opening TCP connection (%i)", regs.Bytes.A);
        Terminate(buffers->Temp1);
    }
    conn = regs.Bytes.B;
    
    ticksWaited = 0;
    do {
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
        debug2("Error connecting: %i\r\n", regs.Bytes.A);
        Terminate("Could not establish a connection to the server");
    }
}


void CloseTcpConnection()
{
    if(conn != 0) {
        regs.Bytes.B = conn;
        UnapiCall(&codeBlock, TCPIP_TCP_CLOSE, &regs, REGS_MAIN, REGS_NONE);
    }
}


void CrToZero(char* str)
{
    while(*str != '\0') {
        if(*str == 13) {
            *str = '\0';
        }
        str++;
    }
}

void ReceiveTcpData()
{
    byte nonceError = 0;

    dataReadCount = 0;
    ticksWaited = 0;
    do {
        sysTimerHold = *SYSTIMER;
        LetTcpipBreathe();
        while(*SYSTIMER == sysTimerHold);
        ticksWaited++;
        if(ticksWaited >= TICKS_TO_WAIT) {
            Terminate("Could not get a reply from the server");
            return;
        }
        
        regs.Bytes.B = conn;
        regs.Words.DE = (int)(TcpInputData) + dataReadCount;
        regs.Words.HL = TCP_BUFFER_SIZE - dataReadCount;
        UnapiCall(&codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_MAIN);
        if(regs.Bytes.A != 0) {
            sprintf(buffers->Temp1, "Unexpected error when reading TCP data (%i)", regs.Bytes.A);
            Terminate(buffers->Temp1);
        }
        dataReadCount += regs.UWords.BC;
        
        regs.Bytes.B = conn;
        regs.Words.HL = 0;
        UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    } while((regs.Bytes.A == 0) && (regs.Bytes.B == 4) && (dataReadCount < TCP_BUFFER_SIZE));
    
    if(regs.Bytes.A != 0) {
        Terminate("Connection lost");
    }
    
    if(dataReadCount == 0) {
        Terminate("The server did not send data");
    } else if(dataReadCount > TCP_BUFFER_SIZE) {
        dataReadCount = TCP_BUFFER_SIZE;
    }
    
    TcpInputData[dataReadCount] = '\0';
    debug2("TCP data received:\r\n%s.", TcpInputData);
    
    tempPointer = strstr(TcpInputData, "HTTP/1.1 ");
    if(tempPointer != TcpInputData) {
        CrToZero(TcpInputData);
        sprintf(buffers->Temp1, "Unexpected data received from server: %s", TcpInputData);
        Terminate(buffers->Temp1);
    }
    if(TcpInputData[9] != (byte)'2') {
        if(strstr(TcpInputData, "timestamp") != NULL || strstr(TcpInputData, "nonce") != NULL) {
            nonceError = 1;
        }
        FindError(buffers->MessageUTF8);
        CrToZero(TcpInputData);
        sprintf(buffers->Temp2, "Error returned by server: %s; %s", TcpInputData+9, buffers->MessageUTF8);
        if(nonceError) {
            strcpy(buffers->Temp2 + strlen(buffers->Temp2), 
                "\r\n\r\n(If you get \"timestamp\" or \"nonce\" errors, ensure that\r\n"
                "the MSX clock is properly set to the current date and time)");
        }
        Terminate(buffers->Temp2);
    }
}


void SendTcpData()
{
    tempPointer = TcpOutputData;
    dataSize = strlen(TcpOutputData);
    debug2("SendTcpData: will send a total of %i bytes\r\n", dataSize);
    
    do {
        do {
            regs.Bytes.B = conn;
            regs.Words.DE = (int)tempPointer;
            regs.Words.HL = dataSize > TCPOUT_STEP_SIZE ? TCPOUT_STEP_SIZE : dataSize;
            regs.Bytes.C = 1;
            UnapiCall(&codeBlock, TCPIP_TCP_SEND, &regs, REGS_MAIN, REGS_AF);
            if(regs.Bytes.A == ERR_BUFFER) {
                LetTcpipBreathe();
                regs.Bytes.A = ERR_BUFFER;
            }
        } while(regs.Bytes.A == ERR_BUFFER);
        debug2("SendTcpData: sent %i bytes\r\n", regs.Words.HL);
        dataSize -= TCPOUT_STEP_SIZE;
        tempPointer += regs.Words.HL;   //Unmodified since REGS_AF was used for output
    } while(dataSize > 0 && regs.Bytes.A == 0);
    
    if(regs.Bytes.A == ERR_NO_CONN) {
        Terminate("Connection lost while sending data");
    } else if(regs.Bytes.A != 0) {
        sprintf(buffers->Temp1, "Unexpected error when sending TCP data (%i)", regs.Bytes.A);
        Terminate(buffers->Temp1);
    }
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


void GenerateSignature(char* baseString)
{
    sprintf(buffers->SignatureKey, "%s&%s", strConsumerSecret, buffers->TokenSecret);
    debug2("Signature key: %s\r\n", buffers->SignatureKey);
    hmac_sha1(buffers->SignatureKey, strlen(buffers->SignatureKey), baseString, strlen(baseString), buffers->UnencodedSignature);
    Base64Init(0);
    length = Base64EncodeChunk(buffers->UnencodedSignature, buffers->Base64Signature, 20, 1);
    buffers->Base64Signature[length] = '\0';
    PercentEncode(buffers->Base64Signature, buffers->Signature, 0);
}


void GenerateTokenRequest()
{
    buffers->TokenSecret[0] = '\0';
    sprintf(buffers->Temp1, strRequestTokenEncryptionBase, strConsumerKey, buffers->Nonce, buffers->Timestamp);
    debug2("Unencoded base string: %s\r\n", buffers->Temp1);
    PercentEncode(buffers->Temp1, buffers->Temp2, 0);
    debug2("Encoded base string: %s\r\n", buffers->Temp2);
    PercentEncode("http://twitter.com/oauth/request_token", buffers->Temp1, 0);
    debug2("Encoded URL: %s\r\n", buffers->Temp1);
    sprintf(buffers->Temp3, "GET&%s&%s", buffers->Temp1, buffers->Temp2);
    debug2("Request token base string:\r\n%s", buffers->Temp3);
    
    GenerateSignature(buffers->Temp3);
    debug2("Request token signature:\r\n%s", buffers->Signature);
    
    sprintf(TcpOutputData, strHttpRequestBase, strGET, "/oauth/request_token", strConsumerKey, buffers->Nonce, buffers->Timestamp, buffers->Signature, strEmpty, strEmpty);
    debug2("Request token HTTP request:\r\n%s", TcpOutputData);
}


byte ArgumentIs(char* argument, char* argumentStart)
{
    return (argument[0] == '/' && (strncmpi(argument+1, argumentStart, strlen(argumentStart)) == 0));
}


void DoAuthorizationProcess()
{
    print(strBeginningAuth);

    debug("Starting authorization process");
    DoCommonInitialization();
    GenerateTokenRequest();
    DoTcpTransaction();

    FindParameterInResponse("oauth_token=", (char*)&(buffers->Token));
    debug2("Token received: %s\r\n", buffers->Token);
    FindParameterInResponse("oauth_token_secret=", (char*)&(buffers->TokenSecret));
    debug2("Token secret received: %s\r\n", buffers->TokenSecret);
    printf(strUserActionRequest, buffers->Token);

    regs.Words.DE = (int)&(buffers->MaxPinLength);
    buffers->MaxPinLength = MAX_PIN_LENGTH;
    DosCall(_BUFIN, &regs, REGS_MAIN, REGS_NONE);
    if(buffers->PinLength == 0) {
        Terminate(strCancelled);
    }
    buffers->Pin[buffers->PinLength] = 0;
    print("\r\n");
    
    GetDateAndTime();
    GenerateTimestamp();
    GenerateNonce();
    
    GenerateAuthorizationRequest();
    DoTcpTransaction();
    
    FindParameterInResponse("oauth_token=", (char*)&(buffers->Token));
    debug2("Token received: %s\r\n", buffers->Token);
    FindParameterInResponse("oauth_token_secret=", (char*)&(buffers->TokenSecret));
    debug2("Token secret received: %s\r\n", buffers->TokenSecret);
    FindParameterInResponse("user_id=", (char*)&(buffers->UserId));
    debug2("User ID received: %s\r\n", buffers->UserId);
    FindParameterInResponse("screen_name=", (char*)&(buffers->UserName));
    debug2("User name received: %s\r\n", buffers->UserName);
    
    CreateConfigurationFile();
    printf(strAuthorizationOk, buffers->UserName);
}


void RemoveExtraSpacesFromMessage()
{
    if(buffers->Message[0] == (byte)' ') {
        tempPointer = buffers->Message;
        while(*tempPointer == (byte)' ') {
            tempPointer++;
            RealMessageLength--;
            if(RealMessageLength == 0) {
                Terminate("Can't send an empty message");
            }
        }
        memcpy(buffers->Message, tempPointer, RealMessageLength);
        buffers->Message[RealMessageLength] = '\0';
    }
    
    tempPointer = &(buffers->Message[RealMessageLength - 1]);
    while(*tempPointer == (byte)' ') {
        tempPointer--;
        RealMessageLength--;
    }
    tempPointer[1] = '\0';
}


void ReadMessageFromConsole()
{
    byte charCount = 0;

    //Behavior of this method depends on whether
    //the input is being redirected from another application or not

    memset(buffers->Message, 0, sizeof(buffers->Message));
    regs.Bytes.A = 0;
    DosCall(_REDIR, &regs, REGS_AF, REGS_MAIN);
    if((regs.Bytes.B & 1) == 0) {
        debug("Input is NOT redirected");
        print("Type your message and press ENTER (or simply hit ENTER to cancel): \r\n");
        regs.Words.DE = (int)&(buffers->MaxMessageLength);
        buffers->MaxMessageLength = (buffers->CharMapType == 2 ? 255 : MESSAGE_MAX_SIZE);
        DosCall(_BUFIN, &regs, REGS_MAIN, REGS_NONE);
        if(buffers->MessageLength == 0) {
            Terminate(strCancelled);
        }
        buffers->Message[buffers->MessageLength] = 0;
        RealMessageLength = buffers->MessageLength;
        print("\r\n\r\n");
    } else {
        debug("Input is being redirected");
        tempPointer = buffers->Message;
        do {
            DosCall(_INNOE, &regs, REGS_NONE, REGS_AF);
            *tempPointer++ = regs.Bytes.A;
        } while(regs.Bytes.A != 13 && regs.Bytes.A != 0x1A);
        tempPointer[-1] = '\0';
        RealMessageLength = strlen(buffers->Message);
    }
    RemoveExtraSpacesFromMessage();
    debug2("Message to send: .%s.", buffers->Message);
    printhex("Message to send: ", buffers->Message, strlen(buffers->Message));
    if(buffers->CharMapType == 2 && strlen2byte(buffers->Message) > MESSAGE_MAX_SIZE) {
        Terminate(strTooLong);
    }
    if(buffers->CharMapType != 2 && RealMessageLength > MESSAGE_MAX_SIZE) {
        Terminate(strTooLong);
    }
}


int strlen2byte(byte* message)
{
    byte ch = 0;
    int len = 0;

    while((ch = *message) != 0) {
        len++;
        message++;
        if(ch >= 0x80) {
            message++;
        }
    }
    return len;
}


void ReadMessageFromCommandLine()
{
    if(buffers->CharMapType == 2) {
        Terminate("Specifying the message in command line is not supported\r\n"
                  "    when using double byte character sets.\r\n"
                  "    Please use the /i option instead.");
    }

    regs.Words.HL = (int)"PARAMETERS";
    regs.Words.DE = (int)buffers->Message;
    regs.Bytes.B = MESSAGE_MAX_SIZE+1;
    DosCall(_GENV, &regs, REGS_MAIN, REGS_NONE);
    buffers->MessageLength = (byte)strlen(buffers->Message);
    RealMessageLength = buffers->MessageLength;
    RemoveExtraSpacesFromMessage();
    debug2("Message to send: .%s.", buffers->Message);
    printhex("Message to send: ", buffers->Message, strlen(buffers->Message));
}


void SendMessage()
{
    ConvertMessageToUTF8();
    DoCommonInitialization();
    print("\r\nGenerating HTTP request, please wait... ");
    GenerateMessageRequest();
    print("Ok\r\n");
    DoTcpTransaction();
    print("Your message has been posted.");
}


void ParseConfigFileLine(byte** src, byte* dest, int maxLength)
{
    byte* pnt = *src;

    if(*pnt == 13) {
        Terminate(strNoConfig);
    }

    while(*pnt != 13) {
        if(maxLength == 0 || *pnt < 33 || *pnt > 126) {
            Terminate(strNoConfig);
        }
        *dest++ = *pnt++;
        maxLength--;
    }
    *dest = 0;
    pnt += 2;    //Skip CR and LF
    *src = pnt;
}


// Open file, return -1 if not found
byte OpenTweeterFile(char* fileExtension)
{
    char* fileName;

    GetAuxiliaryFilePath(fileExtension);
    regs.Bytes.B = 0;
    regs.Words.DE = (int)buffers->AuxFilePath;
    DosCall(_PARSE, &regs, REGS_MAIN, REGS_MAIN);
    fileName = (char*)regs.Words.HL;

    regs.Words.DE = (int)buffers->AuxFilePath;
    regs.Bytes.A = 1;   //Read-only
    DosCall(_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == _NOFIL) {
        return -1;
    } else if(regs.Bytes.A != 0) {
        ExplainDosErrorCode(regs.Bytes.A, buffers->Temp1);
        sprintf(buffers->Temp2, "Error when opening file %s: %s", fileName, buffers->Temp1);
        Terminate(buffers->Temp2);
    }
    debug2("File %s open OK\r\n", fileName);
    return regs.Bytes.B;
}


// Read file and return length, returns -1 if not found
int ReadWholeFile(char* fileExtension, char* destination, int maxLength)
{
    int length;

    fileHandle = OpenTweeterFile(fileExtension);
    if(fileHandle == 255) {
        fileHandle = 0;
        return -1;
    }
    
    regs.Bytes.B = fileHandle;
    regs.Words.DE = (int)destination;
    regs.Words.HL = maxLength;
    DosCall(_READ, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        ExplainDosErrorCode(regs.Bytes.A, buffers->Temp1);
        sprintf(buffers->Temp2, "Error when reading file: %s", buffers->Temp1);
        Terminate(buffers->Temp2);
    }
    
    length = regs.Words.HL;
    CloseFile(&fileHandle);
    return length;
}


void ReadConfigurationFile()
{
    int length = ReadWholeFile(strUSR, buffers->Temp1, 256);
    if(length == -1) {
        Terminate(strNoConfig);
    }
    buffers->Temp1[length] = 0;
    debug2("Config file read OK:\r\n%s\r\n", buffers->Temp1);

    tempPointer = buffers->Temp1;
    ParseConfigFileLine(&tempPointer, buffers->UserName, USERNAME_MAX_SIZE);
    ParseConfigFileLine(&tempPointer, buffers->UserId, USERID_MAX_SIZE);
    ParseConfigFileLine(&tempPointer, buffers->Token, MAX_TOKEN_LENGTH);
    ParseConfigFileLine(&tempPointer, buffers->TokenSecret, MAX_TOKEN_LENGTH);
}


void CreateConfigurationFile()
{
    GetAuxiliaryFilePath(strUSR);
    
    regs.Bytes.A = 0;
    regs.Bytes.B = 0;
    regs.Words.DE = (int)buffers->AuxFilePath;
    DosCall(_CREATE, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        ExplainDosErrorCode(regs.Bytes.A, buffers->Temp1);
        sprintf(buffers->Temp2, "Error when creating configuration file: %s", buffers->Temp1);
        Terminate(buffers->Temp2);
    }
    fileHandle = regs.Bytes.B;
    
    sprintf(buffers->Temp1, "%s\r\n%s\r\n%s\r\n%s\r\n", buffers->UserName, buffers->UserId, buffers->Token, buffers->TokenSecret);
    
    regs.Words.DE = (int)buffers->Temp1;
    regs.Words.HL = strlen(buffers->Temp1);
    
    DosCall(_WRITE, &regs, REGS_MAIN, REGS_AF);
    if(regs.Bytes.A != 0) {
        ExplainDosErrorCode(regs.Bytes.A, buffers->Temp1);
        sprintf(buffers->Temp2, "Error when writing to configuration file: %s", buffers->Temp1);
        Terminate(buffers->Temp2);
    }
    
    regs.Bytes.B = fileHandle;
    DosCall(_CLOSE, &regs, REGS_MAIN, REGS_NONE);
    fileHandle = 0;
}


//Find paramName=xxxxxxxx& (or finished with CR) in TcpInputData, then copy xxxxxxxxx to destination
//(paramName must end with "=")
void FindParameterInResponse(char* paramName, char* destination)
{
    char* value = strstr(TcpInputData, paramName);
    if(value == NULL) {
        sprintf(buffers->Temp1, "Unexpected reply from server: parameter \"%s\" is missing", paramName);
        Terminate(buffers->Temp1);
    }
    value += strlen(paramName);
    /*while(*value == '=' || *value == ' ') {
        value++;
    }*/
    
    while(*value != '&' && *value != 13 && *value != '\0') {
        *destination++ = *value++;
    }
    
    *destination = '\0';
}


void DoCommonInitialization()
{
    GetDateAndTime();
    GenerateTimestamp();
    GenerateNonce();
    GetServername();
    ResolveServerName();
}


void GenerateAuthorizationRequest()
{
    sprintf(buffers->Temp1, strAccessTokenEncryptionBase, strConsumerKey, buffers->Nonce, buffers->Timestamp, buffers->Token, buffers->Pin);
    PercentEncode(buffers->Temp1, buffers->Temp2, 0);
    PercentEncode("http://twitter.com/oauth/access_token", buffers->Temp1, 0);
    sprintf(buffers->Temp3, "POST&%s&%s", buffers->Temp1, buffers->Temp2);
    debug2("Request authorization base string:\r\n%s", buffers->Temp3);
    
    GenerateSignature(buffers->Temp3);
    debug2("Request token signature:\r\n%s", buffers->Signature);
    
    sprintf(buffers->Temp4, "   ,oauth_token=\"%s\"\r\n   ,oauth_verifier=\"%s\"\r\n", buffers->Token, buffers->Pin);
    debug2("Added to request: %s\r\n", buffers->Temp4);
    
    sprintf(TcpOutputData, strHttpRequestBase, strPOST, "/oauth/access_token", strConsumerKey, buffers->Nonce, buffers->Timestamp, buffers->Signature, buffers->Temp4, strEmpty);
    debug2("Request authorization HTTP request:\r\n%s\r\n", TcpOutputData);
}


void FindError(char* destination)
{
    char* value = strstr(TcpInputData, "<error>");
    if(value == NULL) {
        strcpy(destination, "no additional information available");
        return;
    }
    value += 7;
    
    while(*value != '<' && *value != '\0') {
        *destination++ = *value++;
    }
    
    *destination = '\0';
}


void DoTcpTransaction() {
    print("\r\nConnecting to server, please wait...");
    OpenTcpConnection();
    SendTcpData();
    ReceiveTcpData();
    CloseTcpConnection();
    print(" Ok\r\n\r\n");
}


void GetAuxiliaryFilePath(char* fileExtension)
{
    regs.Words.HL = (int)"PROGRAM";
    regs.Words.DE = (int)buffers->AuxFilePath;
    regs.Bytes.B = 128;
    DosCall(_GENV, &regs, REGS_MAIN, REGS_NONE);
    tempPointer = (char*)buffers->AuxFilePath + strlen(buffers->AuxFilePath) - 3;
    strcpy(tempPointer, fileExtension);
    debug3("Aux file path for %s: %s\r\n", fileExtension, buffers->AuxFilePath);
}


void ExplainDosErrorCode(byte code, char* destination)
{
    regs.Bytes.B = code;
    regs.Words.DE = (int)destination;
    DosCall(_EXPLAIN, &regs, REGS_MAIN, REGS_NONE);
}


void GenerateMessageRequest()
{
    int len;
    
    //* Generate signature base string

    strcpy(buffers->Temp1, "POST&");
    PercentEncode("http://twitter.com/statuses/update.xml", buffers->Temp1 + strlen(buffers->Temp1), 0);
    len = strlen(buffers->Temp1);
    buffers->Temp1[len] = '&';
    len++;
        
    sprintf(buffers->Temp4, strSendMessageEncryptionBase, strConsumerKey, buffers->Nonce, buffers->Timestamp, buffers->Token);
    PercentEncode(buffers->Temp4, buffers->Temp1 + len, 0);

    PercentEncode(buffers->MessageUTF8, buffers->Temp1 + strlen(buffers->Temp1), 2);
    debug2("Size of encryption base string for message send: %i\r\n", strlen(buffers->Temp1));
    debug2("Send message base string:\r\n%s\r\n", buffers->Temp1);

    //* Generate signature

    GenerateSignature(buffers->Temp1);
    debug2("Send message signature:\r\n%s\r\n", buffers->Signature);
    
    //* Generate HTTP request

    PercentEncode(buffers->MessageUTF8, buffers->EncodedMessage, 1);
    sprintf(TcpOutputData, strMessageHttpRequest, buffers->EncodedMessage, strConsumerKey, buffers->Nonce, buffers->Timestamp, buffers->Token, buffers->Signature);
    debug2("Send message HTTP request:\r\n%s\r\n", TcpOutputData);
}


void ConvertMessageToUTF8()
{
    if(buffers->CharMapType == 2) {
        ConvertMessageToUTF8_2bytes();
    } else {
        ConvertMessageToUTF8_1byte();
    }
}

void ConvertMessageToUTF8_1byte()
{
    byte ch;
    char* utfPointer = buffers->MessageUTF8;
    char* charPointerInMap;
    tempPointer = buffers->Message;
    
    while((ch = *tempPointer) != 0) {
        if(ch > 31 && ch < 127) {
            *utfPointer++ = ch;
        } else if(ch > 127 && ch != 255) {
            if(buffers->CharMapType == 0) {
                Terminate("File TWEETER.CHR was not found or was invalid.\r\n    Can't send non-standard ASCII characters.");
            }
            charPointerInMap = &(buffers->CharMap[(ch-128)*4]);
            if(*charPointerInMap == 0) {
                Terminate(strBadChar);
            }
            while(*charPointerInMap != 0) {
                *utfPointer++ = *charPointerInMap++;
            }
        } else {
            Terminate(strNotPrintable);            
        }
        tempPointer++;
    }
    *utfPointer = '\0';
    debug2("Message in UTF8: %s\r\n", buffers->MessageUTF8);
}


void ConvertMessageToUTF8_2bytes()
{
    byte chunkIndex = 0;
    byte* srcMsgPointer;
    byte* destMsgPointer=0;
    uint firstChunkCharacter;
    uint lastChunkCharacter;
    byte ch;
    uint twoByteChar = 0;
    long fileSize = 0;
    byte* utfCharPointer;

    debug2("Original message size: %i\r\n", strlen(buffers->Message));

    charmapFileHandle = OpenTweeterFile(strCHR);
    if(charmapFileHandle == 255) {
        charmapFileHandle = 0;
        Terminate("Unexpected error: I can't find TWEETER.CHR, but I could before");
    }
    
    regs.Bytes.A = 2;
    regs.Bytes.B = charmapFileHandle;
    regs.Words.DE = 0;
    regs.Words.HL = 0;
    DosCall(_SEEK, &regs, REGS_MAIN, REGS_MAIN);    
    ((uint*)&fileSize)[0] = regs.UWords.HL;
    ((uint*)&fileSize)[1] = regs.UWords.DE;
    debug2("Charmap real file size: %i\r\n", fileSize);
    numCharmapChunks = fileSize / CHARMAP_CHUNK_SIZE;
    if((numCharmapChunks * CHARMAP_CHUNK_SIZE) != 0) {
        numCharmapChunks++;
    }
    debug2("Number of charmap file chunks: %i\r\n", numCharmapChunks);

    regs.Bytes.A = 0;
    regs.Bytes.B = charmapFileHandle;
    regs.Words.DE = 0;
    regs.Words.HL = 5;
    DosCall(_SEEK, &regs, REGS_MAIN, REGS_NONE);    //Skip file header
    
    lastCharmapChunkIndex = 255;
    
    memset(buffers->MessageUTF8, 0, sizeof(buffers->MessageUTF8));
    while(chunkIndex < numCharmapChunks) {
        srcMsgPointer = buffers->Message;
        destMsgPointer = buffers->MessageUTF8;
        firstChunkCharacter = charmapMin + ((CHARMAP_CHUNK_SIZE / 2) * chunkIndex);
        lastChunkCharacter = firstChunkCharacter + (CHARMAP_CHUNK_SIZE / 2) - 1;
        debug4("Chunk %i, chars %x to %x\r\n", chunkIndex, firstChunkCharacter, lastChunkCharacter);
        while((ch = *srcMsgPointer) != 0) {
            if(ch < 32 || ch == 127) {
                Terminate(strNotPrintable);
            }
            else if(ch < 127) {
                if(chunkIndex == 0) {
                    *destMsgPointer = *srcMsgPointer;
                }
                srcMsgPointer++;
                destMsgPointer +=4;
                continue;
            }
            
            ((byte*)&twoByteChar)[1] = srcMsgPointer[0];
            ((byte*)&twoByteChar)[0] = srcMsgPointer[1];
            
            if((twoByteChar < charmapMin) || (twoByteChar > charmapMax)) {
                sprintf(buffers->Temp1, strBadChar, twoByteChar);
                Terminate(buffers->Temp1);
            }
            
            if(twoByteChar >= firstChunkCharacter && twoByteChar <= lastChunkCharacter) {
                if(lastCharmapChunkIndex != chunkIndex) {
                    ReadCharMapChunk(chunkIndex);
                }
                utfCharPointer = &(buffers->CharMap[(twoByteChar-firstChunkCharacter)*2]);
                if(*utfCharPointer == 0) {
                    sprintf(buffers->Temp1, strBadChar, twoByteChar);
                    Terminate(buffers->Temp1);
                }
                UTF16toUTF8(utfCharPointer, destMsgPointer);
            }
            srcMsgPointer += 2;
            destMsgPointer += 4;
        }
        chunkIndex++;
    }
    
    *destMsgPointer = 0;
    
    printhex("Converted expanded message: ", buffers->MessageUTF8, sizeof(buffers->MessageUTF8));
    CollapseMessage();
    printhex("Converted collapsed message: ", buffers->MessageUTF8, sizeof(buffers->MessageUTF8));
}


void CollapseMessage()
{
    byte* source = buffers->MessageUTF8;
    byte* dest = buffers->MessageUTF8;
    byte ch;
    byte charByteCount;

    while((ch = *source) != 0) {
        for(charByteCount = 4; ch != 0 && charByteCount > 0; charByteCount--)
        {
            *dest = ch;
            *source++;
            *dest++;
            ch = *source;
        }
        source += charByteCount;
    }
    
    *dest = 0;

    debug2("Collapsed message size: %i\r\n", strlen(buffers->MessageUTF8));
}


void ReadCharMapChunk(byte chunkIndex)
{
    unsigned long offsetFromLastChunk;

    debug2("Loading charmap chunk %i\r\n", chunkIndex);

    if(lastCharmapChunkIndex == 255) {
        offsetFromLastChunk = chunkIndex * CHARMAP_CHUNK_SIZE;
    } else {
        offsetFromLastChunk = (chunkIndex - lastCharmapChunkIndex - 1) * (CHARMAP_CHUNK_SIZE);
    }
    
    if(offsetFromLastChunk != 0) {
        regs.Bytes.A = 1;
        regs.Bytes.B = charmapFileHandle;
        regs.Words.DE = ((int*)&offsetFromLastChunk)[1];
        regs.Words.HL = ((int*)&offsetFromLastChunk)[0];
        DosCall(_SEEK, &regs, REGS_MAIN, REGS_AF);
        if(regs.Bytes.A != 0) {
            ExplainDosErrorCode(regs.Bytes.A, buffers->Temp1);
            sprintf(buffers->Temp2, "Error when opening TWEETER.CHR: %s", buffers->Temp1);
            Terminate(buffers->Temp2);
        }
    }
    
    regs.Bytes.B = charmapFileHandle;
    regs.Words.DE = (int)buffers->CharMap;
    regs.Words.HL = CHARMAP_CHUNK_SIZE;
    DosCall(_READ, &regs, REGS_MAIN, REGS_AF);
    if(regs.Bytes.A != 0) {
        ExplainDosErrorCode(regs.Bytes.A, buffers->Temp1);
        sprintf(buffers->Temp2, "Error when reading TWEETER.CHR: %s", buffers->Temp1);
        Terminate(buffers->Temp2);
    }
    
    lastCharmapChunkIndex = chunkIndex;
}


void ReadCharMap()
{
    int length = ReadWholeFile(strCHR, (char*)&(buffers->CharMapType), 509);
    debug2("Size of charmap file: %i\r\n", length);
    debug2("Charmap type: %i\r\n", buffers->CharMapType);
    if((buffers->CharMapType == 1 && length != 509) || 
        (buffers->CharMapType == 2 && length < 7) ||
        (buffers->CharMapType > 2)) {
         buffers->CharMapType = 0;
    } else if(buffers->CharMapType == 2) {
        ((byte*)&charmapMin)[0] = buffers->CharMap[1];
        ((byte*)&charmapMin)[1] = buffers->CharMap[0];
        ((byte*)&charmapMax)[0] = buffers->CharMap[3];
        ((byte*)&charmapMax)[1] = buffers->CharMap[2];
        debug2("Charmap min: %x", charmapMin);
        debug2("Charmap max: %x", charmapMax);
    }
}


void CloseFile(byte* fileHandle)
{
    if(*fileHandle != 0) {
        regs.Bytes.B = *fileHandle;
        DosCall(_CLOSE, &regs, REGS_MAIN, REGS_NONE);
        *fileHandle = 0;
    }
}


void UTF16toUTF8(byte* src, byte* dest)
{
    byte char0 = src[0];
    byte char1 = src[1];

    if((char0 & 0xF8) == 0) {
        dest[0] = (byte)(0xC0 | ((char0 & 7) << 2) | ((char1 & 0xC0) >> 6));
        dest[1] = (byte)(0x80 | (char1 & 0x3F));
    }
    else {
        dest[0] = (byte)(0xE0 | ((char0 & 0xF0) >> 4));
        dest[1] = (byte)(0x80 | ((char0 & 0x0F) << 2) | ((char1 & 0xC0) >> 6));
        dest[2] = (byte)(0x80 | (char1 & 0x3F));
    }
}

#ifdef DEBUG

void PrintHex(byte* src, int leng)
{
    byte ch=0;
    while(leng>0) {
        ch = *src;
        printf(" %x", ch);
        src++;
        leng--;
    }
}

#endif
