/* ObsoFTP - FTP server for the TCP/IP UNAPI 1.0
   By Konamiman, 4/2011

   Compilation command line:
   
   sdcc --code-loc 0x170 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.lib ftpserv.c
   hex2bin -e com ftpserv.ihx
   
   ASM.LIB, MSXCHAR.LIB and crt0msx_msxdos_advanced.rel
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
#include "asm.h"

typedef unsigned char bool;
#define false (0)
#define true (!false)
#define null ((void*)0)

typedef unsigned long ulong;

#define FTP_CONTROL_PORT 21
#define FTP_DATA_PORT 20

#define MAX_FTP_COMMAND_LENGTH 4
#define MAX_FTP_COMMAND_LINE_LENGTH 128
#define MAX_RESPONSE_LENGTH 128
#define MAX_MSXDOS_PATH_LENGTH 64

#define DATA_BUFFER_SIZE 1024
#define COMMAND_RECEIVE_BUFFER_SIZE 256

#define CLIENT_INACTIVITY_TIMEOUT (5 * 60 * 60)
#define DATA_TRANSFER_TIMEOUT (15 * 60)
#define CONN_SETUP_TIMEOUT (5 * 60)

#define TCPOUT_STEP_SIZE 256

#define PASSIVE_PORT_BASE 1024


  /* Structs and enums */

#define _TERM0 0x00
#define _CONIN 0x01
#define _INNOE 0x08
#define _BUFIN 0x0A
#define _CONST 0x0B
#define _LOGIN 0x18
#define _ALLOC 0x1B
#define _GDATE 0x2A
#define _GTIME 0x2C
#define _FFIRST 0x40
#define _FNEXT 0x41
#define _FNEW 0x42
#define _OPEN 0x43
#define _CREATE 0x44
#define _CLOSE 0x45
#define _SEEK 0x4A
#define _READ 0x48
#define _WRITE 0x49
#define _IOCTL 0x4B
#define _DELETE 0x4D
#define _RENAME 0x4E
#define _MOVE 0x4F
#define _ATTR 0x50
#define _HATTR 0x55
#define _HFTIME 0x56
#define _GETCD 0x59
#define _PARSE 0x5B
#define _TERM 0x62
#define _DEFAB 0x63
#define _DEFER 0x64
#define _EXPLAIN 0x66
#define _RAMD 0x68
#define _GENV 0x6B
#define _DOSVER 0x6F
#define _REDIR 0x70

#define _CTRLC 0x9E
#define _STOP  0x9F

#define _NCOMP 0xFF
#define _WRERR 0xFE
#define _DISK  0xFD
#define _NRDY  0xFC
#define _VERFY 0xFB
#define _DATA  0xFA
#define	_RNF   0xF9
#define	_WPROT 0xF8
#define _UFORM 0xF7
#define _NDOS  0xF6
#define _WDISK 0xF5
#define _WFILE 0xF4
#define _SEEKE 0xF3
#define _IFAT  0xF2
#define _INTER 0xDF
#define _NORAM 0xDE
#define _IDRV  0xDB
#define _IFNM  0xDA
#define _IPATH 0xD9
#define _PLONG 0xD8
#define _NOFIL 0xD7
#define _NODIR 0xD6
#define _DRFUL 0xD5
#define _DKFUL 0xD4
#define _DUPF  0xD3
#define _DIRE  0xD2
#define _FILRO 0xD1
#define _DIRNE 0xD0
#define _IATTR 0xCF
#define _DOT   0xCE
#define _SYSX  0xCD
#define _DIRX  0xCC
#define _FILEX 0xCB
#define _FOPEN 0xCA
#define _FILE  0xC8
#define _EOF   0xC7
#define _ACCV  0xC6
#define _NHAND 0xC4
#define _IHAND 0xC3
#define _NOPEN 0xC2
#define _HDEAD 0xBA

#define ERAFNK 0x00CC
#define DSPFNK 0x00CF
//0=display function keys, other=hide
#define CNSDFG 0xF3DE
//Function key contents (10 x 16 bytes)
#define FNKSTR 0xF87F

#define ATTR_DIRECTORY 0x10
#define ATTR_DO_NOT_OVERWRITE 0x80

#define SYSTIMER ((uint*)0xFC9E)

enum TcpipUnapiFunctions {
    UNAPI_GET_INFO = 0,
    TCPIP_GET_CAPAB = 1,
    TCPIP_GET_IPINFO = 2,
    TCPIP_NET_STATE = 3,
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

enum ListCommandType {
	CMD_LIST,
	CMD_NLST,
	CMD_STAT,
	CMD_MLSD
};

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
    byte remoteIP[4];
    uint remotePort;
    uint localPort;
    int userTimeout;
    byte flags;
} t_TcpConnectionParameters;

enum ConnectionStates {
    CONN_CLOSED = 0,
    CONN_IDLE = 1,
    CONN_RNFR_RECEIVED = 2,
    CONN_SENDING_FILE = 3,
    CONN_RECEIVING_FILE = 4
};

typedef struct {
    byte connectionState;
    byte clientDataConnIP[4];
    uint clientDataConnPort;
    int timeoutCounter;
    byte fileHandle;
    bool passiveMode;
	int passiveModePort;
	byte controlConnTcpHandle;
	byte dataConnTcpHandle;
	char* rnfrSource;
	long sentBytes;
	long receivedBytes;
	int sentFiles;
	int receivedFiles;
	long currentFileBytes;
	long restartPosition;
} t_ClientConnection;


   /* Global variables, GUIDs and strings */

Z80_registers regs;
unapi_code_block codeBlock;
bool readOnlyServer = false;
byte* malloc_ptr;
byte* dataBuffer;
byte* controlDataReceiveBuffer;
uint lastSysTimer;
bool debugMode = false;
char* receivedCommand;
char* receivedCommandParameter;
char* basePhysicalDirectory;
char* currentPhysicalDirectory;
char* commandArgumentPhysicalPath;
char* printableBaseDirectory;
char* controlDataReceiveBufferPointer;
char* commandReceiveBufferPointer;
int controlDataReceiveRemaining;
t_FileInfoBlock tempFIB;
t_ClientConnection clientConnection;
byte oldInsertDiskPromptHook;
int remainingInputData;
char* welcomeMessage;
bool baseDirectoryIsDriveRoot;
uint lastUsedPassivePort = PASSIVE_PORT_BASE;
byte serverIP[4];
bool insertDiskPromptHookPatched;
byte functionKeyDisplayOriginal;
bool functionKeysPatched = false;
char functionKeysOriginalContent[80];
byte* functionKeysDisplaySwitch;
char* functionKeysContents;

const char* strTitle=
    "ObsoFTP - FTP server for the TCP/IP UNAPI 1.0\r\n"
    "By Konamiman, 4/2011\r\n"
    "\r\n";
    
const char* strUsage=
	"Usage: obsoftp <base path> [mode={rw|ro}] [debug={on|off}]\r\n"
    "\r\n"
    "<base path>: path that the client will see as the root directory.\r\n"
    "\r\n"
    "\"mode=rw\" starts the server in read and write mode (default).\r\n"
    "\"mode=ro\" starts the server in read only mode.\r\n"
	"\r\n"
	"\"debug=on\" displays all the commands sent and received.";
    
const char* strCRLF = "\r\n";
const char* strInvParam = "Invalid parameter";
const char* strNoNetwork = "No network connection available";
const char* strOkCurrentDirIsRoot = "250 OK. Current directory is /\r\n";
const char* strCantgetSizeOfDirectory = "550 Can't get the size of a directory\r\n";
const char* strFileNotFound = "550 File not found\r\n";
const char* strDataConnLost = "426 Data connection lost\r\n";
const char* strTransferCompleted = "226 Transfer completed, closing data connection\r\n";

char* monthNames[] = {"Jan", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

  /* Code defines */

#define TerminateWithInvalidParameters() Terminate(strInvParam)
#define PrintNewLine() print(strCRLF)
#define LetTcpipBreathe() UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE)
#define ToLowerCase(ch) {ch |= 32;}
//#define ToUpperCase(ch) {ch &= ~32;}
#define StringIs(a, b) (strcmpi(a,b)==0)
#define Clear(mem, size) memset(mem,0,size)
#define CommandIs(s) StringIs(receivedCommand, s)


  /* Function prototypes */

void ProcessParameters(char** argv, int argc);
void DoServerMainLoop();
void InitializeServer();
byte OpenTcpConnection(int localPort, bool active, byte* remoteIP);
void print(char* s);
void CheckDosVersion();
void Terminate(const char* errorMessage);
void DisableAutoAbort();
void RestoreDefaultAbortRoutine();
void TerminateWithCtrlCOrCtrlStop();
void TerminateIfEscIsPressed();
int EscIsPressed();
void InitializeTcpipUnapi();
void AbortAllTransientTcpConnections();
void minit();
void* malloc(unsigned int size);
void mfree(void* address);
void* critical_malloc(unsigned int size);
int strcmpi(const char *a1, const char *a2);
int strncmpi(const char *a1, const char *a2, unsigned size);
bool StringStartsWith(const char* stringToCheck, const char* startingToken);
char* ExplainDosErrorCode(byte code, char* destination);
byte CheckDirectory(char* path);
bool IsEstablishedConnection(byte tcpConnNumber);
void GetClientConnectionIpAndPort();
void CloseClientConnection(char* reason);
bool ReceiveCommand();
void ProcessCommand();
void ProcessQuitCommand();
void CalculateUploadedAndDownloadedString(char* destination, char* code);
void ProcessTypeCommand();
void ProcessModeCommand();
void ProcessStruCommand();
void ProcessCwdCommand();
void ProcessMkdCommand();
void ProcessDeleOrRmdCommand(bool isRmd);
void ProcessRnfrCommand();
void ProcessRntoCommand();
void EndRenameSequence();
void BuildCommandArgumentPrintablePath(char* destinationPrintablePath);
void BuildCommandArgumentPhysicalPath();
void ProcessCdupCommand();
void ProcessPasvCommand();
void ProcessPortCommand();
void LongToAsciiJustified(unsigned long value, char* destination, byte maxLength);
void ProcessMlstCommand();
void ProcessListCommand(byte listCommandType);
bool ArgumentContainsWildcards();
void ProcessStatCommand();
void PorcessSizeCommand();
void ProcessMdtmCommand();
void GenerateDateString(char* destination);
void AppendToString(char* baseString, char* stringToAppend);
void AppendCharToString(char* baseString, char charToAppend);
void ProcessRestCommand();
bool SetFileHandlePointerForRest(byte fileHandle);
void ProcessRetrCommand();
void ProcessStorOrAppeCommand(bool append);
void ProcessAborCommand();
bool ContinueSendingFile();
bool ContinueReceivingFile();
void EndFileTransfer();
void SendStringToControlConnection2(char* string, char* parameter);
void SendStringToControlConnection(char* string);
void PatchInsertDiskPromptHook();
void RestoreInsertDiskPromptHook();
void BuildWelcomeMessage();
bool ReadTcpControlData();
bool SendTcpData(byte connHandle, byte* data, int dataSize);
bool StringEndsWith(char* string, char* substring);
void RemoveLastSlash(char* string);
void GetUnapiImplementationName(char* destination);
void ToUpperCase(char* string);
void AdaptSlashes(char* string);
bool IsReadOnlyServer();
void SendDosErrorMessage(char* prefix, byte errorCode);
bool OpenDataConnection();
bool WaitUntilDataConnectionIsOpen(byte tcpConn);
void CloseDataConnection();
void CloseFile(byte fileHandle);
void DisplayFunctionKeys();
void HideFunctionKeys();
void BackupAndInitializeFunctionKeysState();
void SetFunctionKeyContents(int keyIndex, char* contents);
void RestoreFunctionKeysState();


  /* Main */

int main(char** argv, int argc)
{
    *((byte*)codeBlock) = 0;
	Clear(&clientConnection, sizeof(t_ClientConnection));
    minit();
    CheckDosVersion();
    print(strTitle);
    ProcessParameters(argv, argc);
    InitializeServer();
    DoServerMainLoop();
    
    //Never reached but needed to compile
    return 0;
}


  /* Functions */

void ProcessParameters(char** argv, int argc)
{
    int i;
    char* arg;

    if(argc == 0) {
        print(strUsage);
        Terminate(null); //DosCall(_TERM0, &regs, REGS_NONE, REGS_NONE);
    }

    if(argc > 3) {
        TerminateWithInvalidParameters();
    }

	basePhysicalDirectory = critical_malloc(MAX_MSXDOS_PATH_LENGTH + 5);	//+5 for "X:\" and ending "\"+0
    strcpy(basePhysicalDirectory, argv[0]);

	for(i = 1; i < argc; i++) {
		arg = argv[i];
        if(StringStartsWith(arg, "mode=")) {
			if(StringIs(arg+5, "ro")) {
				readOnlyServer = true;
			} else if(!StringIs(arg+5, "rw")) {
				TerminateWithInvalidParameters();
			}
		} else if(StringStartsWith(arg, "debug=")) {
			if(StringIs(arg+6, "on")) {
				debugMode = true;
			} else if(!StringIs(arg+6, "off")) {
				TerminateWithInvalidParameters();
			}
		} else {
			TerminateWithInvalidParameters();
	    }
	}
}


void DoServerMainLoop()
{
    bool timerInterruptHappened = false;
	bool dataTransferOk = false;
	bool dataTransferInProgress = false;

    lastSysTimer = *SYSTIMER;
    while(true) {
        TerminateIfEscIsPressed();
        DosCall(_CONST, &regs, REGS_NONE, REGS_NONE);	//force checking CTRL-C and CTRL-STOP
        
        if(*SYSTIMER != lastSysTimer) {
            lastSysTimer = *SYSTIMER;
            timerInterruptHappened = true;
        }

		if(clientConnection.connectionState == CONN_CLOSED) {
			if(clientConnection.controlConnTcpHandle == 0) {
				clientConnection.controlConnTcpHandle = OpenTcpConnection(FTP_CONTROL_PORT, false, null);
			} else {
				if(IsEstablishedConnection(clientConnection.controlConnTcpHandle)) {
					clientConnection.connectionState = CONN_IDLE;
					clientConnection.timeoutCounter = 0;
					GetClientConnectionIpAndPort();
					printf("Received connection from %i.%i.%i.%i, port %i\r\n", 
						clientConnection.clientDataConnIP[0], clientConnection.clientDataConnIP[1], clientConnection.clientDataConnIP[2], clientConnection.clientDataConnIP[3],
						clientConnection.clientDataConnPort);
					SendStringToControlConnection(welcomeMessage);

					SetFunctionKeyContents(4, "Client IP:");
					sprintf(dataBuffer, "%i.%i.%i.%i\r\n", 
						clientConnection.clientDataConnIP[0], clientConnection.clientDataConnIP[1], clientConnection.clientDataConnIP[2], clientConnection.clientDataConnIP[3]);
					SetFunctionKeyContents(5, dataBuffer);
				}
			}
		} else if(!IsEstablishedConnection(clientConnection.controlConnTcpHandle)) {
			CloseClientConnection("connection lost");
		}
        
		if(clientConnection.connectionState != CONN_CLOSED) {
			if(ReceiveCommand()) {
				ProcessCommand();
				clientConnection.timeoutCounter = 0;
			} else if(timerInterruptHappened) {
				clientConnection.timeoutCounter++;
				if(clientConnection.timeoutCounter > CLIENT_INACTIVITY_TIMEOUT) {
					CloseClientConnection("client inactivity");
				}
			}
		}

		if(clientConnection.connectionState == CONN_SENDING_FILE) {
			dataTransferInProgress = true;
			dataTransferOk = ContinueSendingFile();
		} else if(clientConnection.connectionState == CONN_RECEIVING_FILE) {
			dataTransferInProgress = true;
			dataTransferOk = ContinueReceivingFile();
		}

		if(dataTransferInProgress) {
			if(dataTransferOk) {
				clientConnection.timeoutCounter = 0;
			} else if(timerInterruptHappened) {
				clientConnection.timeoutCounter++;
				if(clientConnection.timeoutCounter > DATA_TRANSFER_TIMEOUT) {
					CloseClientConnection("client inactivity");
				}
			}
			dataTransferInProgress = false;
		}
        
        timerInterruptHappened = false;
    }
}


#define UPPER_RAM ((byte*)0xC000)
void InitializeServer()
{
	byte error;
	byte* pointer;

    InitializeTcpipUnapi();
    DisableAutoAbort();
	PatchInsertDiskPromptHook();
	
    dataBuffer = UPPER_RAM;
	error = CheckDirectory(basePhysicalDirectory);
    if(error != 0) {
        sprintf(dataBuffer, "Error when checking the base directory: %s", ExplainDosErrorCode(error, dataBuffer + 64));
        Terminate(dataBuffer);
    }
	baseDirectoryIsDriveRoot = (strlen(basePhysicalDirectory) == 3 && StringEndsWith(basePhysicalDirectory, ":\\"));

	welcomeMessage = critical_malloc(1024);
	BuildWelcomeMessage();

	controlDataReceiveBuffer = critical_malloc(COMMAND_RECEIVE_BUFFER_SIZE);
	controlDataReceiveBufferPointer = controlDataReceiveBuffer;
	controlDataReceiveRemaining = 0;

	receivedCommand = critical_malloc(MAX_FTP_COMMAND_LINE_LENGTH + 3);	//+3 for CRLF+0
	commandReceiveBufferPointer = receivedCommand;

	printableBaseDirectory = critical_malloc(MAX_MSXDOS_PATH_LENGTH + 2);	//+2 for "/" and ending 0
	printableBaseDirectory[0] = '/';
	printableBaseDirectory[1] = '\0';
	commandArgumentPhysicalPath = critical_malloc(MAX_MSXDOS_PATH_LENGTH + 2);
	currentPhysicalDirectory = critical_malloc(MAX_MSXDOS_PATH_LENGTH + 2);
	strcpy(currentPhysicalDirectory, basePhysicalDirectory);

	Clear(&clientConnection, sizeof(t_ClientConnection));

	regs.Bytes.B = 1;
	UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
	serverIP[0] = regs.Bytes.L;
	serverIP[1] = regs.Bytes.H;
	serverIP[2] = regs.Bytes.E;
	serverIP[3] = regs.Bytes.D;

	functionKeysDisplaySwitch = (byte*)CNSDFG;
	functionKeysContents = (char*)(byte*)FNKSTR;
	BackupAndInitializeFunctionKeysState();
	SetFunctionKeyContents(1, "Server IP:");
	sprintf(dataBuffer, "%i.%i.%i.%i\r\n", serverIP[0], serverIP[1], serverIP[2], serverIP[3]);
	SetFunctionKeyContents(2, dataBuffer);

    printf("--- Server started in read%s mode\r\n", readOnlyServer ? "-only" : " and write");
	printf("--- Base directory is: %s\r\n", basePhysicalDirectory);
	if(debugMode) {
		print("--- Debug mode is ON\r\n");
	}
    printf("--- Server address: %i.%i.%i.%i\r\n", serverIP[0], serverIP[1], serverIP[2], serverIP[3]);
    print ("--- Press ESC, CTRL-C or CTRL-STOP to terminate.\r\n\r\n");
}


byte OpenTcpConnection(int port, bool active, byte* remoteIP)
{
    t_TcpConnectionParameters* connParams;

	connParams = critical_malloc(sizeof(t_TcpConnectionParameters));
    Clear(connParams, sizeof(t_TcpConnectionParameters));
    connParams->flags = active ? 0 : 1;
	if(active) {
		connParams->remotePort = port;
		connParams->localPort = 0xFFFF;
	} else {
		connParams->localPort = port;
	}
	if(remoteIP != null) {
		memcpy(&(connParams->remoteIP), remoteIP, 4);
	}

    regs.Words.HL = (int)connParams;
    UnapiCall(&codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        sprintf(dataBuffer, "Unexpected error when opening TCP connection: %i", regs.Bytes.A);
        Terminate(dataBuffer);
    }

    mfree(connParams);
	return regs.Bytes.B;
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


void CheckDosVersion()
{
    DosCall(_DOSVER, &regs, REGS_NONE, REGS_MAIN);
    if(regs.Bytes.B < 2) {
        Terminate("This program is for MSX-DOS 2 only.");
    }
}


void Terminate(const char* errorMessage)
{
    if(errorMessage != NULL) {
        printf("\r\x1BK*** %s\r\n", errorMessage);
    }

    RestoreDefaultAbortRoutine();
	RestoreInsertDiskPromptHook();
	RestoreFunctionKeysState();
    
    if(*((byte*)codeBlock) != 0) {
		if(clientConnection.controlConnTcpHandle != 0) {
			SendStringToControlConnection("421 The FTP service is being shut down\r\n");
		}
        AbortAllTransientTcpConnections();
    }
    
    regs.Bytes.B = (errorMessage == NULL ? 0 : 1);
    DosCall(_TERM, &regs, REGS_MAIN, REGS_NONE);
	DosCall(_TERM0, &regs, REGS_NONE, REGS_NONE);
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

Also, it causes all disk errors to be automatically aborted.
*/
void DisableAutoAbort() __naked
{
    __asm
    
    push    ix
	ld  de,#DSKERR_CODE
	ld  c,#_DEFER
	call    #5
    ld  de,#ABORT_CODE
    ld  c,#_DEFAB
    call    #5
    pop ix
    ret

DSKERR_CODE:
	ld	a,#1
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
    DosCall(_DEFER, &regs, REGS_MAIN, REGS_NONE);
    regs.Words.DE = 0;
    DosCall(_DEFAB, &regs, REGS_MAIN, REGS_NONE);
}


void TerminateWithCtrlCOrCtrlStop()
{
    Terminate("CTRL-C or CTRL-STOP pressed, server stopped");
}


void TerminateIfEscIsPressed()
{
    if(EscIsPressed()) {
        Terminate("ESC pressed, server stopped");
    }
}


int EscIsPressed()
{
    return (*((byte*)0xFBEC) & 4) == 0;
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
    if((regs.Bytes.L & (1 << 5)) == 0) {
        Terminate("This TCP/IP implementation does not support opening\r\n"
                  "    passive TCP connections with unespecified remote socket");
    }

    AbortAllTransientTcpConnections();
    
    regs.Bytes.B = 2;
    UnapiCall(&codeBlock, TCPIP_GET_CAPAB, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.D < 2) {
        Terminate("No free TCP connections available (two connections are needed)");
    }
}


void AbortAllTransientTcpConnections()
{
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_NONE);
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


void* malloc(unsigned int size) __naked
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


void* critical_malloc(unsigned int size)
{
    void* pointer = malloc(size);
    if(pointer == null) {
        Terminate("Out of memory, server stopped");
    }
    return pointer;
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


bool StringStartsWith(const char* stringToCheck, const char* startingToken)
{
    int len;
    len = strlen(startingToken);
    return strncmpi(stringToCheck, startingToken, len) == 0;
}


char* ExplainDosErrorCode(byte code, char* destination)
{
    regs.Bytes.B = code;
    regs.Words.DE = (int)destination;
    DosCall(_EXPLAIN, &regs, REGS_MAIN, REGS_NONE);
    return destination;
}


byte CheckDirectory(char* path)
{
	bool isRoot = false;
	if(strlen(path) == 3 && StringEndsWith(path, ":\\")) {
		isRoot = true;
	} else {
		RemoveLastSlash(path);
	}

    regs.Words.DE = (int)path;
    regs.Bytes.B = ATTR_DIRECTORY;
    regs.Words.IX =(int)&tempFIB;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
	if(regs.Bytes.A == _NOFIL && isRoot) {
		return 0;
	} else if(regs.Bytes.A != 0) {
        return regs.Bytes.A;
    } else if(!isRoot && ((tempFIB.attributes & ATTR_DIRECTORY) == 0)) {
        return _NODIR;       
    } else {
		return 0;
	}
}


bool IsEstablishedConnection(byte tcpConnNumber)
{
    regs.Bytes.B = tcpConnNumber;
    regs.Words.HL = 0;
    UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    return (regs.Bytes.A == 0 && regs.Bytes.B == 4);
}


void GetClientConnectionIpAndPort()
{
	byte* buffer = critical_malloc(8);

    regs.Bytes.B = clientConnection.controlConnTcpHandle;
    regs.Words.HL = (int)buffer;
    UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    memcpy(&(clientConnection.clientDataConnIP), buffer, 4);
	clientConnection.clientDataConnPort = (uint)*((uint*)(buffer + 2));
    mfree(buffer);
}


void CloseClientConnection(char* reason)
{
	printf("Closing client connection: %s\r\n", reason);
	regs.Bytes.B = 0;	//this closes the data connection too, if it is open
    UnapiCall(&codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_MAIN);
	if(clientConnection.rnfrSource != null) {
		mfree(clientConnection.rnfrSource);
	}
	Clear(&clientConnection, sizeof(t_ClientConnection));
	controlDataReceiveRemaining = 0;
	commandReceiveBufferPointer = receivedCommand;

	printableBaseDirectory[0] = '/';
	printableBaseDirectory[1] = '\0';
	strcpy(currentPhysicalDirectory, basePhysicalDirectory);

	SetFunctionKeyContents(4, "");
	SetFunctionKeyContents(5, "");
}


bool ReceiveCommand()
{
	char lastChar;
	char* temp;
	char* commandTerminationPointer;

	while(true) {
		if(controlDataReceiveRemaining == 0 && !ReadTcpControlData()) {
			return false;
		}
		lastChar = *controlDataReceiveBufferPointer++;
		controlDataReceiveRemaining--;
		if((byte)lastChar >= 0xF0) {
			continue;	//get rid of Telnet control characters
		}
		*commandReceiveBufferPointer++  = lastChar;
		if(lastChar == 10) {
			commandReceiveBufferPointer[-2] = '\0';
			if(debugMode) {
				printf("<-- %s\r\n", receivedCommand);
			}

			temp = receivedCommand;
			while(*temp != ' ' && *temp != '\0') {
				temp++;
			}
			commandTerminationPointer = temp;
			while(*temp == ' ') {
				temp++;
			}

			if(*temp == '\0') {
				*commandTerminationPointer = '\0';
				receivedCommandParameter = temp;
			} else {
				*commandTerminationPointer = '\0';
				while(*temp == ' ') {
					temp++;
				}
				receivedCommandParameter = temp;

				while(*temp != ' ' && *temp != '\0') {
					temp++;
				}
				*temp = '\0';
			}

			commandReceiveBufferPointer = receivedCommand;
			ToUpperCase(receivedCommand);
			return true;
		}
	}
}


void ProcessCommand()
{
	//printf("*** cmd: '%s', par: '%s'\r\n", receivedCommand, receivedCommandParameter);

	if(clientConnection.fileHandle != 0 &&
		!(CommandIs("ABOR") || CommandIs("QUIT") || CommandIs("STAT"))) {
			SendStringToControlConnection("503 File transfer in progress. Only ABOR, STAT and QUIT commands allowed now.\r\n");
			return;
	}

	if(clientConnection.connectionState == CONN_RNFR_RECEIVED) {
		if(CommandIs("RNTO")) {
			ProcessRntoCommand();
		} else {
			SendStringToControlConnection2("503 Bad sequence of commands\r\n", receivedCommand);
			clientConnection.connectionState = CONN_IDLE;
		}
		EndRenameSequence();
		return;
	}

	if(CommandIs("NOOP")) {
		SendStringToControlConnection("200 NOOP command OK\r\n");
	} else if(CommandIs("USER")) {
		SendStringToControlConnection("331 Any password will work\r\n");
	} else if(CommandIs("PASS")) {
		SendStringToControlConnection("230 You are logged in\r\n");
	} else if(CommandIs("PWD") || CommandIs("XPWD")) {
		SendStringToControlConnection2("257 \"%s\" is your current location\r\n", printableBaseDirectory);
	} else if(CommandIs("QUIT")) {
		ProcessQuitCommand();
	} else if(CommandIs("TYPE")) {
		ProcessTypeCommand();
	} else if(CommandIs("MODE")) {
		ProcessModeCommand();
	} else if(CommandIs("STRU")) {
		ProcessStruCommand();
	} else if(CommandIs("CWD") || CommandIs("XCWD")) {
		if(StringIs(receivedCommandParameter, "..")) {
			ProcessCdupCommand();
		} else {
			ProcessCwdCommand();
		}
	} else if(CommandIs("CDUP") || CommandIs("XCUP")) {
		ProcessCdupCommand();
	} else if(CommandIs("MKD") || CommandIs("XMKD")) {
		ProcessMkdCommand();
	} else if(CommandIs("RMD") || CommandIs("XRMD")) {
		ProcessDeleOrRmdCommand(true);
	} else if(CommandIs("DELE")) {
		ProcessDeleOrRmdCommand(false);
	} else if(CommandIs("RNFR")) {
		ProcessRnfrCommand();
	} else if(CommandIs("PASV")) {
		ProcessPasvCommand();
	} else if(CommandIs("PORT")) {
		ProcessPortCommand();
	} else if(CommandIs("LIST")) {
		ProcessListCommand(CMD_LIST);
	} else if(CommandIs("NLST")) {
		ProcessListCommand(CMD_NLST);
	} else if(CommandIs("MLSD")) {
		ProcessListCommand(CMD_MLSD);
	} else if(CommandIs("MLST")) {
		ProcessMlstCommand();
	} else if(CommandIs("SIZE")) {
		PorcessSizeCommand();
	} else if(CommandIs("MDTM")) {
		ProcessMdtmCommand();
	} else if(CommandIs("FEAT")) {
		SendStringToControlConnection(
			"211-Extensions supported:\r\n"
			" SIZE\r\n"
			" MDTM\r\n"
			" MLST type*;size*;modify*;\r\n"
			" MLSD\r\n"
			" REST STREAM\r\n"
			"211 End.\r\n");
	} else if(CommandIs("SYST")) {
		SendStringToControlConnection("215 UNIX Type: L8\r\n");	//It seems that some clients go crazy if they do not receive this
	} else if(CommandIs("STAT")) {
		ProcessStatCommand();
	} else if(CommandIs("REST")) {
		ProcessRestCommand();
	} else if(CommandIs("RETR")) {
		ProcessRetrCommand();
	} else if(CommandIs("STOR")) {
		ProcessStorOrAppeCommand(false);
	} else if(CommandIs("APPE")) {
		ProcessStorOrAppeCommand(true);
	} else if(CommandIs("ABOR")) {
		ProcessAborCommand();
	} else {
		SendStringToControlConnection("500 Unknown or unimplemented command\r\n");
	}
}


void ProcessQuitCommand()
{
	CalculateUploadedAndDownloadedString(dataBuffer + 256, "221");

	sprintf(dataBuffer, 
		"221-Goodbye.\r\n"
		"%s"
		"221 I hope to see you again!\r\n",
		dataBuffer + 256);

	SendStringToControlConnection(dataBuffer);
	CloseClientConnection("QUIT command received");
}


void CalculateUploadedAndDownloadedString(char* destination, char* code)
{
	char receivedBytes[11];
	char sentBytes[11];
	char* receivedPointer;
	char* sentPointer;
	long receivedKBytes = clientConnection.receivedBytes / 1024;
	long sentKBytes = clientConnection.sentBytes / 1024;

	LongToAsciiJustified(receivedKBytes, receivedBytes, 10);
	receivedPointer = receivedBytes;
	while(*receivedPointer == ' ') {
		receivedPointer++;
	}

	LongToAsciiJustified(sentKBytes, sentBytes, 10);
	sentPointer = sentBytes;
	while(*sentPointer == ' ') {
		sentPointer++;
	}

	sprintf(destination, 
		"%s-You have uploaded %s KBytes in %i files.\r\n"
		"%s-You have downloaded %s KBytes in %i files.\r\n",
		code, receivedPointer, clientConnection.receivedFiles,
		code, sentPointer, clientConnection.sentFiles);
}


void ProcessTypeCommand()
{
	ToUpperCase(receivedCommandParameter);
	if(StringIs(receivedCommandParameter, "A") || StringIs(receivedCommandParameter, "I")) {
		SendStringToControlConnection2("200 Type set to '%s'\r\n", receivedCommandParameter);
	} else {
		SendStringToControlConnection("504 Only types 'A' and 'I' are allowed\r\n");
	}
}


void ProcessModeCommand()
{
	ToUpperCase(receivedCommandParameter);
	if(StringIs(receivedCommandParameter, "S")) {
		SendStringToControlConnection("200 Mode set to 'S'\r\n");
	} else {
		SendStringToControlConnection("504 Only mode 'S' is allowed\r\n");
	}
}


void ProcessStruCommand()
{
	ToUpperCase(receivedCommandParameter);
	if(StringIs(receivedCommandParameter, "F")) {
		SendStringToControlConnection("200 File structure set to 'F'\r\n");
	} else {
		SendStringToControlConnection("504 Only file structure 'F' is allowed\r\n");
	}
}


void ProcessCwdCommand()
{
	bool isAbsolutePath = (receivedCommandParameter[0] == '/');
	bool currentDirIsRoot = StringIs(printableBaseDirectory, "/");
	byte error;

	BuildCommandArgumentPhysicalPath();

	//printf("*** attempting to change to: %s\r\n", commandArgumentPhysicalPath); 

	if((error = CheckDirectory(commandArgumentPhysicalPath)) == 0) {
		strcpy(currentPhysicalDirectory, commandArgumentPhysicalPath);
		BuildCommandArgumentPrintablePath(printableBaseDirectory);
		SendStringToControlConnection2("250 OK. Current directory is %s\r\n", printableBaseDirectory);
	} else {
		sprintf(dataBuffer, "550 Can't change to directory %s: %s\r\n", receivedCommandParameter, ExplainDosErrorCode(error, dataBuffer + 128));
		SendStringToControlConnection(dataBuffer);
	}
}


void ProcessMkdCommand()
{
	byte error;

	if(IsReadOnlyServer()) {
		return;
	}

	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
	regs.Bytes.B = ATTR_DIRECTORY | ATTR_DO_NOT_OVERWRITE;
	regs.Bytes.A = 0;
	DosCall(_CREATE, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) == 0) {
		BuildCommandArgumentPrintablePath(dataBuffer + 128);
		SendStringToControlConnection2("257 \"%s\" created\r\n", dataBuffer + 128);
	} else {
		sprintf(dataBuffer, "550 Can't create directory %s: %s\r\n", receivedCommandParameter, ExplainDosErrorCode(error, dataBuffer + 128));
		SendStringToControlConnection(dataBuffer);
	}
}


void ProcessDeleOrRmdCommand(bool isRmd)
{
	byte error;

	if(IsReadOnlyServer()) {
		return;
	}

	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
	regs.Bytes.B = isRmd ? ATTR_DIRECTORY : 0;
	regs.Words.IX = (int)&tempFIB;
	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
	if((error = regs.Bytes.A) == 0) {
		if(isRmd && ((tempFIB.attributes & ATTR_DIRECTORY) == 0)) {
			error = _NODIR;
		} else if(!isRmd && ((tempFIB.attributes & ATTR_DIRECTORY) != 0)) {
			error = _NOFIL;
		} else {
			regs.Words.DE = (int)commandArgumentPhysicalPath;
			DosCall(_DELETE, &regs, REGS_MAIN, REGS_AF);
			error = regs.Bytes.A;
		}
	}

	if(error == 0) {
		SendStringToControlConnection2("250 %s deleted successfully\r\n", isRmd ? "Directory" : "File");
	} else {
		sprintf(dataBuffer, "550 Can't delete %s: %s\r\n", isRmd ? "directory" : "file", ExplainDosErrorCode(error, dataBuffer + 128));
		SendStringToControlConnection(dataBuffer);
	}
}


void ProcessRnfrCommand()
{
	byte error;

	if(IsReadOnlyServer()) {
		return;
	}

	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
	regs.Bytes.B = ATTR_DIRECTORY;
	regs.Words.IX = (int)&tempFIB;
	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
	if((error = regs.Bytes.A) == 0) {
		clientConnection.rnfrSource = malloc(MAX_MSXDOS_PATH_LENGTH + 5);
		if(clientConnection.rnfrSource == null) {
			SendStringToControlConnection("451 Server error: Out of memory\r\n");
			return;
		}
		strcpy(clientConnection.rnfrSource, commandArgumentPhysicalPath);
		SendStringToControlConnection("350 File exists, ready for destination name\r\n");
		clientConnection.connectionState = CONN_RNFR_RECEIVED;
	} else {
		SendStringToControlConnection2("550 Can't rename file: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
	}
}


void ProcessRntoCommand()
{
	byte error;
	char* pointerToLastItem;

	BuildCommandArgumentPhysicalPath();

	pointerToLastItem = commandArgumentPhysicalPath + strlen(commandArgumentPhysicalPath);
	while(*pointerToLastItem != '\\') {
		pointerToLastItem--;
	}
	pointerToLastItem++;

	regs.Words.DE = (int)clientConnection.rnfrSource;
	regs.Words.HL = (int)pointerToLastItem;
	DosCall(_RENAME, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) == 0) {
		SendStringToControlConnection("250 File renamed successfully\r\n");
	} else {
		SendStringToControlConnection2("550 Can't rename file: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
	}
}


void EndRenameSequence()
{
	mfree(clientConnection.rnfrSource);
	clientConnection.rnfrSource = null;
	clientConnection.connectionState = CONN_IDLE;
}


void BuildCommandArgumentPrintablePath(char* destinationPrintablePath)
{
	bool isAbsolutePath = (receivedCommandParameter[0] == '/');
	bool currentDirIsRoot = StringIs(printableBaseDirectory, "/");

	if(destinationPrintablePath != printableBaseDirectory) {
		strcpy(destinationPrintablePath, printableBaseDirectory);
	}
	if(isAbsolutePath) {
		strcpy(destinationPrintablePath, receivedCommandParameter);
	} else {
		if(!currentDirIsRoot) {
			AppendCharToString(destinationPrintablePath, '/');
		}
		AppendToString(destinationPrintablePath, receivedCommandParameter);
	}
}


void BuildCommandArgumentPhysicalPath()
{
	bool isAbsolutePath = (receivedCommandParameter[0] == '/');
	bool currentDirIsRoot = StringIs(printableBaseDirectory, "/");

	if(StringIs(receivedCommandParameter, "/")) {
		strcpy(commandArgumentPhysicalPath, basePhysicalDirectory);
		return;
	}

	RemoveLastSlash(receivedCommandParameter);
	

	if(isAbsolutePath) {
		strcpy(commandArgumentPhysicalPath, basePhysicalDirectory);
		if(!baseDirectoryIsDriveRoot) {
			AppendCharToString(commandArgumentPhysicalPath, '\\');
		}

		AppendToString(commandArgumentPhysicalPath, &receivedCommandParameter[1]);
	} else {
		strcpy(commandArgumentPhysicalPath, currentPhysicalDirectory);
		if(!currentDirIsRoot || !baseDirectoryIsDriveRoot) {
			AppendCharToString(commandArgumentPhysicalPath, '\\');
		}

		AppendToString(commandArgumentPhysicalPath, receivedCommandParameter);
	}

	AdaptSlashes(commandArgumentPhysicalPath);
	RemoveLastSlash(commandArgumentPhysicalPath);
}


void ProcessCdupCommand()
{
	int charsToRemove = 0;
	char* pointer;

	if(StringIs(currentPhysicalDirectory, "/")) {
		SendStringToControlConnection(strOkCurrentDirIsRoot);
		return;
	}

	pointer = printableBaseDirectory + strlen(printableBaseDirectory) - 1;
	while(*pointer != '/') {
		pointer--;
		charsToRemove++;
	}

	if(pointer == printableBaseDirectory) {
		printableBaseDirectory[1] = '\0';
		strcpy(currentPhysicalDirectory, basePhysicalDirectory);
	} else {
		*pointer = '\0';
		currentPhysicalDirectory[strlen(currentPhysicalDirectory) - charsToRemove - 1] = '\0';
	}

	SendStringToControlConnection2("250 OK. Current directory is %s\r\n", printableBaseDirectory);
	//printf("***current dir: %s\r\n", currentPhysicalDirectory); 
}


void ProcessPasvCommand()
{
	clientConnection.passiveModePort = lastUsedPassivePort++;
	if(lastUsedPassivePort == 0) {
		lastUsedPassivePort = PASSIVE_PORT_BASE;
	}

	clientConnection.passiveMode = true;

	if(!OpenDataConnection()) {
		return;
	}

	sprintf(dataBuffer, "227 Entering Passive Mode (%i,%i,%i,%i,%i,%i)\r\n",
		serverIP[0], serverIP[1], serverIP[2], serverIP[3],
		((byte*)&clientConnection.passiveModePort)[1],
		((byte*)&clientConnection.passiveModePort)[0]);
	SendStringToControlConnection(dataBuffer);
}


void ProcessPortCommand()
{
	char* paramPointer = receivedCommandParameter;
	int i;
	int value;

	clientConnection.passiveMode = false;

	for(i = 0; i < 4; i++) {
		value = atoi(paramPointer);
		clientConnection.clientDataConnIP[i] = (byte)value;
		while(*paramPointer++ != ',');
	}

	clientConnection.clientDataConnPort = ((byte)atoi(paramPointer)) << 8;
	while(*paramPointer++ != ',');
	clientConnection.clientDataConnPort |= (byte)atoi(paramPointer);

	//printf("*** port cmd, IP: %i.%i.%i.%i, port: %i\r\n",
	//	clientConnection.clientDataConnIP[0], clientConnection.clientDataConnIP[1], clientConnection.clientDataConnIP[2], clientConnection.clientDataConnIP[3], 
	//	clientConnection.clientDataConnPort);
    SendStringToControlConnection("200 PORT command successful\r\n");
}


void LongToAsciiJustified(unsigned long value, char* destination, byte maxLength)
{
	byte i = 0;
	byte remaining;

	destination += maxLength;
	*destination-- = '\0';

	for(i = 0; i < maxLength; i++) {
		remaining = value % 10;
		*destination-- = (char)(remaining + (byte)'0');
		value /= 10;
	}

	destination++;
	while(*destination == '0') {
		*destination++ = ' ';
	}

	if(*destination == '\0') {
		destination[-1] = '0';
		return;
	}
}


void ProcessMlstCommand()
{
	byte error;
	char date[16];
	char fileSize[11];
	char* pointer;
	bool emptyArgument;

	if(StringIs(receivedCommandParameter, ".")) {
		*receivedCommandParameter = '\0';
	}

	if(ArgumentContainsWildcards()) {
		return;
	}

	emptyArgument = (*receivedCommandParameter == '\0');

	if(emptyArgument && StringIs(printableBaseDirectory, "/") && baseDirectoryIsDriveRoot) {
		SendStringToControlConnection(
			"250-Begin\r\n"
			" type=cdir;modify=19800101000000; .\r\n"
			"250 End.\r\n");
		return;
	}

	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
    regs.Bytes.B = ATTR_DIRECTORY;
   	regs.Words.IX = (int)&tempFIB;
   	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
   	error = regs.Bytes.A;
   	if(error == _NOFIL) {
		SendStringToControlConnection("550 File not found\r\n");
	} else if(error != 0) {
		SendStringToControlConnection2("451 Error when obtaining file information: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
	} else {
		GenerateDateString(date);
		LongToAsciiJustified(tempFIB.fileSize, fileSize, 10);
		pointer = fileSize;
		while(*pointer == ' ') {
			pointer++;
		}
		if((tempFIB.attributes & ATTR_DIRECTORY) == 0) {
			sprintf(dataBuffer,
				"250-Begin\r\n"
				" type=file;size=%s;modify=%s; %s\r\n"
				"250 End.\r\n",
				pointer,
				date,
				tempFIB.filename
			);
		} else {
			sprintf(dataBuffer,
				"250-Begin\r\n"
				" type=%s;modify=%s; %s\r\n"
				"250 End.\r\n",
				emptyArgument ? "cdir" : "dir",
				date,
				emptyArgument ? "." : tempFIB.filename
			);
		}

		SendStringToControlConnection(dataBuffer);
	}
}


bool ArgumentContainsWildcards()
{
	char* pointer = receivedCommandParameter;
	while(*pointer != '\0') {
		if(*pointer == '?' || *pointer == '*') {
			SendStringToControlConnection("550 File not found\r\n");
			return true;
		}
		pointer++;
	}
	return false;
}


void ProcessListCommand(byte listCommandType)
{
    int entries = 0;
    byte error;
    byte dosFunction = _FFIRST;
	char fileSize[11];
	char date[15];
	char month[3];
	char day[3];
	byte monthNumber;
	byte dayNumber;
	int yearNumber;
	bool oldDebugMode;
	bool isDirAll = false;
	char* pointer;
	char* pointerToLastItem;
	bool emptyArgument;

	emptyArgument = (*receivedCommandParameter == '\0');

    if(*receivedCommandParameter == '\0' || StringIs(receivedCommandParameter, ".") || StringIs(receivedCommandParameter, "*")) {
        strcpy(receivedCommandParameter, "*.*");
		isDirAll = true;
    }
    
    BuildCommandArgumentPhysicalPath();

	pointerToLastItem = commandArgumentPhysicalPath + strlen(commandArgumentPhysicalPath);
	while(*pointerToLastItem != '\\') {
		pointerToLastItem--;
	}
	pointerToLastItem++;

	if(listCommandType == CMD_STAT) {
		SendStringToControlConnection("213-STAT\r\n");
		oldDebugMode = debugMode;
		debugMode = false;
	} else if(!OpenDataConnection()) {
		return;
	}
	
    regs.Words.DE = (int)commandArgumentPhysicalPath;
    regs.Bytes.B = listCommandType == CMD_NLST ? 0 : ATTR_DIRECTORY;
	while(true) {
    	regs.Words.IX = (int)&tempFIB;
    	DosCall(dosFunction, &regs, REGS_ALL, REGS_AF);
    	error = regs.Bytes.A;
    	if(error == _NOFIL) {
			if(listCommandType == CMD_STAT) {
				debugMode = oldDebugMode;
				SendStringToControlConnection2("213 End, %i entries.\r\n", entries);
			} else {
    			SendStringToControlConnection2("226 %i entries\r\n", entries);
			}
    	    break;
    	} else if(error != 0) {
			if(listCommandType == CMD_STAT) {
				debugMode = oldDebugMode;
			}
    	    SendStringToControlConnection2("451 Error when listing files: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
    	    break;
    	} else if(listCommandType != CMD_MLSD && (StringIs(tempFIB.filename, "." || StringIs(tempFIB.filename, "..")))) {
			dosFunction = _FNEXT;
			continue;
		} else if(dosFunction == _FFIRST && StringIs(tempFIB.filename, pointerToLastItem) && ((tempFIB.attributes & ATTR_DIRECTORY) != 0)) {
			//If the command parameter is a name which happens to be a directory,
			//the contents of that directory must be shown.
			AppendToString(commandArgumentPhysicalPath, "\\*.*");
			continue;
		}
    	
    	entries++;
    	
    	if(listCommandType == CMD_NLST) {
			 sprintf(dataBuffer, "%s\r\n", tempFIB.filename);
		} else if(listCommandType == CMD_MLSD) {
			GenerateDateString(date);
			LongToAsciiJustified(tempFIB.fileSize, fileSize, 10);
			pointer = fileSize;
			while(*pointer == ' ') {
				pointer++;
			}
			if((tempFIB.attributes & ATTR_DIRECTORY) == 0) {
				sprintf(dataBuffer,
					"type=file;size=%s;modify=%s; %s\r\n",
					pointer,
					date,
					tempFIB.filename
				);
			} else {
				sprintf(dataBuffer,
					"type=%s;modify=%s; %s\r\n",
					StringIs(tempFIB.filename, ".") ? "cdir" :
					StringIs(tempFIB.filename, "..") ? "pdir" : "dir",
					date,
					tempFIB.filename
				);
			}
		} else {
			LongToAsciiJustified(tempFIB.fileSize, fileSize, 10);

			dayNumber = tempFIB.dateOfModification[0] & 0x1F;
			if(dayNumber < 1) {
				dayNumber = 1;
			} else if(dayNumber > 31) {
				dayNumber = 31;
			}
			monthNumber = ((*(uint*)&(tempFIB.dateOfModification)) >> 5) & 0x0F;
			if(monthNumber > 12) {
				monthNumber = 0;
			}
			yearNumber = ((tempFIB.dateOfModification[1] >> 1) & 0x7F) + 1980;
			if(yearNumber < 1000 || yearNumber > 9999) {
				yearNumber = 1980;
			}

			LongToAsciiJustified(dayNumber, day, 2);
			LongToAsciiJustified(monthNumber, month, 2);

    	    sprintf(dataBuffer, 
				"%crw-r--r--   0 0 0     %s %s %s  %i %s\r\n",
				(tempFIB.attributes & ATTR_DIRECTORY) == 0 ? '-' : 'd',
				fileSize,
				monthNames[monthNumber],
				day,
				yearNumber,
				tempFIB.filename);
    	}

		if(listCommandType == CMD_STAT) {
			SendStringToControlConnection(dataBuffer);
		} else {
    		if(!SendTcpData(clientConnection.dataConnTcpHandle, dataBuffer, strlen(dataBuffer))) {
    			SendStringToControlConnection(strDataConnLost);
    			break;
			}
    	}
    	
    	dosFunction = _FNEXT;
	}

	if(listCommandType == CMD_STAT) {
		debugMode = oldDebugMode;
	} else {
		CloseDataConnection();
	}
}


void ProcessStatCommand()
{
	if(*receivedCommandParameter == '\0') {
		SendStringToControlConnection("211-ObsoFTP 1.0 - http://www.konamiman.com\r\n");
		if(clientConnection.connectionState == CONN_RECEIVING_FILE) {
			SendStringToControlConnection("211 Sending file...\r\n");
		} else if(clientConnection.connectionState == CONN_RECEIVING_FILE) {
			SendStringToControlConnection("211 Receiving file...\r\n");
		} else {
			CalculateUploadedAndDownloadedString(dataBuffer + 256, "211");
			SendStringToControlConnection2("%s211 I'm idle. Your wish is my command.\r\n", dataBuffer + 256);
		}
	} else {
		ProcessListCommand(CMD_STAT);
	}
}


void PorcessSizeCommand()
{
	char fileSize[11];
	char* pointer;
	byte error;

	if(StringIs(receivedCommandParameter, "/")) {
		SendStringToControlConnection(strCantgetSizeOfDirectory);
		return;
	}

	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
    regs.Bytes.B = ATTR_DIRECTORY;
    regs.Words.IX =(int)&tempFIB;
    DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);

	error = regs.Bytes.A;
	if(error == _NOFIL) {
		SendStringToControlConnection(strFileNotFound);
		return;
    } else if(error != 0) {
    	SendStringToControlConnection2("451 Error when retrieving file size: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
		return;
	} else if((tempFIB.attributes & ATTR_DIRECTORY) != 0) {
		SendStringToControlConnection(strCantgetSizeOfDirectory);
		return;
	}

	LongToAsciiJustified(tempFIB.fileSize, fileSize, 10);
	pointer = fileSize;
	while(*pointer == ' ') {
		pointer++;
	}

	SendStringToControlConnection2("213 %s\r\n", pointer);
}


void ProcessMdtmCommand()
{
	byte error;
	
	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
    regs.Bytes.B = ATTR_DIRECTORY;
   	regs.Words.IX = (int)&tempFIB;
   	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
    error = regs.Bytes.A;
    if(error == _NOFIL) {
		SendStringToControlConnection(strFileNotFound);
		return;
	} else if(error != 0) {
		SendStringToControlConnection2("451 Error when retrieving file modification date: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
		return;
	}

	strcpy(dataBuffer, "213 ");
	GenerateDateString(dataBuffer + 4);
	AppendToString(dataBuffer, "\r\n");
	SendStringToControlConnection(dataBuffer);
}


void GenerateDateString(char* destination)
{
	byte value;
	byte dateData[5];
	int i;
	int year;
	char* pointer;

	year = ((tempFIB.dateOfModification[1] >> 1) & 0x7F) + 1980;
	dateData[0] = ((*(uint*)&(tempFIB.dateOfModification)) >> 5) & 0x0F;
	dateData[1] = tempFIB.dateOfModification[0] & 0x1F;
	dateData[2] = ((tempFIB.timeOfModification[1]) >> 3) & 0x1F;
	dateData[3] = ((*(uint*)&(tempFIB.timeOfModification)) >> 5) & 0x3F;
	dateData[4] = tempFIB.timeOfModification[0] & 0x1F;

	sprintf(destination, "%i", year);
	pointer = destination + 4;
	for(i = 0; i < 5; i++) {
		value = dateData[i];
		if(value < 10) {
			*pointer++ = '0';
		}
		sprintf(pointer, "%i", value);
		pointer += strlen(pointer);
	}
}


void AppendToString(char* baseString, char* stringToAppend)
{
	strcpy(baseString + strlen(baseString), stringToAppend);
}


void AppendCharToString(char* baseString, char charToAppend)
{
	int len = strlen(baseString);
	baseString[len] = charToAppend;
	baseString[len+1] = '\0';
}


void ProcessRestCommand()
{
	char* pointer;
	long value = 0;
	char ch;

	if(*receivedCommandParameter == '\0') {
		SendStringToControlConnection("501 Parameter required for REST command\r\n");
		return;
	}
	
	pointer = receivedCommandParameter;
	while((ch = *pointer) != 0) {
		if(ch < '0' || ch > '9') {
			SendStringToControlConnection("501 Parameter for REST command must contain digits only\r\n");
			return;
		}
		value = (value * 10) + (ch - '0');
		pointer++;
	}

	clientConnection.restartPosition = value;
	SendStringToControlConnection2("350 Restarting at %s. Send STOR or RETR.\r\n", receivedCommandParameter);
}


bool SetFileHandlePointerForRest(byte fileHandle)
{
	byte error;

	if(clientConnection.restartPosition == 0) {
		return true;
	}

	regs.Bytes.A = 0;	//seek from start of file
	regs.Words.DE = ((uint*)&(clientConnection.restartPosition))[1];
	regs.Words.HL = ((uint*)&(clientConnection.restartPosition))[0];
	//printf("*** restarting at: %x, %x\r\n", regs.Words.DE, regs.Words.HL);
	DosCall(_SEEK, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) == 0) {
		return true;
	} else {
		CloseFile(fileHandle);
		SendStringToControlConnection2("451 Error when changing file pointer: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
		return false;
	}
}


void ProcessRetrCommand()
{
	byte error;
	byte fileHandle;

	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
	regs.Bytes.A = 1; //open for read
	DosCall(_OPEN, &regs, REGS_MAIN, REGS_MAIN);
	error = regs.Bytes.A;
	fileHandle = regs.Bytes.B;
	if(error == _NOFIL) {
		SendStringToControlConnection(strFileNotFound);
		return;
	} else if(error != 0) {
    	SendStringToControlConnection2("451 Error when opening file: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
		return;
	} else if(!SetFileHandlePointerForRest(fileHandle)) {
		return;
	}

	if(!OpenDataConnection()) {
		CloseFile(fileHandle);
		return;
	}

	clientConnection.connectionState = CONN_SENDING_FILE;
	clientConnection.fileHandle = fileHandle;
}


void ProcessStorOrAppeCommand(bool append)
{
	byte error;
	byte fileHandle;
	bool restNeeded = (clientConnection.restartPosition != 0);

	if(IsReadOnlyServer()) {
		return;
	}

	BuildCommandArgumentPhysicalPath();

	regs.Words.DE = (int)commandArgumentPhysicalPath;
	regs.Bytes.B = (append || restNeeded) ? ATTR_DO_NOT_OVERWRITE : 0;
	regs.Bytes.A = 2;	//write-only mode
	DosCall(_CREATE, &regs, REGS_MAIN, REGS_MAIN);
	error = regs.Bytes.A;

	if((append || restNeeded) && error == _FILEX) {
		regs.Words.DE = (int)commandArgumentPhysicalPath;
		regs.Bytes.A = 2;
		DosCall(_OPEN, &regs, REGS_MAIN, REGS_MAIN);
		error = regs.Bytes.A;
	}

	if(error != 0) {
		SendStringToControlConnection2("451 Error when opening or creating file: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
		return;
	}
	fileHandle = regs.Bytes.B;

	if(restNeeded) {
		if(!SetFileHandlePointerForRest(fileHandle)) {
			return;
		}
	} else if(append) {
		regs.Bytes.A = 2;	//seek from end of file
		regs.Words.HL = 0;
		regs.Words.DE = 0;
		DosCall(_SEEK, &regs, REGS_MAIN, REGS_AF);
		if((error = regs.Bytes.A) != 0) {
			CloseFile(fileHandle);
			SendStringToControlConnection2("451 Error when changing file pointer: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
			return;
		}
	}

	if(!OpenDataConnection()) {
		CloseFile(fileHandle);
		return;
	}

	clientConnection.connectionState = CONN_RECEIVING_FILE;
	clientConnection.fileHandle = fileHandle;
}


void ProcessAborCommand()
{
	if(clientConnection.fileHandle == 0) {
		SendStringToControlConnection("226 Nothing to abort\r\n");
	} else {
		SendStringToControlConnection("226 Data transfer aborted\r\n");
		EndFileTransfer();
	}
}


bool ContinueSendingFile()
{
	byte error;
	int readSize;

	regs.Bytes.B = clientConnection.fileHandle;
	regs.Words.DE = (int)dataBuffer;
	regs.Words.HL = DATA_BUFFER_SIZE;
	DosCall(_READ, &regs, REGS_MAIN, REGS_MAIN);
	error = regs.Bytes.A;
	readSize = regs.Words.HL;

	if(readSize > 0) {
		if(!SendTcpData(clientConnection.dataConnTcpHandle, dataBuffer, readSize)) {
			SendStringToControlConnection(strDataConnLost);
			EndFileTransfer();
		} else {
			clientConnection.currentFileBytes += readSize;
		}
	} else if(error == _EOF) {
		SendStringToControlConnection(strTransferCompleted);
		clientConnection.sentFiles++;
		clientConnection.sentBytes += clientConnection.currentFileBytes;
		EndFileTransfer();
	} else {
		SendStringToControlConnection2("451 Error when reading file: %s\r\n", ExplainDosErrorCode(error, dataBuffer + 128));
		EndFileTransfer();
	}

	return true;
}


bool ContinueReceivingFile()
{
	byte error;
	int receivedSize;

	regs.Bytes.B = clientConnection.dataConnTcpHandle;
    regs.Words.DE = (int)dataBuffer;
    regs.Words.HL = DATA_BUFFER_SIZE;
    UnapiCall(&codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
		SendStringToControlConnection(strDataConnLost);
		EndFileTransfer();
		return false;
	}

	receivedSize = regs.Words.BC;
	if(receivedSize == 0) {
		if(!IsEstablishedConnection(clientConnection.dataConnTcpHandle)) {
			SendStringToControlConnection(strTransferCompleted);
			clientConnection.receivedFiles++;
			clientConnection.receivedBytes += clientConnection.currentFileBytes;
			EndFileTransfer();
		}
		return false;
	}

	regs.Bytes.B = clientConnection.fileHandle;
    regs.Words.DE = (int)dataBuffer;
    regs.Words.HL = receivedSize;
	DosCall(_WRITE, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) != 0) {
		sprintf(dataBuffer, "%s Error when writing to file: %s\r\n",
			error == _DKFUL || error == _DRFUL ? "452" : "451",
			ExplainDosErrorCode(error, dataBuffer + 128));
		SendStringToControlConnection(dataBuffer);
		EndFileTransfer();
	} else {
		clientConnection.currentFileBytes += receivedSize;
	}

	return true;
}


void EndFileTransfer()
{
	CloseDataConnection();
	CloseFile(clientConnection.fileHandle);
	clientConnection.fileHandle = 0;
	clientConnection.connectionState = CONN_IDLE;
	clientConnection.currentFileBytes = 0;
	clientConnection.restartPosition = 0;
}


void SendStringToControlConnection2(char* string, char* parameter)
{
	sprintf(dataBuffer, string, parameter);
	SendStringToControlConnection(dataBuffer);
}


void SendStringToControlConnection(char* string)
{
	char theChar = 10;
	char* temp;

	if(string != dataBuffer) {
		strcpy(dataBuffer, string);
	}

	SendTcpData(clientConnection.controlConnTcpHandle, dataBuffer, strlen(string));

	if(!debugMode) {
		return;
	}

	temp = string;
	while(*temp != 0) {
		if(theChar == 10) {
			printf("--> ");
		}
		theChar = *temp++;
		putchar(theChar);
	}
}


void PatchInsertDiskPromptHook()
{
	byte* pointer = (byte*)0xF24F;
	oldInsertDiskPromptHook = *pointer;
	*pointer = 0xF1;
	insertDiskPromptHookPatched = true;
}


void RestoreInsertDiskPromptHook()
{
	if(insertDiskPromptHookPatched) {
		byte* pointer = (byte*)0xF24F;
		*pointer = oldInsertDiskPromptHook;
	}
}

#define RDSLT 0x000C
#define EXPTBL 0xFCC1
#define MSX_TYPE 0x002D

void BuildWelcomeMessage()
{
	char* dosVersion = critical_malloc(6);
	char* msxType;
	char* unapiName = critical_malloc(80);

    char* baseString =
        "220------ Welcome to ObsoFTP, the FTP server for MSX -------\r\n"
		"220-\r\n"
        "220-You are talking to a MSX%s computer running MSX-DOS %s\r\n"
        "220-The TCP/IP implementation is %s\r\n"
		"220-Please note that I can serve only one client at a time.\r\n"
        "220-Any user name and password combination will be accepted.\r\n"
        "220 You will be disconnected after 5 minutes of inactivity.\r\n";

	regs.Bytes.A = *(byte*)EXPTBL;
	regs.Words.HL = MSX_TYPE;
	AsmCall(RDSLT, &regs, REGS_MAIN, REGS_MAIN);
	switch(regs.Bytes.A) {
		case 1:
			msxType = "2";
			break;
		case 2:
			msxType = "2+";
			break;
		case 3:
			msxType = " Turbo-R";
			break;
		default:
			msxType = "";
			break;
	}

	DosCall(_DOSVER, &regs, REGS_NONE, REGS_MAIN);
    sprintf(dosVersion, "%i.%i%i", regs.Bytes.B, (regs.Bytes.C >> 4) & 0xF, regs.Bytes.C & 0xF);

	GetUnapiImplementationName(unapiName);

	sprintf(welcomeMessage, baseString, msxType, dosVersion, unapiName);

	mfree(unapiName);
	mfree(dosVersion);
}


bool ReadTcpControlData()
{
    regs.Bytes.B = clientConnection.controlConnTcpHandle;
    regs.Words.DE = (int)controlDataReceiveBuffer;
    regs.Words.HL = COMMAND_RECEIVE_BUFFER_SIZE;
    UnapiCall(&codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
		return false;
    }

    controlDataReceiveRemaining = regs.UWords.BC;
    controlDataReceiveBufferPointer = controlDataReceiveBuffer;
	return controlDataReceiveRemaining != 0;
}


bool SendTcpData(byte connHandle, byte* data, int dataSize)
{
    do {
        do {
            regs.Bytes.B = connHandle;
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
    
    return regs.Bytes.A == 0;
}


bool StringEndsWith(char* string, char* substring)
{
	string += (strlen(string) - strlen(substring));
	return StringIs(string, substring);
}


void RemoveLastSlash(char* string)
{
	char ch;

	int len = strlen(string) - 1;
	ch = string[len];
	if(len >= 0 && (ch == '\\' || ch == '/')) {
		string[len] = '\0';
	}
}


void GetUnapiImplementationName(char* destination)
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
}


void ToUpperCase(char* string)
{
	char ch;

	while((ch = *string) != '\0') {
		*string = (ch & ~32);
		string++;
	}
}


void AdaptSlashes(char* string)
{
	char ch;

	while((ch = *string) != '\0') {
		if(ch == '/') {
			*string = '\\';
		}
		string++;
	}
}


bool IsReadOnlyServer()
{
	if(readOnlyServer) {
		SendStringToControlConnection("550 Sorry, this is a read-only server\r\n");
		return true;
	} else {
		return false;
	}
}


void SendDosErrorMessage(char* prefix, byte errorCode)
{
	ExplainDosErrorCode(errorCode, dataBuffer);
	sprintf(dataBuffer + 64, "%s: %s\r\n", prefix, dataBuffer);
	SendStringToControlConnection(dataBuffer);
}


bool OpenDataConnection()
{
	int ticksWaited = 0;
	byte tcpConn;

	if(clientConnection.dataConnTcpHandle == 0) {
		tcpConn = OpenTcpConnection(
			clientConnection.passiveMode ? clientConnection.passiveModePort : clientConnection.clientDataConnPort,
			!clientConnection.passiveMode,
			clientConnection.passiveMode ? null : clientConnection.clientDataConnIP);

		if(clientConnection.passiveMode) {
			clientConnection.dataConnTcpHandle = tcpConn;
			return true;
		}
	} else {
		tcpConn = clientConnection.dataConnTcpHandle;
	}

	if(WaitUntilDataConnectionIsOpen(tcpConn)) {
		SendStringToControlConnection("150 Opening data connection\r\n");
		clientConnection.dataConnTcpHandle = tcpConn;
		return true;
	} else {
		SendStringToControlConnection("425 No data connection\r\n");
		return false;
	}
}


bool WaitUntilDataConnectionIsOpen(byte tcpConn)
{
	int ticksWaited = 0;

	lastSysTimer = *SYSTIMER;
	while(true) {
	    TerminateIfEscIsPressed();
		DosCall(_CONST, &regs, REGS_NONE, REGS_NONE);	//force checking CTRL-C and CTRL-STOP
        
		if(*SYSTIMER != lastSysTimer) {
			lastSysTimer = *SYSTIMER;
			ticksWaited++;
		}
	
		if(IsEstablishedConnection(tcpConn)) {
			return true;
		}

		if(ticksWaited > CONN_SETUP_TIMEOUT) {
			CloseDataConnection();
			return false;
		}
	}
}


void CloseDataConnection()
{
	if(clientConnection.dataConnTcpHandle != 0) {
		regs.Bytes.B = clientConnection.dataConnTcpHandle;	//this closes the data connection too, if it is open
		UnapiCall(&codeBlock, TCPIP_TCP_CLOSE, &regs, REGS_MAIN, REGS_MAIN);
		clientConnection.dataConnTcpHandle = 0;
	}
}


void CloseFile(byte fileHandle)
{
	regs.Bytes.B = fileHandle;
	DosCall(_CLOSE, &regs, REGS_MAIN, REGS_NONE);
}


void DisplayFunctionKeys()
{
	BiosCall(DSPFNK, &regs, REGS_NONE);
}


void HideFunctionKeys()
{
	BiosCall(ERAFNK, &regs, REGS_NONE);
}


void BackupAndInitializeFunctionKeysState()
{
	functionKeyDisplayOriginal = *functionKeysDisplaySwitch;
	memcpy(functionKeysOriginalContent, functionKeysContents, 80);
	HideFunctionKeys();
	Clear(functionKeysContents, 80);
	functionKeysPatched = true;
}


void SetFunctionKeyContents(int keyIndex, char* contents)
{
	byte* pointer = functionKeysContents + (16 * (keyIndex - 1));
	Clear(pointer, 16);
	strcpy(pointer, contents);
	DisplayFunctionKeys();
}


void RestoreFunctionKeysState()
{
	if(functionKeysPatched) {
		HideFunctionKeys();
		memcpy(functionKeysContents, functionKeysOriginalContent, 80);
		if(functionKeyDisplayOriginal != 0) {
			DisplayFunctionKeys();
		}
	}
}
