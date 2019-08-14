/* HTTP getter 1.3
   By Konamiman 1/2011 v1.1
   By Oduvaldo Pavan Junior 07/2019 v1.3

   ASM.LIB, BASE64.LIB and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   printf_simple.rel and putchar.rel can be obtained at 
   www.konamiman.com or retrieved from Fusion-C

   sdcc --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 196 --no-std-crt0 
   crt0_msxdos_advanced.rel printf_simple.rel putchar.rel base64.lib asm.lib hget.c
   
   And then:
   
   hex2bin -e com hget.ihx

   Comments are welcome: konamiman@konamiman.com (original creator)
                         ducasp@gmail.com (1.3 update creator)

   Version 1.3 should be TCP-IP v1.1 compliant, that means, TLS support, so you
   can download files from https sites if your device is compliant.
   It also removes an extra tick wait after calling TCPIP_WAIT, as there seems
   to have no reason for it and it can lower the performance. Any needed WAIT
   should be already done by adapter UNAPI when calling TCPIP_WAIT.
   Also I've changed the download progress to a bar, it changes every 4% 
   increment of file size of known file size or there is a moving character if 
   file size is unknown. This is way easier on VDP / CALLs and allow better 
   performance on fast adapters that can use the extra CPU time.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

//These are available at www.konamiman.com
#include "asm.h"
#include "base64.h"

typedef unsigned char bool;
#define false (0)
#define true (!false)

#define _TERM0 0
#define _CONIN 1
#define _INNOE 8
#define _BUFIN 0x0A
#define _CONST 0x0B
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

#define TICKS_TO_WAIT (20*60)
#define SYSTIMER ((uint*)0xFC9E)

#define TCP_BUFFER_SIZE (1024)
#define TCPOUT_STEP_SIZE (512)

#define HTTP_DEFAULT_PORT (80)
#define HTTPS_DEFAULT_PORT (443)

#define TCPIP_CAPAB_VERIFY_CERTIFICATE 16
#define TCPFLAGS_USE_TLS 4
#define TCPFLAGS_VERIFY_CERTIFICATE 8

#define MAX_REDIRECTIONS 10

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

    /* Strings */

#define strDefaultFilename "index.htm";

const char* strTitle=
    "HTTP file downloader 1.3\r\n"
    "By Oduvaldo (ducasp@gmail.com) 7/2019\r\n"
    "Based on HGET 1.1 by Konamiman\r\n"
    "\r\n";

const char* strUseQuestionMarkForHelp=
    "\r\nFor extended help: hget ?\r\n";

const char* strShortUsage=
    "Usage: hget <file URL>|<local file with the URL>|con [/l:<local file name>]\r\n"
    "  [/n] [/t] [/c] [/v] [/h] [/x:<headers file name>] [/a:<user>:<password>]\r\n";

const char* strLongUsage=
    "\r\n"
    "/c: Continue downloading a partially downloaded file.\r\n"
    "/v: Verbose mode, shows all the HTTP headers sent and received.\r\n"
    "/h: Show HTTP headers only, do not download any file.\r\n"
    "/x: Send the contents of the specified text file as extra HTTP headers.\r\n"
    "/a: Authentication parameters (basic HTTP authentication is used).\r\n"
	"/u: Unsafe https, do not validate server certificate and hostname.\r\n"
	"/n: Authenticate server certificate but not the hostname on https.\r\n"
    "\r\n"
    "If no local file name is specified, the name is taken from the\r\n"
    "last part of the URL. If the URL ends with a slash or has no\r\n"
    "slashes, then INDEX.HTM is used.\r\n"
    "\r\n"
    "If an existing local text file is specified instead of an URL,\r\n"
    "then the URL is read from that file (useful for very large URLs).\r\n"
    "\r\n"
    "If \"con\" is specified instead of an URL, the name is read from the console\r\n"
    "(useful for very large URLs or for redirecting, e.g. \"type url.txt|hget con\")\r\n"
    "\r\n"
    "TIP: Use /l:con to display the contents instead of saving to a file.";

const char* strInvParam = "Invalid parameter";
const char* strNoNetwork = "No network connection available";
const char* strCRLF = "\r\n";
const char* strWwwAuthenticate = "WWW-Authenticate";
#define TCP_CONN_FAILURE_KNOWN_REASONS 20
const char* strConnFailureReasons[21] = {
	"Unknow failure opening connection\r\n",
	"This connection has never been used since the implementation was initialized.\r\n",
	"The TCPIP_TCP_CLOSE method was called.\r\n",
	"The TCPIP_TCP_ABORT method was called.\r\n",
	"A RST segment was received (the connection was refused or aborted by the remote host).\r\n",
	"The user timeout expired.\r\n",
	"The connection establishment timeout expired.\r\n",
	"Network connection was lost while the TCP connection was open.\r\n",
	"ICMP \"Destination unreachable\" message received.\r\n",
	"TLS: The server did not provide a certificate.\r\n",
	"TLS: Invalid server certificate.\r\n",
	"TLS: Invalid server certificate (the host name didn't match).\r\n",
	"TLS: Invalid server certificate (expired).\r\n",
	"TLS: Invalid server certificate (self-signed).\r\n",
	"TLS: Invalid server certificate (untrusted root).\r\n",
	"TLS: Invalid server certificate (revoked).\r\n",
	"TLS: Invalid server certificate (invalid certificate authority).\r\n",
	"TLS: Invalid server certificate (invalid TLS version or cypher suite).\r\n",
	"TLS: Our certificate was rejected by the peer.\r\n",
	"TLS: Other error.\r\n",
	"An error that is unknown to this software occurred...\r\n"};


    /* Variables */

byte headersOnly = 0;
byte continueDownloading = 0;
byte verboseMode = 0;
byte fileHandle = 0;
byte conn = 0;
char* credentials;
char* domainName;
char localFileName[128];
char** arguments;
int argumentsCount;
byte continueReceived;
byte redirectionRequested = 0;
byte authenticationRequested;
byte authenticationSent;
int remainingInputData = 0;
byte* inputDataPointer;
int emptyLineReaded;
long contentLength,blockSize,currentBlock;
bool isFirstUpdate;
int isChunkedTransfer;
long currentChunkSize = 0;
int newLocationReceived;
int acceptsPartialDownloads;
long existingFileSize;
long receivedLength = 0;
byte* TcpInputData;
#define TcpOutputData TcpInputData
char extraHeadersFilePath[128];
byte remoteFilePath[256];
byte Buffer[512];
byte headerLine[256];
byte responseStatus[256];
char statusLine[256];
char redirectionFullLocation[256];
byte dosVersion[6];
int responseStatusCode;
int responseStatusCodeFirstDigit;
char* headerTitle;
char* headerContents;
Z80_registers regs;
unapi_code_block* codeBlock;
int ticksWaited;
int sysTimerHold;
char unapiImplementationName[80];
byte localFileIsConsole;
byte redirectionUrlIsNewDomainName;
bool zeroContentLengthAnnounced;
typedef struct {
    byte remoteIP[4];
    uint remotePort;
    uint localPort;
    int userTimeout;
    byte flags;
	int hostName;
} t_TcpConnectionParameters;

t_TcpConnectionParameters* TcpConnectionParameters;
bool TlsIsSupported = false;
bool useHttps = false;
bool mustCheckCertificate = true;
bool mustCheckHostName = true;
bool safeTlsIsSupported = true;
byte redirectionRequests = 0;
byte tcpIpSpecificationVersionMain;
byte tcpIpSpecificationVersionSecondary;

    /* Some handy defines */

#define PrintNewLine() print(strCRLF)
#define LetTcpipBreathe() UnapiCall(codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE)
#define SkipCharsWhile(pointer, ch) {while(*pointer == ch) pointer++;}
#define SkipCharsUntil(pointer, ch) {while(*pointer != ch) pointer++;}
#define SkipLF() GetInputByte()
#define ToLowerCase(ch) {ch |= 32;}


    /* Function prototypes */

int NoParameters();
void PrintTitle();
void PrintUsageAndEnd(bool printLongUsage);
void Terminate(const char* errorMessage);
void CheckDosVersion();
void InitializeTcpipUnapi();
void CheckTcpipCapabilities();
bool LongHelpRequested();
void ProcessParameters();
void ProcessUrl(char* url, byte isRedirection);
void ProcessOptions();
void GetLocalFilePathIfNecessary();
char* SkipInitialColon(char* string);
int StringStartsWith(const char* stringToCheck, const char* startingToken);
void CheckNetworkConnection();
char* FindLastSlash(char* string);
char* FindFirstSlash(char* string);
char* FindFirstSemicolon(char* string);
void ExtractPortNumberFromDomainName();
void DoHttpWork();
void SendHttpRequest();
void ReadResponseHeaders();
void SendLineToTcp(char* string);
int DestinationFileExists();
int strcmpi(const char *a1, const char *a2);
int strncmpi(const char *a1, const char *a2, unsigned size);
void ResolveServerName();
void OpenTcpConnection();
void AbortIfEscIsPressed();
int EscIsPressed();
void CloseTcpConnection();
void SendTcpData(byte* data, int dataSize);
void print(char* s);
int ArgumentIs(char* argument, char* argumentStart);
char* ExplainDosErrorCode(byte code, char* destination);
void CloseLocalFile();
void InitializeHttpVariables();
void CheckHeaderErrors();
void DownloadHttpContents();
void SendCredentialsIfNecessary();
void ReadResponseStatus();
void ProcessResponseStatus();
void ReadNextHeader();
void ProcessNextHeader();
void TerminateWithHttpError();
byte GetInputByte();
void ExtractHeaderTitleAndContents();
int HeaderTitleIs(char* string);
int HeaderContentsIs(char* string);
void ReadAsMuchTcpDataAsPossible();
void DiscardBogusHttpContent();
void ResetTcpBuffer();
void PrintRedirectionInformation();
void PrintLongLength(char* message, long length, byte showOnlyKBytes);
int ContainsProtocolSpecifier(char* url);
char* ltoa(unsigned long num, char *string);
void TerminateWithDosErrorCode(char* message, byte errorCode);
void GetExsitingFileInfo();
void SendPartialRequestIfNecessary();
void OpenLocalFile();
void CreateLocalFile();
void UpdateReceivingMessage();
void WriteContentsToFile(byte* dataPointer, int size);
void PrepareLocalFileForAppend();
void DoDirectDatatransfer();
void DoChunkedDataTransfer();
long GetNextChunkSize();
void GetUnapiImplementationNameAndVersion();
void CheckIfLocalFileIsConsole();
int FirstParameterIsExistingfileName();
void ReadUrlFromFile();
int CharIsWhitespace(char ch);
void InitializeBufferPointers();
byte OpenFile(char* path, byte* fileHandle);
void CloseFile(byte fileHandle);
byte ReadFromFile(byte fileHandle, byte* address, int* amount);
void SendExtraHeadersIfNecessary();
byte CheckIfFileExists(char* path);
void RestoreDefaultAbortRoutine();
void DisableAutoAbort();
void TerminateWithCtrlCOrCtrlStop();
void EnsureTcpConnectionIsStillOpen();
void ReadUrlFromConsole();


/**********************
 ***  MAIN is here  ***
 **********************/

int main(char** argv, int argc)
{
	useHttps = false;
	mustCheckCertificate = true;
	mustCheckHostName = true;
	TlsIsSupported = false;
    arguments = argv;
    argumentsCount = argc;

    PrintTitle();
    if(NoParameters()) {
        PrintUsageAndEnd(false);
    }
    if(LongHelpRequested()) 
    {
        PrintUsageAndEnd(true);
    }

    DisableAutoAbort();
    InitializeBufferPointers();
    CheckDosVersion();
    InitializeTcpipUnapi();
    GetUnapiImplementationNameAndVersion();
    CheckTcpipCapabilities();
    ProcessParameters();
    CheckNetworkConnection();

    printf("Local file path: %s\r\n", localFileName);
    if(continueDownloading) {
        PrintLongLength("Local file size: ", existingFileSize, 0);
        PrintNewLine();
    }
    PrintNewLine();

    print("* Press ESC at any time to cancel the process\r\n\r\n");

    DoHttpWork();

    Terminate(NULL);
    return 0;
}


/****************************
 ***  FUNCTIONS are here  ***
 ****************************/

void InitializeBufferPointers()
{
    TcpConnectionParameters = (t_TcpConnectionParameters*)0x8000;
    domainName =(char*)0x8100;
    codeBlock = (unapi_code_block*)0x8300;
    TcpInputData = (byte*)0x8400;
}


int NoParameters()
{
    return (argumentsCount == 0);
}


void PrintTitle()
{
    print(strTitle);
}


void PrintUsageAndEnd(bool printLongUsage)
{
    print(strShortUsage);
    print(printLongUsage ? strLongUsage : strUseQuestionMarkForHelp);
    DosCall(0, &regs, REGS_MAIN, REGS_NONE);
}


void Terminate(const char* errorMessage)
{
    if(errorMessage != NULL) {
        printf("\r\x1BK*** %s\r\n", errorMessage);
    }

    CloseTcpConnection();
    CloseLocalFile();

    RestoreDefaultAbortRoutine();

    regs.Bytes.B = (errorMessage == NULL ? 0 : 1);
    DosCall(_TERM, &regs, REGS_NONE, REGS_NONE);
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
    sprintf(dosVersion, "%i.%i%i", regs.Bytes.B, (regs.Bytes.C >> 4) & 0xF, regs.Bytes.C & 0xF);
    debug("DOS version OK");
}


void InitializeTcpipUnapi()
{
    int i;

    i = UnapiGetCount("TCP/IP");
    if(i==0) {
        Terminate("No TCP/IP UNAPI implementations found");
    }
    UnapiBuildCodeBlock(NULL, 1, codeBlock);

    regs.Bytes.B = 0;
    UnapiCall(codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_MAIN);

    TcpConnectionParameters->remotePort = HTTP_DEFAULT_PORT;
    TcpConnectionParameters->localPort = 0xFFFF;
    TcpConnectionParameters->userTimeout = 0;
    TcpConnectionParameters->flags = 0;
    debug("TCP/IP UNAPI initialized OK");
}


void CheckTcpipCapabilities()
{
    regs.Bytes.B = 1;
    UnapiCall(codeBlock, TCPIP_GET_CAPAB, &regs, REGS_MAIN, REGS_MAIN);
    if((regs.Bytes.L & (1 << 3)) == 0) {
        Terminate("This TCP/IP implementation does not support active TCP connections.");
    }

    TlsIsSupported = false;
    safeTlsIsSupported = false;

    if(tcpIpSpecificationVersionMain == 0 || (tcpIpSpecificationVersionMain == 1 && tcpIpSpecificationVersionSecondary == 0))
        return; //TCP/IP UNAPI <1.1 has no TLS support at all

    if(regs.Bytes.D & TCPIP_CAPAB_VERIFY_CERTIFICATE)
		safeTlsIsSupported = true;

    regs.Bytes.B = 4;
    UnapiCall(codeBlock, TCPIP_GET_CAPAB, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.H & 1)
        TlsIsSupported = true;
}


bool LongHelpRequested()
{
    return strcmpi(arguments[0], "?") == 0;
}


void ProcessParameters()
{		
    if(strcmpi(arguments[0], "con") == 0) {
        ReadUrlFromConsole();
        printf("URL to download: %s\r\n", domainName);
        ProcessUrl(domainName, 0);
    } else if(FirstParameterIsExistingfileName()) {
        ReadUrlFromFile();
        printf("URL to download: %s\r\n", domainName);
        ProcessUrl(domainName, 0);
    } else {
        *domainName = '\0';
        ProcessUrl(arguments[0], 0);
    }
	
	ProcessOptions();
}


int FirstParameterIsExistingfileName()
{
    regs.Words.DE = (int)arguments[0];
    regs.Bytes.B = 0;
    regs.Words.IX = (int)Buffer;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
    return regs.Bytes.A == 0;
}


void ReadUrlFromFile()
{
    byte tempFileHandle;
    byte data;
    char* pointer;
    byte error;
    int amount;

    error = OpenFile(arguments[0], &tempFileHandle);
    if(error != 0) {
        TerminateWithDosErrorCode("Error when opening URL file: ", error);
    }

    amount = 255;
    error = ReadFromFile(tempFileHandle, domainName, &amount);
    if(error != 0) {
        TerminateWithDosErrorCode("Error when reading URL file: ", error);
    }
    domainName[amount] = 13;

    CloseFile(tempFileHandle);

    pointer = domainName;
    pointer--;
    do {
        ++pointer;
        data = *pointer;
        if((data < 32 && !CharIsWhitespace(data)) || (data == 127)) {
            Terminate("ERROR: The specified URL file is not a valid text file.");
        }
    } while(!CharIsWhitespace(data));

    if(pointer == domainName) {
        Terminate("ERROR: The specified URL file is empty.");
    }
    *pointer = '\0';
}


byte ReadFromFile(byte fileHandle, byte* address, int* amount)
{
    regs.Bytes.B = fileHandle;
    regs.Words.DE = (int)address;
    regs.Words.HL = *amount;
    DosCall(_READ, &regs, REGS_MAIN, REGS_MAIN);
    *amount = regs.Words.HL;
    return regs.Bytes.A;
}


int CharIsWhitespace(char ch)
{
    return (ch==' ' || ch==13 || ch==10 || ch == 9);
}


void ProcessUrl(char* url, byte isRedirection)
{
    char* pointer;

    if(url[0] == '/') {
        if(isRedirection) {
            redirectionUrlIsNewDomainName = 0;
        } else {
            Terminate(strInvParam);
        }
    } else if(StringStartsWith(url, "http://")) {
		TcpConnectionParameters->remotePort = HTTP_DEFAULT_PORT;
		TcpConnectionParameters->flags = 0 ;
        if(isRedirection) {
			if (useHttps)
				redirectionUrlIsNewDomainName = 1;
			else
			{
				pointer = FindFirstSlash(url+7);
				if ((pointer)&&(strncmpi(url+7, domainName, (pointer-url-7))))
					redirectionUrlIsNewDomainName = 1;
				else
					redirectionUrlIsNewDomainName = 0;
			}
        }
        strcpy(domainName, url + 7);
		useHttps = false;
    } else if((TlsIsSupported)&&(StringStartsWith(url, "https://"))) {
        if(isRedirection) {
			if (!useHttps)
				redirectionUrlIsNewDomainName = 1;
			else
			{
				pointer = FindFirstSlash(url+8);
				if ((pointer)&&(strncmpi(url+8, domainName, (pointer-url-8))))
					redirectionUrlIsNewDomainName = 1;
				else
					redirectionUrlIsNewDomainName = 0;
			}
        }
        strcpy(domainName, url + 8);
		useHttps = true;
		TcpConnectionParameters->remotePort = HTTPS_DEFAULT_PORT;
		TcpConnectionParameters->flags = TcpConnectionParameters->flags | TCPFLAGS_USE_TLS ;		
    } else if(ContainsProtocolSpecifier(url)) {
        if(isRedirection) {
            Terminate("Redirection request to HTTPS received, but this TCP/IP doesn't support TLS.");
        } else {
            Terminate("This TCP/IP implementation supports the HTTP protocol only.");
        }
    } /*else if(domainName[0]=='\0') {
        if(isRedirection) {
            Terminate("Redirection request received, but the new URL is empty.");
        } else {
            Terminate(strInvParam);
        }
    }*/ else {
        if(isRedirection) {
            Terminate("Redirection request received, but the new URL is not absolute.");
        }
        strcpy(domainName, url);
    }

    if(url[0] == '/') {
        strcpy(remoteFilePath, url);
    } else {
        remoteFilePath[0] = '/';
        remoteFilePath[1] = '\0';
        pointer = FindFirstSlash(domainName);
        if(pointer != NULL) {
            *pointer = '\0';
            strcpy(remoteFilePath+1, pointer+1);
        }

        ExtractPortNumberFromDomainName();
    }

    debug2("URL: %s", domainName);
    debug2("Remote resource: %s", remoteFilePath);

    debug2("Port number: %i", TcpConnectionParameters->remotePort);
}


int ContainsProtocolSpecifier(char* url)
{
    return (strstr(url, "://") != NULL);
}


void ExtractPortNumberFromDomainName()
{
    char* pointer;

    pointer = FindFirstSemicolon(domainName);
    if(pointer == NULL) {
		if (!useHttps)
			TcpConnectionParameters->remotePort = HTTP_DEFAULT_PORT;
		else
			TcpConnectionParameters->remotePort = HTTPS_DEFAULT_PORT;
        return;
    }

    *pointer = '\0';
    pointer++;
    TcpConnectionParameters->remotePort = atoi(pointer);
}


void ProcessOptions()
{
    int i;
    byte error;

    localFileName[0] = '\0';
    extraHeadersFilePath[0] = '\0';
    credentials = NULL;

    for(i=1; i<argumentsCount; i++) {
        if(ArgumentIs(arguments[i], "v")) {
            verboseMode = 1;
            debug("Verbose mode");
        } else if(ArgumentIs(arguments[i], "u")) {
            mustCheckCertificate = false;
			mustCheckHostName = false;
            debug("UNSAFE TLS");
        } else if(ArgumentIs(arguments[i], "n")) {
            mustCheckCertificate = true;
			mustCheckHostName = false;
            debug("TLS won't check host name");
        } else if(ArgumentIs(arguments[i], "c")) {
            continueDownloading = 1;
            debug("Continue downloading");
        } else if(ArgumentIs(arguments[i], "h")) {
            headersOnly = 1;
            debug("Headers only");
        } else if(ArgumentIs(arguments[i], "l")) {
            strcpy(localFileName, SkipInitialColon(arguments[i] + 2));
            debug2("Specified local filename: %s", localFileName);
        } else if(ArgumentIs(arguments[i], "a")) {
            credentials = SkipInitialColon(arguments[i] + 2);
            debug2("Credentials: %s", credentials);
        } else if(ArgumentIs(arguments[i], "x")) {
            strcpy(extraHeadersFilePath, SkipInitialColon(arguments[i] + 2));
        } else {
            Terminate(strInvParam);
        }
    }

    GetLocalFilePathIfNecessary();
    GetExsitingFileInfo();

    if(extraHeadersFilePath[0] != '\0') {
        error = CheckIfFileExists(extraHeadersFilePath);
        if(error != 0) {
            TerminateWithDosErrorCode("Error when searching the extra headers file: ", error);
        }
    }
}


void GetExsitingFileInfo()
{
    if(!continueDownloading) {
        return;
    }

    if(!DestinationFileExists()) {
        print("WARNING: Resume download requested but local file does not exist.\r\n         A new download will be started.\r\n\r\n");
        continueDownloading = 0;
    }
}


void GetLocalFilePathIfNecessary()
{
    char* pointer;

    if(localFileName[0] != '\0') {
        return;
    }

    pointer = FindLastSlash(remoteFilePath);
    if(pointer == NULL || pointer[1] == '\0') {
        pointer = strDefaultFilename;
        strcpy(localFileName, pointer);
    } else {
        strcpy(localFileName, pointer + 1);
    }

    debug2("Calculated local filename: %s", localFileName);
}


char* SkipInitialColon(char* string) {
    if(*string == ':') {
        return string + 1;
    } else {
        return string;
    }
}


int StringStartsWith(const char* stringToCheck, const char* startingToken)
{
    int len;
    len = strlen(startingToken);
    return strncmpi(stringToCheck, startingToken, len) == 0;
}


void CheckNetworkConnection()
{
    UnapiCall(codeBlock, TCPIP_NET_STATE, &regs, REGS_NONE, REGS_MAIN);
    if(regs.Bytes.B == 0 || regs.Bytes.B == 3) {
        Terminate(strNoNetwork);
    }
}


void InitializeVariables()
{
}


char* FindLastSlash(char* string)
{
    char* pointer;

    pointer = string + strlen(string);
    while(pointer >= string) {
        if(*pointer == '/') {
            return pointer;
        }
        pointer--;
    }

    return NULL;
}


char* FindFirstSlash(char* string)
{
    return strstr(string, "/");
}


char* FindFirstSemicolon(char* string)
{
    return strstr(string, ":");
}


void DoHttpWork()
{
    authenticationRequested = 0;
	redirectionRequests = 0;

    ResetTcpBuffer();
    ResolveServerName();
    OpenTcpConnection();

    do {
        InitializeHttpVariables();
        SendHttpRequest();
        ReadResponseHeaders();
        CheckHeaderErrors();
        if(redirectionRequested) {
            PrintRedirectionInformation();
            if(redirectionUrlIsNewDomainName) {
                CloseTcpConnection();
                ResolveServerName();
                OpenTcpConnection();
            }
            ResetTcpBuffer();
        } else if(continueReceived || authenticationRequested) {
            DiscardBogusHttpContent();
        }
    } while(continueReceived || redirectionRequested || authenticationRequested);

    if(headersOnly) {
        return;
    }

    if(isChunkedTransfer) {
        print("Content size is unknown (chunked data transfer)\r\n\r\n");
		DownloadHttpContents();
    } else if(contentLength != 0) {
        PrintLongLength("Content size: ", contentLength, 0);
        PrintNewLine();
        PrintNewLine();
		DownloadHttpContents();
    }

}


void PrintRedirectionInformation()
{
    printf("* Redirecting to: %s\r\n\r\n", redirectionFullLocation);	
}


void PrintLongLength(char* message, long length, byte showOnlyKBytes)
{
    long kbytes;
    int bytes;

    if(showOnlyKBytes) {
        print(message);
    } else {
        printf("%s%s bytes", message, ltoa(length, Buffer));
    }

    if(showOnlyKBytes || length >= 1024*10) {
        kbytes = length / 1024;
        bytes = length % 1024;
        if(bytes >= 512) {
            kbytes++;
        }
        if(showOnlyKBytes) {
            printf("%s KBytes", ltoa(kbytes, Buffer));
        } else {
            printf(" (%s KBytes)", ltoa(kbytes, Buffer));
        }
    }
}


void ResetTcpBuffer()
{
    remainingInputData = 0;
    inputDataPointer = TcpInputData;
}


void DiscardBogusHttpContent()
{
    while(remainingInputData > 0) {
        GetInputByte();
    }
}


void InitializeHttpVariables()
{
    redirectionRequested = 0;
    authenticationSent = 0;
    continueReceived = 0;
    isChunkedTransfer = 0;
    contentLength = 0;
    newLocationReceived = 0;
    acceptsPartialDownloads = 1;
}


void SendHttpRequest()
{
    sprintf(TcpOutputData, "%s %s HTTP/1.1\r\n", headersOnly ? "HEAD" : "GET", remoteFilePath);
    SendLineToTcp(TcpOutputData);
    sprintf(TcpOutputData, "Host: %s\r\n", domainName);
    SendLineToTcp(TcpOutputData);
    sprintf(TcpOutputData, "User-Agent: HGET/1.3 (MSX-DOS %s; TCP/IP UNAPI; %s)\r\n", dosVersion, unapiImplementationName);
    SendLineToTcp(TcpOutputData);
    SendCredentialsIfNecessary();
    SendPartialRequestIfNecessary();
    SendExtraHeadersIfNecessary();
    SendLineToTcp(strCRLF);
    if(verboseMode) {
        PrintNewLine();
    }
}


void SendExtraHeadersIfNecessary()
{
    byte tempFileHandle;
    int amount;
    byte error;
    byte data;
    byte* pointer;

    if(extraHeadersFilePath[0] == '\0') {
        return;
    }

    error = OpenFile(extraHeadersFilePath, &tempFileHandle);
    if(error != 0) {
        TerminateWithDosErrorCode("Error when opening extra headers file: ", error);
    }

    while(1) {
        amount = TCP_BUFFER_SIZE;
        error = ReadFromFile(tempFileHandle, TcpOutputData, &amount);
        if(error != 0 && error != _EOF) {
            CloseFile(tempFileHandle);
            TerminateWithDosErrorCode("Error when reading extra headers file: ", error);
        }

        if(amount == 0) {
            break;
        }

        data = 10;
        pointer = TcpOutputData;
        while(amount > 0 && data != 0x1A) {
            if(data == 10 && verboseMode) {
                print("--> ");
            }

            data = *pointer;
            if(data == 0x1A) {
                break;
            }

            if(verboseMode) {
                putchar(data);
            }

            SendTcpData(pointer, 1);
            pointer++;
            amount--;
        }

        if(data == 0x1A) {
            break;
        }
    }

    CloseFile(tempFileHandle);
}


void SendPartialRequestIfNecessary()
{
    if(continueDownloading) {
        sprintf(TcpOutputData, "Range: bytes=%s-\r\n", ltoa(existingFileSize, TcpOutputData+100));
        SendLineToTcp(TcpOutputData);
    }
}


void SendCredentialsIfNecessary()
{
    int encodedLength;

    if(authenticationRequested) {
        Base64Init(0);
        encodedLength = Base64EncodeChunk(credentials, TcpOutputData, strlen(credentials),1);
        TcpOutputData[encodedLength] = '\0';
        encodedLength++;
        sprintf(&TcpOutputData[encodedLength], "Authorization: Basic %s\r\n", TcpOutputData);
        SendLineToTcp(&TcpOutputData[encodedLength]);
        authenticationSent = 1;
    }
}


void ReadResponseHeaders()
{
    emptyLineReaded = 0;
    zeroContentLengthAnnounced = false;

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
    debug2("Response status code: %i", responseStatusCode);
    debug2("Response status code first digit: %i", responseStatusCodeFirstDigit);
}


void ProcessResponseStatus()
{
    if(responseStatusCode == 401) {
        if(authenticationSent) {
            Terminate("Authentication failed");
        } else {
            authenticationRequested = 1;
        }
        return;
    }

    authenticationRequested = 0;

    if(responseStatusCodeFirstDigit == 1) {
        continueReceived = 1;
    } else if(responseStatusCodeFirstDigit == 3) {
        redirectionRequested = 1;
		++redirectionRequests;
		if (redirectionRequests>MAX_REDIRECTIONS)
			Terminate ("ERROR: Too many redirects!\r\n");
    } else if(responseStatusCodeFirstDigit == 2 && continueDownloading && responseStatusCode != 206) {
        Terminate("ERROR: Resume download was requested, but the server started a new download.");
    } else if(responseStatusCodeFirstDigit != 2) {
        TerminateWithHttpError();
    }
}


void TerminateWithHttpError()
{
    char* pointer = statusLine;

    if(headersOnly) {
        Terminate(NULL);
    }

    SkipCharsUntil(pointer, ' ');
    SkipCharsWhile(pointer, ' ');
    sprintf(Buffer, "Error returned by server: %s", pointer);
    Terminate(Buffer);
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
        if(headersOnly || verboseMode) {
            PrintNewLine();
        }
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

    if(headersOnly) {
        printf("%s\r\n", headerLine);
    } else if(verboseMode) {
        printf("<-- %s\r\n", headerLine);
    }
}


void ProcessNextHeader()
{
    char* pointer;

    if(emptyLineReaded) {
        return;
    }

    if(continueReceived) {
        return;
    }

    ExtractHeaderTitleAndContents();

    if(HeaderTitleIs("Content-Length")) {
        contentLength = atol(headerContents);
        if(contentLength == 0) {
            zeroContentLengthAnnounced = true;
        }
        return;
    }

    if(HeaderTitleIs("Transfer-Encoding")) {
        if(HeaderContentsIs("Chunked")) {
            isChunkedTransfer = 1;
        } else if(!headersOnly) {
            printf("WARNING: Unknown transfer encoding: '%s'\r\n\r\n", headerContents);
        }
        return;
    }

    if(HeaderTitleIs("WWW-Authenticate") && !StringStartsWith(headerContents, "Basic")) {
        pointer = headerContents;
        SkipCharsUntil(pointer, ' ');
        *pointer = '\0';
        sprintf(Buffer, "ERROR: Unknown authentication method requested: '%s'", headerContents);
        Terminate(Buffer);
    }

    if(HeaderTitleIs("Location")) {
        strcpy(redirectionFullLocation, headerContents);
        newLocationReceived = 1;
        ProcessUrl(headerContents, 1);
        return;
    }

    if(HeaderTitleIs("Accept-Ranges") && HeaderContentsIs("none")) {
        acceptsPartialDownloads = 0;
    }
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

    debug3("Header title: %s, contents: %s", headerTitle, headerContents);
}


void CheckHeaderErrors()
{
    if(contentLength == 0 && !zeroContentLengthAnnounced && !isChunkedTransfer) {
        print("WARNING: Unknown transfer length. Will retrieve data until connection is closed.\r\n");
    }

    if(redirectionRequested && !newLocationReceived) {
        Terminate("ERROR: Redirection was requested, but the new location was not provided.");
    }

    if(authenticationRequested && credentials == NULL) {
        Terminate("ERROR: Server requires authentication, but no credentials were provided.");
    }

    if(continueDownloading && !acceptsPartialDownloads && responseStatusCodeFirstDigit == 2) {
        Terminate("ERROR: Resume download requested, but the server does not support partial downloads.");
    }
}


int HeaderTitleIs(char* string)
{
    return strcmpi(headerTitle, string) == 0;
}


int HeaderContentsIs(char* string)
{
    return strcmpi(headerContents, string) == 0;
}


void SendLineToTcp(char* string)
{
    int len;

    if(verboseMode && string[0] != (char)13) {
        print("--> ");
        print(string);
    }

    len = strlen(string);
    SendTcpData(string, len);
}


void EnsureThereIsTcpDataAvailable()
{
    ticksWaited = 0;

	sysTimerHold = *SYSTIMER;
	while(remainingInputData == 0) {						
		LetTcpipBreathe();
		if (sysTimerHold != *SYSTIMER)
		{
			ticksWaited++;
			sysTimerHold = *SYSTIMER;
		}
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
    UnapiCall(codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
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
    UnapiCall(codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        sprintf(Buffer, "Unexpected error when reading TCP data (%i)", regs.Bytes.A);
        Terminate(Buffer);
    }
    remainingInputData = regs.UWords.BC;
    inputDataPointer = TcpInputData;
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


int DestinationFileExists()
{
    byte error;

    error = CheckIfFileExists(localFileName);

    if(error == _NOFIL) {
        return 0;
    } else if(error != 0) {
        TerminateWithDosErrorCode("Error when searching the local file: ", regs.Bytes.A);
    }

    existingFileSize = *((long*)&Buffer[21]);
    return 1;
}


byte CheckIfFileExists(char* path)
{
    regs.Words.DE = (int)path;
    regs.Bytes.B = 0;
    regs.Words.IX = (int)Buffer;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
    return regs.Bytes.A;
}

void DownloadHttpContents()
{
    if(continueDownloading) {
        OpenLocalFile();
        PrepareLocalFileForAppend();
    } else {
        CreateLocalFile();
    }
    if(isChunkedTransfer) {
        DoChunkedDataTransfer();
    } else {
        DoDirectDatatransfer();
    }

    if(!localFileIsConsole) {
        printf("\r\n\r\nDownload complete. Generated file: %s", localFileName);
    }
    Terminate(NULL);
}

void DoDirectDatatransfer()
{
    if(zeroContentLengthAnnounced) {
        print("Content size: 0 bytes");
        return;
    }
	print(" ");
	if (contentLength)
	{
		blockSize = contentLength/25;
		currentBlock = 0;
		isFirstUpdate = true;
	}
    while(contentLength == 0 || receivedLength < contentLength) {
        EnsureThereIsTcpDataAvailable();
        receivedLength += remainingInputData;
		currentBlock += remainingInputData;
        UpdateReceivingMessage();
        WriteContentsToFile(inputDataPointer, remainingInputData);
        ResetTcpBuffer();
    }
}


void DoChunkedDataTransfer()
{
    int chunkSizeInBuffer;

    currentChunkSize = GetNextChunkSize();
	print(" ");
	if (contentLength)
	{
		blockSize = contentLength/25;
		currentBlock = 0;
		isFirstUpdate = true;
	}
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
        debug2("Chunk size in buffer: %i", chunkSizeInBuffer);
        receivedLength += chunkSizeInBuffer;
        UpdateReceivingMessage();
        WriteContentsToFile(inputDataPointer, chunkSizeInBuffer);
        inputDataPointer += chunkSizeInBuffer;
        currentChunkSize -= chunkSizeInBuffer;
        remainingInputData -= chunkSizeInBuffer;
    }
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

    debug2("Chunk size: %s", ltoa(value, Buffer));

    return value;
}


void OpenLocalFile()
{
    byte error;
    error = OpenFile(localFileName, &fileHandle);
    if(error != 0) {
        TerminateWithDosErrorCode("Error when opening local file: ", error);
    }
    CheckIfLocalFileIsConsole();
}


byte OpenFile(char* path, byte* fileHandle)
{
    regs.Bytes.A = 0;
    regs.Words.DE = (int)path;
    DosCall(_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == 0) {
        *fileHandle = regs.Bytes.B;
    }
    return regs.Bytes.A;
}


void CheckIfLocalFileIsConsole()
{
    regs.Bytes.A = 0;
    regs.Bytes.B = fileHandle;
    DosCall(_IOCTL, &regs, REGS_MAIN, REGS_MAIN);
    localFileIsConsole = ((regs.Bytes.E & 0x80) == 0x80);
}


void PrepareLocalFileForAppend()
{
    regs.Bytes.A = 2;
    regs.Bytes.B = fileHandle;
    regs.Words.HL = 0;
    regs.Words.DE = 0;
    DosCall(_SEEK, &regs, REGS_MAIN, REGS_NONE);
}


void CreateLocalFile()
{
    regs.Bytes.A = 0;
    regs.Bytes.B = 0;
    regs.Words.DE = (int)localFileName;
    DosCall(_CREATE, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when creating local file: ", regs.Bytes.A);
    }
    fileHandle = regs.Bytes.B;
    CheckIfLocalFileIsConsole();
}


void UpdateReceivingMessage()
{
	static int sti=0;
	unsigned char advance[4][3] = {"\r-","\r\\","\r|","\r/"};
	static unsigned char ui = 0;

    if(!localFileIsConsole) {
		if (contentLength)
		{			
			if (isFirstUpdate)
			{
				isFirstUpdate=false;
				print("\r[                         ]\r\x1c");
			}
			while (currentBlock>=blockSize)
			{
				currentBlock-=blockSize;
				print("=");
			}			
		}
		else
		{
			print(advance[ui%4]);
			++ui;
		}
    }
}


void WriteContentsToFile(byte* dataPointer, int size)
{
    regs.Bytes.B = fileHandle;
    regs.Words.DE = (int)dataPointer;
    regs.Words.HL = size;
    DosCall(_WRITE, &regs, REGS_MAIN, REGS_AF);
    if(regs.Bytes.A != 0) {
        TerminateWithDosErrorCode("Error when writing to local file: ", regs.Bytes.A);
    }
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


void ResolveServerName()
{
    print("Resolving server name...");
    regs.Words.HL = (int)domainName;
    debug2("Server name: %s\r\n", (byte*)regs.Words.HL);
    regs.Bytes.B = 0;
    UnapiCall(codeBlock, TCPIP_DNS_Q, &regs, REGS_MAIN, REGS_MAIN);
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
        UnapiCall(codeBlock, TCPIP_DNS_S, &regs, REGS_MAIN, REGS_MAIN);
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

	if (useHttps)
	{
		if (mustCheckCertificate)
			TcpConnectionParameters->flags = TcpConnectionParameters->flags | TCPFLAGS_VERIFY_CERTIFICATE ;
		if (mustCheckHostName)
			TcpConnectionParameters->hostName =  (int)domainName;
		else
			TcpConnectionParameters->hostName =  0;
	}
	else
	{
		TcpConnectionParameters->flags = 0 ;
		TcpConnectionParameters->hostName =  0;
	}

    print(" Ok\r\n");

    #ifdef DEBUG
    printf("--- Server IP: %i.%i.%i.%i\r\n", TcpConnectionParameters->remoteIP[0], TcpConnectionParameters->remoteIP[1], TcpConnectionParameters->remoteIP[2], TcpConnectionParameters->remoteIP[3]);
    #endif
}


void OpenTcpConnection()
{
    print("Connecting to server... ");

    regs.Words.HL = (int)TcpConnectionParameters;
    UnapiCall(codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == (byte)ERR_NO_FREE_CONN) {
        regs.Bytes.B = 0;
        UnapiCall(codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_NONE);
        regs.Words.HL = (int)TcpConnectionParameters;
        UnapiCall(codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    }

    if(regs.Bytes.A == (byte)ERR_NO_NETWORK) {
        Terminate(strNoNetwork);
    } else if(regs.Bytes.A != 0) {
        sprintf(Buffer, "Unexpected error when opening TCP connection (%i)", regs.Bytes.A);
		if (regs.Bytes.A == ERR_NO_CONN) //C should have the reason
		{
			if (regs.Bytes.C >= TCP_CONN_FAILURE_KNOWN_REASONS)
				printf("\r\n%s",strConnFailureReasons[TCP_CONN_FAILURE_KNOWN_REASONS]);
			else
				printf("\r\n%s",strConnFailureReasons[regs.Bytes.C]);
		}
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
        UnapiCall(codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    } while((regs.Bytes.A) == 0 && (regs.Bytes.B != 4));

    if(regs.Bytes.A != 0) {
        debug2("Error connecting: %i\r\n", regs.Bytes.A);
        Terminate("Could not establish a connection to the server");
		if (regs.Bytes.A == ERR_NO_CONN)
		{
			if (regs.Bytes.C >= TCP_CONN_FAILURE_KNOWN_REASONS)
				printf("\r\n%s",strConnFailureReasons[TCP_CONN_FAILURE_KNOWN_REASONS]);
			else
				printf("\r\n%s",strConnFailureReasons[regs.Bytes.C]);
		}
    }	

    print("OK\r\n\r\n");
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


void CloseTcpConnection()
{
    if(conn != 0) {
        regs.Bytes.B = conn;
        UnapiCall(codeBlock, TCPIP_TCP_CLOSE, &regs, REGS_MAIN, REGS_NONE);
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
            UnapiCall(codeBlock, TCPIP_TCP_SEND, &regs, REGS_MAIN, REGS_AF);
            if(regs.Bytes.A == ERR_BUFFER) {
                LetTcpipBreathe();
                regs.Bytes.A = ERR_BUFFER;
            }
        } while(regs.Bytes.A == ERR_BUFFER);
        debug2("SendTcpData: sent %i bytes\r\n", regs.Words.HL);
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


int ArgumentIs(char* argument, char* argumentStart)
{
    return (argument[0] == '/' && (strncmpi(argument+1, argumentStart, strlen(argumentStart)) == 0));
}


void TerminateWithCtrlCOrCtrlStop()
{
    Terminate("Operation cancelled");
}


void TerminateWithDosErrorCode(char* message, byte errorCode)
{
    char* pointer;

    strcpy(Buffer, message);
    pointer = Buffer + strlen(message);
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


void CloseLocalFile()
{
    if(!localFileIsConsole && fileHandle != 0) {
        CloseFile(fileHandle);
        fileHandle = 0;
    }
}


void CloseFile(byte fileHandle)
{
    regs.Bytes.B = fileHandle;
    DosCall(_CLOSE, &regs, REGS_MAIN, REGS_NONE);
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


void GetUnapiImplementationNameAndVersion()
{
    byte readChar;
    byte versionMain;
    byte versionSec;
    uint nameAddress;
    char* pointer = unapiImplementationName;

    UnapiCall(codeBlock, UNAPI_GET_INFO, &regs, REGS_NONE, REGS_MAIN);
    versionMain = regs.Bytes.B;
    versionSec = regs.Bytes.C;
    nameAddress = regs.UWords.HL;

    tcpIpSpecificationVersionMain = regs.Bytes.D;
    tcpIpSpecificationVersionSecondary = regs.Bytes.E;

    while(1) {
        readChar = UnapiRead(codeBlock, nameAddress);
        if(readChar == 0) {
            break;
        }
        *pointer++ = readChar;
        nameAddress++;
    }

    sprintf(pointer, " v%u.%u", versionMain, versionSec);
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


void ReadUrlFromConsole()
{
    byte* maxMessageLength = domainName-2;
    byte* messageLength = domainName-1;
    char* pointer;

    //Behavior of this method depends on whether
    //the input is being redirected from another application or not

    memset(domainName, 0, 256);
    regs.Bytes.A = 0;
    DosCall(_REDIR, &regs, REGS_AF, REGS_MAIN);
    if((regs.Bytes.B & 1) == 0) {
        debug("Input is NOT redirected");
        print("Type the URL and press ENTER (or simply hit ENTER to cancel): \r\n");
        regs.Words.DE = (int)maxMessageLength;
        *maxMessageLength = 255;
        DosCall(_BUFIN, &regs, REGS_MAIN, REGS_NONE);
        if(*messageLength == 0) {
            Terminate(NULL);
        }
        domainName[*messageLength] = 0;
        print("\r\n\r\n");
    } else {
        debug("Input is being redirected");
        pointer = domainName;
	regs.Bytes.B = 0;
	regs.Words.DE = (int)pointer;
	regs.Words.HL = 1;
	DosCall(_READ, &regs, REGS_MAIN, REGS_MAIN);
	if(regs.Words.HL == 0 || *pointer == 13 || *pointer == 0x1A) {
	    Terminate("No URL provided");
	}
	*pointer++;
        do {
            DosCall(_INNOE, &regs, REGS_NONE, REGS_AF);
            *pointer++ = regs.Bytes.A;
        } while(regs.Bytes.A != 13 && regs.Bytes.A != 0x1A);
        pointer[-1] = '\0';
    }
    debug2("URL: .%s.", buffers->Message);
}
