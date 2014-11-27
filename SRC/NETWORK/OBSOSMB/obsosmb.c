/* ObsoSMB - SMB server for the TCP/IP UNAPI 1.0
   By Konamiman, 4/2011

   Compilation command line:
   
   sdcc --code-loc 0x170 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.lib smbserv.c
   hex2bin -e com smbserv.ihx
   
   ASM.LIB, MSXCHAR.LIB and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com
*/

/*
This program has been developed "on the fly", looking at the TCP frames
used by Windows clients and implementing the SMB commands needed to make it work.
Therefore, when compared with the MS-CIFS specification there are both
unimplemented mandatory commands (which I didn't implement because I have no way
to test them) and implemented deprecated commands (which are still used by
modern Windows clients).

I'm sorry but I failed on making it work with Samba.

The SMB dialect implemented is "NT LM 0.12", as defined in the MS-CIFS document.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "asm.h"
#include "smb.h"
#include "rpc.h"

typedef unsigned char bool;
#define false (0)
#define true (!false)
#define null ((void*)0)

//#ifndef ushort
typedef unsigned short ushort;
//#endif

//#ifndef ulong
typedef unsigned long ulong;
//#endif

#define SMB_PORT 445

#define GUID_LEN 16

#define SMB_SERVER_FLAGS (SMB_FLAGS_CASE_INSENSITIVE | SMB_FLAGS_CANONICALIZED_PATHS | SMB_FLAGS_REPLY)
#define SMB_SERVER_FLAGS2 (0)
#define SMB_SERVER_CAPABILITIES (CAP_RPC_REMOTE_APIS)

#define FID_SRVSVC 0x100
#define FID_WKSSVC 0x102
#define IPC_TID 0x00FF
#define FID_DIRECTORY 0xFE

#define MAX_TCP_CONNS 8
#define MAX_TREES_PER_CONN 8
#define MAX_OPENS_PER_TREE 8
#define MAX_SEARCHES_PER_TREE 8
#define NO_REQUESTS_INACTIVITY_TIMEOUT (5*60*60)  //5 minutes * 60 timer interrupts per second
#define PARTIAL_REQUEST_INACTIVITY_TIMEOUT (5*60)  //5 seconds * 60 timer interrupts per second

#define MAX_MSX_DOS_DRIVES 8
#define MSXDOS_SECTOR_SIZE 512

#define MAX_REQUEST_SIZE 1024
#define MAX_RESPONSE_SIZE 1024

#define NETBIOS_HEADER_LENGTH 4
#define SMB_HEADER_LENGTH 32

#define MAX_FIND_ENTRIES_IN_PACKET 5


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

enum ClientConnectionStates {
    CLIENT_LISTENING = 0,
    CLIENT_CONNECTED = 1,
    CLIENT_LOGGED_IN = 2
};

enum RpcPendingStates {
	RPC_NONE = 0,
	RPC_BIND_ACK_PENDING,
	RPC_ENUMSHARES_PENDING
};

typedef struct {
    char driveLetter;
    int TID;
	int bytesPerCluster;
    byte openFileHandles[MAX_OPENS_PER_TREE];
	t_FileInfoBlock* searches[MAX_SEARCHES_PER_TREE];
} t_TreeConnection;

typedef struct {
    byte connectionState;
    byte tcpConnNumber;
    byte IP[4];
    t_TreeConnection* treeConnections[MAX_TREES_PER_CONN];
    int timeoutCounter;
	byte bindRequestContextItemsCount;
	byte bindRequestAcceptedContextIndex;
	byte rpcPendingState;
	unsigned long rpcCallId; 
} t_ClientConnection;
   
#define NO_CTX_ACCEPTED 0xFF

typedef struct {
    int Year;
    byte Month;
    byte Day;
    byte Hour;
    byte Minute;
    byte Second;
} t_Date;

typedef struct { 
    uint word0; 
    uint word1;
    uint word2;
    uint word3;
} longint;


   /* Global variables, GUIDs and strings */

Z80_registers regs;
byte conn;
unapi_code_block codeBlock;
bool readOnlyServer = false;
char sharedDrives[MAX_MSX_DOS_DRIVES + 1];
byte* malloc_ptr;
int maxAvailableTcpConnections;
t_ClientConnection* clientConnections;
byte* requestBuffer;
byte* responseBuffer;
t_ClientConnection* currentClientConnection;
uint lastSysTimer;
int currentRequestSize;
byte* requestReadPointer;
byte* responseWritePointer;
struct smb* request;
struct smb* response;
t_TreeConnection* currentTree;
byte* requestDataBytes;
int requestDataBytesCount;
byte requestParametersWordsCount;
unsigned long lastUsedSessionKey = 0;
unsigned short lastUsedUid = 0;
unsigned short lastUsedTid = 0;
byte currentClientIp[16];
unsigned long nextReferentId = 0;
byte serverIP[16];
struct smb_trans_request* trans2Request;
struct smb_trans_response* trans2Response;
byte* trans2RequestParameters;
byte* trans2RequestData;
t_TreeConnection* currentTreeConnection;
t_FileInfoBlock* tempFIB;
void copy(byte* to, byte* from, int len);
int timeZoneMinutes = 0;
int timeZoneSeconds = 0;
byte oldInsertDiskPromptHook;
ushort lastUsedEchoSequenceNumber;
byte functionKeyDisplayOriginal;
bool functionKeysPatched = false;
char functionKeysOriginalContent[80];
byte* functionKeysDisplaySwitch;
char* functionKeysContents;

const byte GUID_NDR[] = {0x04, 0x5d, 0x88, 0x8a, 0xeb, 0x1c, 0xc9, 0x11, 0x9f, 0xe8, 0x08, 0x00, 0x2b, 0x10, 0x48, 0x60};
//NDR64: {0x33, 0x05, 0x71, 0x71, 0xba, 0xbe, 0x37, 0x49, 0x83, 0x19, 0xb5, 0xdb, 0xef, 0x9c, 0xcc, 0x36};
const byte GUID_SRVSVC[] = {0xC8, 0x4F, 0x32, 0x4B, 0x70, 0x16, 0xD3, 0x01, 0x12, 0x78, 0x5A, 0x47, 0xBF, 0x6E, 0xE1, 0x88};
const byte GUID_WKSSVC[] = {0x98, 0xd0, 0xff, 0x6b, 0x12, 0xa1, 0x10, 0x36, 0x98, 0x33, 0x46, 0xc3, 0xf8, 0x7e, 0x34, 0x5a};

#define SECS_IN_MINUTE ((unsigned long)(60))
#define SECS_IN_HOUR ((unsigned long)(SECS_IN_MINUTE * 60))
#define SECS_IN_DAY ((unsigned long)(SECS_IN_HOUR * 24))
#define SECS_IN_MONTH_28 ((unsigned long)(SECS_IN_DAY * 28))
#define SECS_IN_MONTH_29 ((unsigned long)(SECS_IN_DAY * 29))
#define SECS_IN_MONTH_30 ((unsigned long)(SECS_IN_DAY * 30))
#define SECS_IN_MONTH_31 ((unsigned long)(SECS_IN_DAY * 31))
#define SECS_IN_YEAR ((unsigned long)(SECS_IN_DAY * 365))
#define SECS_IN_LYEAR ((unsigned long)(SECS_IN_DAY * 366))
#define SECS_1970_TO_2011 ((unsigned long)(1293840000))

#define BytesOfError(class, code) (byte)((ushort)code) & 0x00FF, (byte)((((ushort)code) & 0xFF00) >> 8) | (byte)(((ushort)class) << 6)

const byte MsxDosToSmbErrorMappings[] = {
	_NCOMP, BytesOfError(ERRHRD, ERRbadmedia),
	_WRERR, BytesOfError(ERRHRD, ERRwrite),
	_DISK,  BytesOfError(ERRHRD, ERRgeneral),
	_NRDY,  BytesOfError(ERRHRD, ERRnotready),
	_VERFY, BytesOfError(ERRHRD, ERRread),
	_DATA,  BytesOfError(ERRHRD, ERRdata),
	_RNF,   BytesOfError(ERRHRD, ERRbadsector),
	_WPROT, BytesOfError(ERRHRD, ERRnowrite),
	_UFORM, BytesOfError(ERRHRD, ERRbadmedia),
	_NDOS,  BytesOfError(ERRHRD, ERRbadmedia),
	_WDISK, BytesOfError(ERRHRD, ERRwrongdisk),
	_WFILE, BytesOfError(ERRHRD, ERRwrongdisk),
	_SEEKE, BytesOfError(ERRHRD, ERRseek),
	_IFAT,  BytesOfError(ERRHRD, ERRbadmedia),

	_INTER, BytesOfError(ERRSRV, ERRsrverror),
	_NORAM, BytesOfError(ERRDOS, ERRnomem),
	_IDRV,  BytesOfError(ERRDOS, ERRbaddrive),
	_IFNM,  BytesOfError(ERRDOS, ERRbadpath),
	_IPATH, BytesOfError(ERRDOS, ERRbadpath),
	_PLONG, BytesOfError(ERRDOS, ERRbadpath),
	_NOFIL, BytesOfError(ERRDOS, ERRbadfile),
	_NODIR, BytesOfError(ERRDOS, ERRbadpath),
	_DRFUL, BytesOfError(ERRDOS, ERRnoaccess),
	_DKFUL, BytesOfError(ERRHRD, ERRdiskfull),
	_DUPF,  BytesOfError(ERRDOS, ERRfilexists),
	_DIRE,  BytesOfError(ERRDOS, ERRnoaccess),
	_FILRO, BytesOfError(ERRHRD, ERRnowrite),
	_DIRNE, BytesOfError(ERRDOS, ERRremcd),
	_IATTR, BytesOfError(ERRDOS, ERRnoaccess),
	_DOT,   BytesOfError(ERRDOS, ERRnoaccess),
	_SYSX,  BytesOfError(ERRDOS, ERRfilexists),
	_DIRX,  BytesOfError(ERRDOS, ERRfilexists),
	_FILEX, BytesOfError(ERRDOS, ERRfilexists),
	_FOPEN, BytesOfError(ERRHRD, ERRbadshare),
	_FILE,  BytesOfError(ERRHRD, ERRbadmedia),
	_EOF,   BytesOfError(ERRDOS, ERReof),
	_ACCV,	BytesOfError(ERRDOS, ERRnoaccess),
	_NHAND, BytesOfError(ERRDOS, ERRnofids),
	_IHAND, BytesOfError(ERRDOS, ERRbadfid),
	_NOPEN, BytesOfError(ERRDOS, ERRbadfid),
	_HDEAD, BytesOfError(ERRDOS, ERRnoaccess),

	0
};

unsigned long SecsPerMonth[12] = {SECS_IN_MONTH_31, SECS_IN_MONTH_28, SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31, SECS_IN_MONTH_31, SECS_IN_MONTH_30,
    SECS_IN_MONTH_31, SECS_IN_MONTH_30, SECS_IN_MONTH_31};

const unsigned long NSECS_1601_TO_2011_HIGH = 0x01CBA946;
const unsigned long NSECS_1601_TO_2011_LOW = 0xD534C000;
const unsigned long NSECS_1601_TO_1980_HIGH = 0x01A8E79F;
const unsigned long NSECS_1601_TO_1980_LOW = 0xE1D58000;

const byte AndxCommands[] = {
    SMB_COM_OPEN_ANDX,
    SMB_COM_READ_ANDX,
    SMB_COM_WRITE_ANDX,
    SMB_COM_SESSION_SETUP_ANDX,
    SMB_COM_LOGOFF_ANDX,
    SMB_COM_TREE_CONNECT_ANDX,
    0
};

const char* strTitle=
    "ObsoSMB - SMB server for the TCP/IP UNAPI 1.0\r\n"
    "By Konamiman, 4/2011\r\n"
    "\r\n";
    
const char* strUsage=
    "Usage: obsosmb <drives>|all [mode={rw|ro}]\r\n"
    "\r\n"
    "Drives: drive letters to share, without colons.\r\n"
    "Example: \"ABC\" to share drives A:, B:, and C:.\r\n"
    "Or, \"all\" to share all the available drives.\r\n"
    "\r\n"
    "\"mode=rw\" shares the drives in read and write mode (default).\r\n"
    "\"mode=ro\" shares the drives in read only mode.\r\n"
	"\r\n"
	"Please create an environment item named TIMEZONE formatted as\r\n"
	"[+|-]hh:mm where hh=00-12, mm=00-59, in order to get the\r\n"
	"file dates and times properly displayed in clients.";
    
const char* strCRLF = "\r\n";
const char* strInvParam = "Invalid parameter";
const char* strNoNetwork = "No network connection available";
const char* strInvalidNetbios = "invalid NETBIOS header received";
const char* strConnLost = "connection lost";
const char* strInvSmb = "invalid SMB packet received";


  /* Code defines */

#define TerminateWithInvalidParameters() Terminate(strInvParam)
#define PrintNewLine() print(strCRLF)
#define ToLowerCase(ch) {ch |= 32;}
#define ToUpperCase(ch) {ch &= ~32;}
#define StringIs(a, b) (strcmpi(a,b)==0)
#define Clear(mem, size) memset(mem,0,size)
#define SetError(class, code) {response->error_class=class; response->error=code;}


  /* Function prototypes */

void ProcessParameters(char** argv, int argc);
void InitializeServer();
void OpenTcpConnection(t_ClientConnection* clientConnection);
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
void DoServerMainLoop();
void SetClientIpString();
void RegisterOpenConnection(byte tcpConnNumber);
void CloseClientConnection(char* reason);
bool IsDataAvailable(byte tcpConnNumber, int minimumLength);
bool ReceiveRequest();
void ProcessRequest();
bool IsAndxCommand(byte commandCode);
void ProcessCommand(byte commandCode);
int ProcessNegotiateRequest();
int ProcessSetupAndxRequest();
int ProcessTreeConnectAndxRequest();
int ProcessTreeDisconnectReques();
unsigned short ConnectTid(char driveLetter);
bool DisconnectTid(unsigned short tid);
int ProcessOpenAndxRequest();
int ProcessOpenAndxRequest_Ipc();
void ProcessRpcBindRequest(unsigned short fid);
int ProcessOpenAndxRequest_File();
int ProcessWriteRequest();
int ProcessWriteRequest_Ipc();
int ProcessWriteRequest_File();
int ProcessReadAndxRequest();
int ProcessReadAndxRequest_Ipc();
int ProcessReadAndxRequest_File();
int ProcessReadAndxRequest_SendBindAck(unsigned short fid);
int ProcessCloseRequest();
int ProcessCloseRequest_Ipc();
int ProcessCloseRequest_File();
int ProcessTransactionRequest();
int ProcessTrans_NetShareEnum(rpcconn_request_hdr_t* rpcRequest);
int ProcessTrans_NetSrvGetInfo(rpcconn_request_hdr_t* rpcRequest);
int ProcessTransaction2Request();
bool ProcessTrans2_QueryFsInformation();
bool ProcessTrans2_QueryFsInformation_FsAttributeInfo();
bool ProcessTrans2_QueryFsInformation_InfoVolume();
bool ProcessTrans2_QueryFsInformation_InfoAllocation();
bool ProcessTrans2_QueryPathInformation();
bool ProcessTrans2_Find2(bool isFirst);
int ProcessQueryInformationRequest();
int ProcessFindClose2Request();
int ProcessQueryInformation2Request();
int ProcessCreateOrDeleteDirectoryRequest(bool isDelete);
int ProcessRenameOrDeleteRequest(bool isDelete);
int ProcessSetInformationRequest();
char* SeparatePathAndFilename(char* path);
int ProcessEchoRequest();
int ProcessQueryInformationDiskRequest();
void InsertLongInResponse(long value);
void InsertReferentIdInResponse();
void InitializeResponse();
void SendResponse();
void SendErrorResponse(byte errorClass, unsigned short errorCode);
bool IsEstablishedConnection(byte tcpConnNumber);
void minit();
void* malloc(unsigned int size);
void mfree(void* address);
void* critical_malloc(unsigned int size);
int strcmpi(const char *a1, const char *a2);
int strncmpi(const char *a1, const char *a2, unsigned size);
bool StringStartsWith(const char* stringToCheck, const char* startingToken);
void CloseFileHandle(byte handle);
bool StringEndsWith(char* string, char* substring);
bool GuidsAreEqual(byte* guid1, byte* guid2);
void SetFiletimeField(t_Date* date, byte* destination, bool startAt1980);
void add64(longint* result, longint* a, longint* b);
void MultBy10Milions(longint* destination, longint* a);
void GetSystemDate(t_Date* destination);
void SetSmbErrorFromMsxdosError(byte errorCode);
bool GetCurrentTree();
void GetTimeZoneMinutes(byte* buffer);
bool CurrentTreeDriveIsAvailable();
void FillDateFromFib(t_Date* date, t_FileInfoBlock* fib);
void SetUtimeField(t_Date* date, unsigned long* destination);
byte* InsertAsUnicode(char* string, byte* destination);
byte* GetFileHandlePointer(byte fid);
void CalculateBytesPerCluster();
bool IsReadOnlyServer();
void PatchInsertDiskPromptHook();
void RestoreInsertDiskPromptHook();
void DisplayFunctionKeys();
void HideFunctionKeys();
void BackupAndInitializeFunctionKeysState();
void SetFunctionKeyContents(int keyIndex, char* contents);
void RestoreFunctionKeysState();


  /* Main */

int main(char** argv, int argc)
{
    *((byte*)codeBlock) = 0;
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
    char* writePointer;
    char* readPointer;
    char letter;
    byte loginVector;

    if(argc == 0) {
        print(strUsage);
        Terminate(null);
    }

    if(argc > 2) {
        TerminateWithInvalidParameters();
    }

    Clear(sharedDrives, MAX_MSX_DOS_DRIVES + 1);
    
    writePointer = &sharedDrives[0];
    if(StringIs(argv[0], "all")) {
        DosCall(_LOGIN, &regs, REGS_NONE, REGS_MAIN);
        loginVector = regs.Bytes.L;
        for(i=0; i < MAX_MSX_DOS_DRIVES; i++) {
            if((loginVector & 1) != 0) {
                *writePointer++ = i + 'A';
                loginVector >>= 1;
            }
        }
        if(*(writePointer-1) != 'H') {
            regs.Bytes.B = 0xFF;
            DosCall(_RAMD, &regs, REGS_MAIN, REGS_MAIN);
            if(regs.Bytes.B != 0) {
                *writePointer = 'H';
            }
        }
    } else {
        if(strlen(argv[0]) > MAX_MSX_DOS_DRIVES) {
            TerminateWithInvalidParameters();
        }
        readPointer = argv[0];
        for(i=0; i < strlen(argv[0]); i++) {
            letter = *readPointer++;
            ToUpperCase(letter);
            if(letter < 'A' || letter > ('A' + MAX_MSX_DOS_DRIVES - 1)) {
                TerminateWithInvalidParameters();
            }
            *writePointer++ = letter;
        }
    }
    
    if(argc == 2) {
        if(!StringStartsWith(argv[1], "mode=")) {
            TerminateWithInvalidParameters();
        }
        if(StringIs(argv[1]+5, "ro")) {
            readOnlyServer = true;
        } else if(!StringIs(argv[1]+5, "rw")) {
            TerminateWithInvalidParameters();
        }
    }
}

#define UPPER_RAM ((byte*)0xC000)
void InitializeServer()
{
    int i;
    InitializeTcpipUnapi();
    DisableAutoAbort();
	PatchInsertDiskPromptHook();

    clientConnections = critical_malloc(sizeof(t_ClientConnection) * maxAvailableTcpConnections);
	GetTimeZoneMinutes((byte*)clientConnections);
    Clear(clientConnections, sizeof(t_ClientConnection) * maxAvailableTcpConnections);
    requestBuffer = UPPER_RAM;
    responseBuffer = requestBuffer + MAX_REQUEST_SIZE;
	tempFIB = (t_FileInfoBlock*)(responseBuffer + MAX_RESPONSE_SIZE + NETBIOS_HEADER_LENGTH);

    for(i=0; i < maxAvailableTcpConnections; i++) {
        OpenTcpConnection(&clientConnections[i]);
    }

	regs.Bytes.B = 1;
	UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
	sprintf(serverIP, "%i.%i.%i.%i", regs.Bytes.L, regs.Bytes.H, regs.Bytes.E, regs.Bytes.D);

	functionKeysDisplaySwitch = (byte*)CNSDFG;
	functionKeysContents = (char*)(byte*)FNKSTR;
	BackupAndInitializeFunctionKeysState();
	SetFunctionKeyContents(1, "Server IP:");
	SetFunctionKeyContents(2, serverIP);

    printf("--- Server started in read%s mode, %i TCP connections available\r\n",
        readOnlyServer ? "-only" : " and write",
        maxAvailableTcpConnections);
    printf("--- Server address: %s\r\n", serverIP);
    printf("--- Shared drives: %s\r\n", sharedDrives);
    print ("--- Press ESC, CTRL-C or CTRL-STOP to terminate.\r\n\r\n");
}


void OpenTcpConnection(t_ClientConnection* clientConnection)
{
    t_TcpConnectionParameters* connParams = critical_malloc(sizeof(t_TcpConnectionParameters));
    Clear(connParams, sizeof(t_TcpConnectionParameters));
    connParams->flags = 1;
    connParams->localPort = SMB_PORT;

    Clear(clientConnection, sizeof(t_ClientConnection));

    regs.Words.HL = (int)connParams;
    UnapiCall(&codeBlock, TCPIP_TCP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        sprintf(requestBuffer, "Unexpected error when opening TCP connection: %i", regs.Bytes.A);
        Terminate(requestBuffer);
    }

    clientConnection->tcpConnNumber = regs.Bytes.B;
    
    mfree(connParams);
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
    
	RestoreFunctionKeysState();
    RestoreDefaultAbortRoutine();
	RestoreInsertDiskPromptHook();
    
    if(*((byte*)codeBlock) != 0) {
        AbortAllTransientTcpConnections();
    }
    
    regs.Bytes.B = (errorMessage == NULL ? 0 : 1);
    DosCall(_TERM, &regs, REGS_MAIN, REGS_NONE);
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
    if(regs.Bytes.D == 0) {
        Terminate("No free TCP connections available");
    }
    
    if(regs.Bytes.D > MAX_TCP_CONNS) {
        maxAvailableTcpConnections = MAX_TCP_CONNS;
    } else {
        maxAvailableTcpConnections = regs.Bytes.D;
    }
}


void AbortAllTransientTcpConnections()
{
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_NONE);
}


void DoServerMainLoop()
{
    int i;
    bool isEstablishedConnection;
    bool timerInterruptHappened = false;
    byte tcpConnNumber;
	bool newConnection;

    lastSysTimer = *SYSTIMER;
    while(true) {
        TerminateIfEscIsPressed();
        DosCall(_CONST, &regs, REGS_NONE, REGS_NONE);	//force checking CTRL-C and CTRL-STOP
        
        if(*SYSTIMER != lastSysTimer) {
            lastSysTimer = *SYSTIMER;
            timerInterruptHappened = true;
        }
        
        for(i=0; i < maxAvailableTcpConnections; i++) {
            currentClientConnection = &clientConnections[i];
            
            tcpConnNumber = currentClientConnection->tcpConnNumber;
            isEstablishedConnection = IsEstablishedConnection(tcpConnNumber);
            
			newConnection = false;
            if(currentClientConnection->connectionState == CLIENT_LISTENING && isEstablishedConnection) {
                RegisterOpenConnection(tcpConnNumber);
				newConnection = true;
            } else if(currentClientConnection->connectionState != CLIENT_LISTENING && !isEstablishedConnection) {
                CloseClientConnection(strConnLost);
            }

			SetClientIpString();
			if(newConnection) {
				printf("Client %s connected\r\n", currentClientIp);
			}
            
            if(currentClientConnection->connectionState != CLIENT_LISTENING) {
                if(IsDataAvailable(tcpConnNumber, NETBIOS_HEADER_LENGTH)) {
                    if(ReceiveRequest()) {
                        currentClientConnection->timeoutCounter = 0;
                        ProcessRequest();
                    }
                } else if(timerInterruptHappened) {
                    currentClientConnection->timeoutCounter++;
                    if(currentClientConnection->timeoutCounter >= NO_REQUESTS_INACTIVITY_TIMEOUT) {
                        CloseClientConnection("inactivity timeout expired");
                    }
                }
            }
        }
        
        timerInterruptHappened = false;
    }
}


void SetClientIpString()
{
	sprintf(currentClientIp, "%i.%i.%i.%i", currentClientConnection->IP[0], currentClientConnection->IP[1], currentClientConnection->IP[2], currentClientConnection->IP[3]);
}


void RegisterOpenConnection(byte tcpConnNumber)
{
    byte* buffer = critical_malloc(8);

    Clear(currentClientConnection, sizeof(t_ClientConnection));
    currentClientConnection->connectionState = CLIENT_CONNECTED;
    currentClientConnection->tcpConnNumber = tcpConnNumber;
    regs.Bytes.B = tcpConnNumber;
    regs.Words.HL = (int)buffer;
    UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    memcpy(&(currentClientConnection->IP), buffer, 4);
    
    mfree(buffer);
}


void CloseClientConnection(char* reason)
{
    int tree, file;
    byte fileHandle;
    t_TreeConnection* currentTree;
	t_FileInfoBlock* search;

	SetClientIpString();
	printf("Closing client connection %s: %s\r\n", currentClientIp, reason);
    
    for(tree=0; tree < MAX_TREES_PER_CONN; tree++)
    {
        currentTree = currentClientConnection->treeConnections[tree];
        if(currentTree == null) {
            continue;
        }
        
        for(file=0; file < MAX_OPENS_PER_TREE; file++) {
            fileHandle = currentTree->openFileHandles[file];
            if(fileHandle != 0) {
                CloseFileHandle(fileHandle);
            }
			search = currentTree->searches[file];
			if(search != null) {
				debug3("*** CloseClientConnection, close search %i (%x)\r\n", file, search);
				mfree(search);
			}
        }
        
        mfree(currentTree);
    }
    
    regs.Bytes.B = currentClientConnection->tcpConnNumber;
    UnapiCall(&codeBlock, TCPIP_TCP_ABORT, &regs, REGS_MAIN, REGS_MAIN);
    
    OpenTcpConnection(currentClientConnection);
}


bool IsDataAvailable(byte tcpConnNumber, int minimumLength)
{
    regs.Bytes.B = tcpConnNumber;
    regs.Words.HL = 0;
    UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    return (regs.Bytes.A == 0 && regs.Words.HL >= minimumLength);
}


bool ReceiveRequest()
{
    int remainingData;
    byte* receivePointer;
    int timeoutCounter = 0;

    regs.Bytes.B = currentClientConnection->tcpConnNumber;
    regs.Words.DE = (int)requestBuffer;
    regs.Words.HL = NETBIOS_HEADER_LENGTH;
    UnapiCall(&codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_AF);
    if(regs.Bytes.A != 0) {
        CloseClientConnection(strConnLost);
        return false;
    } else if(*requestBuffer != 0) {
        CloseClientConnection(strInvalidNetbios);
        return false;
    }
    
    remainingData = ((requestBuffer[2])<<8) | (requestBuffer[3]);
    if(remainingData == 0) {
        CloseClientConnection(strInvalidNetbios);
        return false;
    } else if(remainingData > MAX_REQUEST_SIZE) {
        CloseClientConnection("request too big received");
        return false;
    }
    
    currentRequestSize = remainingData;
    
    lastSysTimer = *SYSTIMER;
    receivePointer = requestBuffer;
    
    while(true) {
        regs.Bytes.B = currentClientConnection->tcpConnNumber;
        regs.Words.DE = (int)receivePointer;
        regs.Words.HL = remainingData;
        UnapiCall(&codeBlock, TCPIP_TCP_RCV, &regs, REGS_MAIN, REGS_MAIN);
        if(regs.Bytes.A != 0) {
            CloseClientConnection("connection lost");
            return false;
        }
        
        remainingData -= regs.Words.BC;
        if(remainingData == 0) {
            break;
        }
        receivePointer += regs.Words.BC;
        
        if(*SYSTIMER != lastSysTimer) {
            timeoutCounter++;
            if(timeoutCounter >= PARTIAL_REQUEST_INACTIVITY_TIMEOUT) {
                CloseClientConnection("data receive timeout");
                return false;
            }
            lastSysTimer = *SYSTIMER;
        }
    }

	return true;
}


void ProcessRequest()
{
    byte cmd;
    int i;
	unsigned short tid;
    request = (struct smb*)requestBuffer;

    if((currentRequestSize < SMB_HEADER_LENGTH + 3) ||
       (strncmpi((char*)(&(request->protocol)), "\xffSMB", 4) != 0)
      )
    {
        CloseClientConnection(strInvSmb);
        return;
    }

    //At this point we have a minimally structured SMB request.
    //Any further problem with the request will be notified
    //by sending an error response, not by closing the connection.

    InitializeResponse();

    if(currentRequestSize < 
            SMB_HEADER_LENGTH +
            (request->wordcount*2) +
            *((uint*)&requestBuffer[SMB_HEADER_LENGTH + (request->wordcount*2) + 1]) + 3) {
        SendErrorResponse(ERRSRV, ERRerror);
        return;
    }

    cmd = request->cmd;

    currentTree = null;
	tid = request->tid;
    if( !(cmd == SMB_COM_NEGOTIATE ||
          cmd == SMB_COM_SESSION_SETUP_ANDX ||
          cmd == SMB_COM_TREE_CONNECT ||
          cmd == SMB_COM_TREE_CONNECT_ANDX ||
          cmd == SMB_COM_LOGOFF_ANDX
          )) {
		
		if(tid != IPC_TID) {
			for(i=0; i < MAX_TREES_PER_CONN; i++) {
				currentTree = currentClientConnection->treeConnections[i];
				if(currentTree != null && request->tid == currentTree->TID) {
					break;
				}
			}

			if(currentTree == null) {
				SendErrorResponse(ERRSRV, ERRinvtid);
				return;
			}
		}
	}
    
    requestReadPointer = requestBuffer + SMB_HEADER_LENGTH;
    responseWritePointer = (byte*)response + SMB_HEADER_LENGTH;

    ProcessCommand(cmd);
}


bool IsAndxCommand(byte commandCode)
{
    byte* pointer = AndxCommands;
    while(true) {
        if(*pointer == 0) {
            return false;
        } else if(*pointer++ == commandCode) {
            return true;
        }
    }
}


void ProcessCommand(byte commandCode)
{
    byte* requestWordCountPointer = null;
    byte* responseWordCountPointer = null;
	byte* responseAndxOffsetPointer = null;
	byte* requestAndxOffsetPointer = null;
	byte* requestReadPointerBackup;
	bool isAndxCommand = false;
    int wordCountInBytes;
    int responseParameterWordsCount;
	byte nextCommandCode = 0;
	bool firstCommandInChanin = true;

	debug2("*** Command: %x\r\n", commandCode);

    while(true) {
		requestParametersWordsCount = *requestReadPointer;

		isAndxCommand = IsAndxCommand(commandCode);
		requestWordCountPointer = requestReadPointer++;
		responseWordCountPointer = responseWritePointer++;
        if(isAndxCommand) {
			debug2("%x is ANDX command", commandCode);
			nextCommandCode = requestWordCountPointer[1];
			debug2("next cmd: %x", nextCommandCode);
			*responseWritePointer = nextCommandCode;
            requestReadPointer += 4;
            responseWritePointer += 4;
			requestAndxOffsetPointer = &requestReadPointer[-2];
			responseAndxOffsetPointer = &responseWritePointer[-2];
			requestParametersWordsCount -= 2;
        } else {
			debug2("%x is NOT ANDX command", commandCode);
		}

		debug2("requestWordCountPointer: %x", requestWordCountPointer);
		debug2("responseWordCountPointer: %x", responseWordCountPointer);
		debug2("requestReadPointer: %x", requestReadPointer);
		debug2("responseWritePointer: %x", responseWritePointer);

        wordCountInBytes = requestParametersWordsCount * 2;
		debug2("wordCountInBytes: %i", wordCountInBytes);
        requestDataBytesCount = *((uint*)&requestReadPointer[wordCountInBytes]);
		debug2("requestDataBytesCount: %i", requestDataBytesCount);
        requestDataBytes = requestReadPointer + wordCountInBytes + 2;
		debug2("requestDataBytes: %x", requestDataBytes);

		requestReadPointerBackup = requestReadPointer;
        switch(commandCode) {
            case SMB_COM_NEGOTIATE:
                responseParameterWordsCount = ProcessNegotiateRequest();
                break;
			case SMB_COM_SESSION_SETUP_ANDX:
				responseParameterWordsCount = ProcessSetupAndxRequest();
				break;
			case SMB_COM_TREE_CONNECT_ANDX:
				responseParameterWordsCount = ProcessTreeConnectAndxRequest();
				break;
			case SMB_COM_TREE_DISCONNECT:
				responseParameterWordsCount = ProcessTreeDisconnectReques();
				break;
			case SMB_COM_OPEN_ANDX:
				responseParameterWordsCount = ProcessOpenAndxRequest();
				break;
			case SMB_COM_WRITE:
				//Deprecated, but still used by Windows
				responseParameterWordsCount = ProcessWriteRequest();
				break;
			case SMB_COM_READ_ANDX:
				responseParameterWordsCount = ProcessReadAndxRequest();
				break;
			case SMB_COM_CLOSE:
				responseParameterWordsCount = ProcessCloseRequest();
				break;
			case SMB_COM_TRANSACTION:
				responseParameterWordsCount = ProcessTransactionRequest();
				break;
			case SMB_COM_TRANSACTION2:
				responseParameterWordsCount = ProcessTransaction2Request();
				break;
			case SMB_COM_QUERY_INFORMATION:
				//Deprecated, but still used by Windows
				responseParameterWordsCount = ProcessQueryInformationRequest();
				break;
			case SMB_COM_FIND_CLOSE2:
				responseParameterWordsCount = ProcessFindClose2Request();
				break;
			case SMB_COM_QUERY_INFORMATION2:
				//Deprecated, but still used by Windows
				responseParameterWordsCount = ProcessQueryInformation2Request();
				break;
			case SMB_COM_CREATE_DIRECTORY:
				//Deprecated, but still used by Windows
				responseParameterWordsCount = ProcessCreateOrDeleteDirectoryRequest(false);
				break;
			case SMB_COM_DELETE_DIRECTORY:
				responseParameterWordsCount = ProcessCreateOrDeleteDirectoryRequest(true);
				break;
			case SMB_COM_RENAME:
				responseParameterWordsCount = ProcessRenameOrDeleteRequest(false);
				break;
			case SMB_COM_DELETE:
				responseParameterWordsCount = ProcessRenameOrDeleteRequest(true);
				break;
			case SMB_COM_SET_INFORMATION:
				//Deprecated, but still used by Windows
				responseParameterWordsCount =  ProcessSetInformationRequest();
				break;
			case SMB_COM_ECHO:
				//Deprecated, but still used by Windows
				responseParameterWordsCount =  ProcessEchoRequest();
				break;
			case SMB_COM_QUERY_INFORMATION_DISK:
				//Deprecated, but used by Samba
				responseParameterWordsCount = ProcessQueryInformationDiskRequest();
				break;

				//TODO: Implement more commands

            default:
                SetError(ERRDOS, ERRunsup);
                responseParameterWordsCount = -1;
        }
		requestReadPointer = requestReadPointerBackup;

		debug2("responseParameterWordsCount on response: %i", responseParameterWordsCount);
		debug2("responseWritePointer after response: %x", responseWritePointer);

        if(responseParameterWordsCount == -1) {
			if(isAndxCommand) {
				*responseWordCountPointer = 0;
				*((uint*)responseWordCountPointer) = 0;
				responseWritePointer -= 2; //-4 for the ANDX header, +2 for zero byte count
			} else {
				responseWritePointer += 2; //for zero byte count
			}
            break;
        }

		*responseWordCountPointer = isAndxCommand ? responseParameterWordsCount+2 : responseParameterWordsCount;

		if(!isAndxCommand || nextCommandCode == 0xFF) {
			break;
		}

        commandCode = nextCommandCode;
		*((uint*)responseAndxOffsetPointer) = (int)(responseWritePointer - (byte*)response);
		requestReadPointer = (byte*)request + *((uint*)requestAndxOffsetPointer);
    }

    SendResponse();
}

//Each "ProcessXXX" command must:
//- Read the request parameters and data block starting at requestReadPointer,
//  which will point to the first parameter after the word count byte, or after the ANDX block if present
//  (requestDataBytes, requestDataBytesCount and requestParametersWordsCount variables are available and can be modified)
//- Write the response parameters and data block (including the data byte count field)
//  starting at responseWritePointer (NOT including the response parameters word count nor any ANDX block)
//- Increase responseWritePointer by the number of bytes written
//- Return the size of the parameters block in words
//
//  In case of error:
//
//- Set the error class and code appropriately (SetError macro can be used)
//- Do NOT modify responseWritePointer
//- Return -1

int ProcessNegotiateRequest()
{
    unsigned short dialectIndex = 0xFFFF;
    int currentIndex = 0;
    int len;
	struct smb_negotiate_response* negotiate_response;
	t_Date date;
	byte serverIPlen;

    negotiate_response = (struct smb_negotiate_response*)responseWritePointer;
	debug2("negotiate_response: %x", negotiate_response);

    Clear(negotiate_response, sizeof(struct smb_negotiate_response));

    while(requestDataBytesCount > 0 && dialectIndex == 0xFFFF) {
        requestDataBytes++;	//skip buffer format id
        requestDataBytesCount--;
        if(StringIs(requestDataBytes, "NT LM 0.12")) {
            dialectIndex = currentIndex;
        } else {
            len = strlen(requestDataBytes);
            requestDataBytes += strlen(requestDataBytes) + 1;
            requestDataBytesCount -= len;
            currentIndex++;
        }
    }

	GetSystemDate(&date);
	SetFiletimeField(&date, (byte*)&(negotiate_response->systemtime_low), false);

	debug2("ProcessNegotiateRequest : dialectIndex: %i", dialectIndex);
	debug2("negotiate_response->dialect_index: %x", &(negotiate_response->dialect_index));
    negotiate_response->dialect_index = dialectIndex;
    negotiate_response->max_mpx_count = 255;
    negotiate_response->max_number_vcs = 255;
    negotiate_response->max_buffer_size = MAX_REQUEST_SIZE;
	//negotiate_response->max_raw_buffer_size = MAX_REQUEST_SIZE;
    //negotiate_response->session_key = ++lastUsedSessionKey;
    negotiate_response->capabilities = SMB_SERVER_CAPABILITIES;
	negotiate_response->server_timezone = timeZoneMinutes;

    responseWritePointer += sizeof(struct smb_negotiate_response);

	serverIPlen = strlen(serverIP);
	*((uint*)responseWritePointer) = serverIPlen + 2;
	responseWritePointer += 3;	//Skip byte count and empty domain name
	strcpy(responseWritePointer, serverIP);
	responseWritePointer += serverIPlen + 1;

	debug2("responseWritePointer (at end of ProcessNegotiateRequest): %x", responseWritePointer);

    return 0x11;
}


int ProcessSetupAndxRequest()
{
	struct smb_session_setup_request* setupRequest = (struct smb_session_setup_request*)requestReadPointer;
	int passwordsLen;
	char* account;
	char* os = "MSX-DOS";
	char* lanman="";
	int osLen = strlen(os);
	int lanmanLen = strlen(lanman);

	passwordsLen = setupRequest->ansi_password_length + setupRequest->unicode_password_length;
	account = requestDataBytes + passwordsLen;
	printf("Received login request from %s, account: %s\r\n", currentClientIp, account);

	*((uint*)responseWritePointer) = SMB_SETUP_GUEST;
	responseWritePointer += 2;

	*((uint*)responseWritePointer) = osLen + lanmanLen + 3;
	responseWritePointer += 2;

	strcpy(responseWritePointer, os);
	responseWritePointer += osLen+1;

	strcpy(responseWritePointer, lanman);
	responseWritePointer += lanmanLen + 1;

	*responseWritePointer++ = 0;	//primary domain

	currentClientConnection->connectionState = CLIENT_LOGGED_IN;
	lastUsedUid = (lastUsedUid+1) & 0x7FFF;
	response->uid = lastUsedUid;
	return 1;
}


int ProcessTreeConnectAndxRequest()
{
	struct smb_tree_connect_request* connectRequest = (struct smb_tree_connect_request*)requestReadPointer;
	bool mustDisconnectTid = (connectRequest->flags & TREE_CONNECT_ANDX_DISCONNECT_TID) == TREE_CONNECT_ANDX_DISCONNECT_TID;
	unsigned short tidToDisconnect = request->tid;
	char* path = &requestDataBytes[connectRequest->password_length];
	unsigned short newTid;

	printf("Received tree connect request from %s, path: %s\r\n", currentClientIp, path);
	
	if(StringEndsWith(path, "\\IPC$")) {
		response->tid = IPC_TID;

		((struct smb_tree_connect_response*)responseWritePointer)->optional_support = 0;	//TODO: Support exclusive search attrs?
		//((struct smb_tree_connect_response*)responseWritePointer)->max_access_rights = 0x1ff;
		//((struct smb_tree_connect_response*)responseWritePointer)->guest_max_access_rights = 0x1ff;
		responseWritePointer += sizeof(struct smb_tree_connect_response);

		*((unsigned short*)responseWritePointer) = 5;
		responseWritePointer += 2;

		strcpy(responseWritePointer, "IPC");
		responseWritePointer += 5;
		responseWritePointer[-1] = 0;

		return sizeof(struct smb_tree_connect_response)/2;
	} else {
		newTid = ConnectTid(path[strlen(path) - 1]);
		if(newTid == -1) {
			SetError(ERRDOS, ERRbadpath);
			return -1;
		} else if(newTid == -2) {
			SetError(ERRDOS, ERRnomem);
			return -1;
		}

		response->tid = newTid;

		responseWritePointer += 2;	//skip "optional support"
		*((unsigned short*)responseWritePointer) = 7;	//byte count
		responseWritePointer += 2;
		strcpy(responseWritePointer, "A:");
		responseWritePointer += 3;
		strcpy(responseWritePointer, "FAT");
		responseWritePointer += 4;

		if(mustDisconnectTid) {
			DisconnectTid(tidToDisconnect);
		}

		return 1;
	}
}


int ProcessTreeDisconnectReques()
{
	uint tid = request->tid;

	responseWritePointer += 2;	//byte count

	DisconnectTid(tid);
	request->tid = 0;
	return 0;

	/*if(tid == IPC_TID || DisconnectTid(tid)) {
		request->tid = 0;
		return 0;
	} else {
		SetError(ERRSRV, ERRinvtid);
		return -1;
	}*/
}


unsigned short ConnectTid(char driveLetter)
{
	//returns -1 on invalid drive, -2 on too many tids or out of memory, new tid otherwise
	byte i;
	t_TreeConnection** currentTreeConn = &(currentClientConnection->treeConnections[0]);
	t_TreeConnection* selectedTreeConn = null;
	char* drive = sharedDrives;
	bool driveOk = false;

	while(*drive != 0) {
		if(*drive++ == driveLetter) {
			driveOk = true;
			break;
		}
	}

	if(!driveOk) {
		return -1;
	}

	for(i = 0; i < MAX_TREES_PER_CONN; i++) {
		selectedTreeConn = *currentTreeConn;
		if(selectedTreeConn == null) {
			selectedTreeConn = malloc(sizeof(t_TreeConnection));
			if(selectedTreeConn == null) {
				return -2;
			}
			Clear(selectedTreeConn, sizeof(t_TreeConnection));
			break;
		} else {
			selectedTreeConn = null;
			currentTreeConn++;
		}
	}

	if(selectedTreeConn == null) {
		return -2;
	}

	lastUsedTid = (lastUsedTid+1) & 0x7FFF;
	selectedTreeConn->TID = lastUsedTid;
	selectedTreeConn->driveLetter = driveLetter;

	*currentTreeConn = selectedTreeConn;

	return lastUsedTid;
}


bool DisconnectTid(unsigned short tid)
{
	byte i;
	byte fh;
	t_TreeConnection** currentTreeConn = &(currentClientConnection->treeConnections[0]);
	t_TreeConnection* selectedTreeConn = null;
	byte fileHandle;
	t_FileInfoBlock* search;

	for(i = 0; i < MAX_TREES_PER_CONN; i++) {
		selectedTreeConn = *currentTreeConn;
		if(selectedTreeConn != null && selectedTreeConn->TID == tid) {
			for(fh = 0; fh < MAX_OPENS_PER_TREE; fh ++) {
				fileHandle = selectedTreeConn->openFileHandles[0];
				if(fileHandle != 0) {
					CloseFileHandle(fileHandle);
				}
				search = currentTree->searches[fh];
				if(search != null) {
					debug3("*** DisconnectTid, close search %i (%x)\r\n", i, search);
					mfree(search);
				}

			}
			mfree(selectedTreeConn);
			*currentTreeConn = null;
			return true;
		}
	}

	return false;
}


int ProcessOpenAndxRequest()
{
	//printf("Received file open request from %s, path: %s\r\n", currentClientIp, requestDataBytes);

	if(request->tid == IPC_TID) {
		return ProcessOpenAndxRequest_Ipc();
	} else {
		return ProcessOpenAndxRequest_File();
	}
}


int ProcessOpenAndxRequest_Ipc()
{
	struct smb_open_file_request* openRequest = (struct smb_open_file_request*)requestReadPointer;
	struct smb_open_file_response* openResponse;
	uint newFid;

	bool fillResponseFields;

	if(StringEndsWith(requestDataBytes, "\\srvsvc")) {
		newFid = FID_SRVSVC;
	} else if(StringEndsWith(requestDataBytes, "\\wkssvc")) {
		newFid = FID_WKSSVC;
	} else {
		SetError(ERRDOS, ERRbadfile);
		return -1;
	}

	fillResponseFields = ((openRequest->flags & REQ_ATTRIB) == REQ_ATTRIB);
	openResponse = (struct smb_open_file_response*)responseWritePointer;

	openResponse->fid = newFid;
	if(fillResponseFields) {
		openResponse->access_rights = SMB_DA_ACCESS_READ_WRITE;
		openResponse->resource_type = FileTypeMessageModePipe;
		openResponse->nm_pipe_status = 0x00FF | NmStatus_MessageReadMode | NmStatus_MessageOpenMode;
		openResponse->open_results = OpenResult_FileExistedAndWasOpened;
	}

	responseWritePointer += sizeof(struct smb_open_file_response) + 2;
	((uint*)responseWritePointer)[-1] = 0;

	return sizeof(struct smb_open_file_response)/2;
}


#define ACTION_FAIL 0
#define ACTION_OPEN 1
#define ACTION_OVERWRITE 2
#define ACTION_CREATE 3

int ProcessOpenAndxRequest_File()
{
	/*
	FileExistsOpts = 0 & CreateFile = 1 : If the file already exists, fail the request and do not create or open the given file. If it does not, create the given file.
	FileExistsOpts = 1 & CreateFile = 0 : If the file already exists, open it instead of creating a new file. If it does not, fail the request and do not create a new file.
	FileExistsOpts = 1 & CreateFile = 1 : If the file already exists, open it. If it does not, create the given file.
	FileExistsOpts = 2 & CreateFile = 0 : If the file already exists, open it and overwrite it. If it does not, fail the request.
	FileExistsOpts = 2 & CreateFile = 1 : If the file already exists, open it and overwrite it. If it does not, create the given file.
	Others: ERRDOS/ERRbadaccess
	*/

	struct smb_open_file_request* openRequest = (struct smb_open_file_request*)requestReadPointer;
	struct smb_open_file_response* openResponse = (struct smb_open_file_response*)responseWritePointer;
	bool populateResponse = (openRequest->flags & REQ_ATTRIB) != 0;
	byte accessMask = openRequest->access_mode & 3;
	bool allowReading;
	bool allowWriting;
	byte fileExistsOpts = openRequest->open_mode & 0x13;
	char* fileName = requestDataBytes - 2;
	byte* newFileHandlePointer = null;
	byte fileHandle = 0xFF;
	byte i;
	byte error;
	byte actionIfFileExists;
	byte actionIfFileNotExists;
	bool fileExists;
	t_Date date;
	//TODO: Obtain and apply creation time

	if(!GetCurrentTree()) {
		return -1;
	}

	if(accessMask == 3) {
		accessMask = 0;	//open for exe = open for read
	}
	allowReading = (accessMask != 1);
	allowWriting = (accessMask != 0);

	if(fileName[2] == 0) {
		openResponse->fid = FID_DIRECTORY;
		openResponse->file_attributes = tempFIB->attributes;
		openResponse->access_rights = accessMask;
		responseWritePointer += sizeof(struct smb_open_file_response) + 2;	//+2 for zero byte count
		return sizeof(struct smb_open_file_response) / 2;
	}

	newFileHandlePointer = &(currentTreeConnection->openFileHandles[0]);
	fileHandle = 0;
	for(i = 0; i < MAX_OPENS_PER_TREE; i ++) {
		if(*newFileHandlePointer == 0) {
			fileHandle = 0;
			break;
		}
		newFileHandlePointer++;
	}

	if(fileHandle == 0xFF) {
		SetError(ERRDOS, ERRnofids);
		return -1;
	}

	if(fileExistsOpts == 0x10) {
		//If the file already exists, fail the request and do not create or open the given file. If it does not, create the given file.
		actionIfFileExists = ACTION_FAIL;
		actionIfFileNotExists = ACTION_CREATE;
	} else if(fileExistsOpts == 0x01) {
		//If the file already exists, open it instead of creating a new file. If it does not, fail the request and do not create a new file.
		actionIfFileExists = ACTION_OPEN;
		actionIfFileNotExists = ACTION_FAIL;
	} else if(fileExistsOpts == 0x11) {
		//If the file already exists, open it. If it does not, create the given file.
		actionIfFileExists = ACTION_OPEN;
		actionIfFileNotExists = ACTION_CREATE;
	} else if(fileExistsOpts == 0x02) {
		//If the file already exists, open it and overwrite it. If it does not, fail the request.
		actionIfFileExists = ACTION_OVERWRITE;
		actionIfFileNotExists = ACTION_FAIL;
	} else if(fileExistsOpts == 0x12) {
		//If the file already exists, open it and overwrite it. If it does not, create the given file.
		actionIfFileExists = ACTION_OVERWRITE;
		actionIfFileNotExists = ACTION_CREATE;
	} else {
		SetError(ERRDOS, ERRbadaccess);
		return -1;
	}
	
	fileName[0] = currentTreeConnection->driveLetter;
	fileName[1] = ':';

	regs.Words.DE = (int)fileName;
	regs.Bytes.B = *(byte*)&(openRequest->search_attributes) & 0x7F;
	regs.Words.IX = (int)tempFIB;
	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);

	//printf("*** op: %x, file: %s, err: %x\r\n", fileExistsOpts, fileName, regs.Bytes.A);

	fileExists = (error = regs.Bytes.A) == 0;
	if(fileExists && actionIfFileExists == ACTION_FAIL) {
		SetSmbErrorFromMsxdosError(_FILEX);
		return -1;
	} else if(error == _NOFIL && actionIfFileNotExists == ACTION_FAIL) {
		SetSmbErrorFromMsxdosError(_NOFIL);
		return -1;
	} else if(error != 0 && error != _NOFIL) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}
	
	if(((fileExists && actionIfFileExists == ACTION_OVERWRITE) || (!fileExists && actionIfFileNotExists == ACTION_CREATE))
		&& readOnlyServer) {
		SetError(ERRHRD, ERRnowrite);
		return -1;
	}

	if((fileExists && actionIfFileExists == ACTION_OVERWRITE) || !fileExists) {
		regs.Bytes.B = *(byte*)&(openRequest->file_attributes) & 0x7F;
		DosCall(_FNEW, &regs, REGS_ALL, REGS_AF);
		if((error = regs.Bytes.A) != 0) {
			SetSmbErrorFromMsxdosError(error);
			return -1;
		}
	}

	//At this point we are sure that the file exists

	regs.Bytes.A = (allowReading ? 0 : 2) | (allowWriting ? 0 : 1);
	regs.Words.DE = (int)fileName;
	DosCall(_OPEN, &regs, REGS_ALL, REGS_MAIN);
	error = regs.Bytes.A;
	if(error == _DIRX) {
		//MSX-DOS can't open directories, 
		//but since no r/w operations can be done on direcrtories anyway,
		//we just pretend having opened it and provide a fake file handle.
		fileHandle = FID_DIRECTORY;
	} else if(error != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	} else {
		fileHandle = regs.Bytes.B;
		*newFileHandlePointer = fileHandle;
	}

	openResponse->fid = fileHandle;
    openResponse->file_attributes = tempFIB->attributes;
	FillDateFromFib(&date, tempFIB);
	SetUtimeField(&date, (unsigned long*)&(openResponse->last_write_time));
	openResponse->file_data_size = tempFIB->fileSize;
	openResponse->access_rights = accessMask;

	if(fileExists) {
		if(actionIfFileExists == ACTION_OVERWRITE) {
			openResponse->open_results = 3;
		} else {
			openResponse->open_results = 1;
		}
	} else {
		openResponse->open_results = 2;
	}

	/*if((openRequest->flags & 6) != 0) {
		openResponse->open_results |= 0x8000;
	}*/

	responseWritePointer += sizeof(struct smb_open_file_response) + 2;	//+2 for zero byte count
	return sizeof(struct smb_open_file_response) / 2;
}


int ProcessWriteRequest()
{
	if(request->tid == IPC_TID) {
		return ProcessWriteRequest_Ipc();
	} else {
		return ProcessWriteRequest_File();
	}
}


int ProcessWriteRequest_Ipc()
{
	rpcconn_common_hdr_t* rpcRequest = (rpcconn_common_hdr_t*)(requestDataBytes + 3);
	unsigned short bytesToWrite = ((struct smb_write_file_request*)requestReadPointer)->data_length;
	unsigned short requestFid = ((struct smb_write_file_request*)requestReadPointer)->fid;

	currentClientConnection->rpcCallId = rpcRequest->call_id;
	//TODO: Check RPC header fields (version, flags, data representation)

	if((requestFid == FID_SRVSVC || requestFid == FID_WKSSVC) && rpcRequest->PTYPE == rpc_bind) {
		ProcessRpcBindRequest(requestFid);
	} else {
		SetError(ERRDOS, ERRgeneral);
		return -1;
	}

	((struct smb_write_file_response*)responseWritePointer)->count = bytesToWrite;
	responseWritePointer += sizeof(struct smb_write_file_response) + 2;
	((uint*)responseWritePointer)[-1] = 0;
	return sizeof(struct smb_write_file_response)/2;
}


void ProcessRpcBindRequest(unsigned short fid)
{
	rpcconn_bind_hdr_t* bindRequest = (rpcconn_bind_hdr_t*)(requestDataBytes + 3);
	p_cont_elem_t* currentContextItem;
	p_syntax_id_t* currentTransferSyntax;
	int numContextItems, numTransferItems;
	int contextItemIndex, transferItemIndex;
	bool interfaceOk;

	currentClientConnection->rpcPendingState = RPC_BIND_ACK_PENDING;
	currentClientConnection->bindRequestAcceptedContextIndex = NO_CTX_ACCEPTED;

	numContextItems = bindRequest->p_context_elem.n_context_elem;
	currentClientConnection->bindRequestContextItemsCount = numContextItems;
	currentContextItem = &bindRequest->p_context_elem.p_cont_elem;

	debug2("*** call id: %i\r\n", currentClientConnection->rpcCallId);
	debug2("*** %i context items\r\n", numContextItems);

	for(contextItemIndex = 0; contextItemIndex < numContextItems; contextItemIndex++) {
		debug2("*** contextItemIndex = %i\r\n", contextItemIndex);
		debug4("*** context: id = %i, num trans items: %i, version: %i\r\n",
			currentContextItem->p_cont_id,
			currentContextItem->n_transfer_syn,
			currentContextItem->abstract_syntax.if_version);
		if(fid == FID_SRVSVC) {
			interfaceOk = GuidsAreEqual((byte*)(&(currentContextItem->abstract_syntax.if_uuid)), (byte*)GUID_SRVSVC);
		} else {
			interfaceOk = GuidsAreEqual((byte*)(&(currentContextItem->abstract_syntax.if_uuid)), (byte*)GUID_WKSSVC);
		}
		//TODO: Check interface version as well

		if(interfaceOk) {
			debug("*** interface ok\r\n");
			currentTransferSyntax = &(currentContextItem->transfer_syntaxes);
			numTransferItems = currentContextItem->n_transfer_syn;
			debug2("*** num trans items: %i\r\n", numTransferItems);
			for(transferItemIndex = 0; transferItemIndex < numTransferItems; transferItemIndex++) {
				if(GuidsAreEqual((byte*)&(currentTransferSyntax->if_uuid), (byte*)GUID_NDR)) {
					debug2("*** trans syntax ok, contextItemIndex: %i\r\n", contextItemIndex);
					currentClientConnection->bindRequestAcceptedContextIndex = contextItemIndex;
				}
				//TODO: Check transfer syntax version as well
				currentTransferSyntax++;
			}
		}
		currentContextItem++;
	}
}


int ProcessWriteRequest_File()
{
	byte* fileHandlePointer;
	byte fileHandle;
	uint length;
	ulong offset;
	byte error;

	if(!GetCurrentTree()) {
		return -1;
	}

	if(IsReadOnlyServer()) {
		return -1;
	}

	fileHandle = *requestReadPointer;
	fileHandlePointer = GetFileHandlePointer(fileHandle);
	if(fileHandlePointer == null) {
		return -1;
	}

	length = *(uint*)(&requestReadPointer[2]);
	offset = *(ulong*)(&requestReadPointer[4]);

	regs.Bytes.B = fileHandle;
	regs.Bytes.A = 0;
	regs.UWords.HL = (uint)offset;
	regs.UWords.DE = ((uint*)&(offset))[1];
	DosCall(_SEEK, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	regs.Bytes.B = fileHandle;
	regs.UWords.DE = (uint)requestDataBytes + 3;
	regs.UWords.HL = length;
	DosCall(_WRITE, &regs, REGS_MAIN, REGS_MAIN);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	*(ushort*)responseWritePointer = regs.UWords.HL;
	responseWritePointer += 4;	//include zero byte count
	return 1;
}


int ProcessReadAndxRequest()
{
	if(request->tid == IPC_TID) {
		return ProcessReadAndxRequest_Ipc();
	} else {
		return ProcessReadAndxRequest_File();
	}
}


int ProcessReadAndxRequest_Ipc()
{
	struct smb_read_file_andx_request* readRequest = (struct smb_read_file_andx_request*)requestReadPointer;
	struct smb_read_file_andx_response* readResponse = (struct smb_read_file_andx_response*)responseWritePointer;
	unsigned short requestFid = readRequest->fid;
	int generatedByteCount;

	if((requestFid == FID_SRVSVC || requestFid == FID_WKSSVC) && currentClientConnection->rpcPendingState == RPC_BIND_ACK_PENDING) {
		generatedByteCount = ProcessReadAndxRequest_SendBindAck(readRequest->fid);
	} else {
		SetError(ERRDOS, ERRgeneral);
		return -1;
	}

	readResponse->data_length = generatedByteCount;
	
	readResponse->data_offset = 59;	//Offset from SMB header to start of RPC packet
	
	return sizeof(struct smb_read_file_andx_response)/2;
}


int ProcessReadAndxRequest_SendBindAck(unsigned short fid)
{
	int generatedByteCount = sizeof(rpcconn_bind_ack_hdr_t) - sizeof(p_result_t);
	int numResults = currentClientConnection->bindRequestContextItemsCount;
	rpcconn_bind_ack_hdr_t* bindAckPdu;
	unsigned short* byteCountPointer;
	p_result_t* currentResult;
	int i;

	responseWritePointer += sizeof(struct smb_read_file_andx_response) + 2;
	byteCountPointer = &(((unsigned short*)responseWritePointer)[-1]);
	bindAckPdu = (rpcconn_bind_ack_hdr_t*)responseWritePointer;

	bindAckPdu->rpc_vers = 5;
	bindAckPdu->PTYPE = rpc_bind_ack;
	bindAckPdu->pfc_flags = 3; //first and last fragment
	bindAckPdu->packed_drep[0] = 0x10;	//little endian, ASCII, IEEE
	bindAckPdu->call_id = currentClientConnection->rpcCallId;
	bindAckPdu->max_xmit_frag = 1024;
	bindAckPdu->max_recv_frag = 1024;
	bindAckPdu->assoc_group_id = 1;
	bindAckPdu->sec_addr.length = 13;
	strcpy(bindAckPdu->sec_addr.port_spec, fid == FID_SRVSVC ? "\\PIPE\\srvsvc" : "\\PIPE\\wkssvc");

	bindAckPdu->p_result_list.n_results = numResults;
	responseWritePointer = (byte*)&(bindAckPdu->p_result_list.p_results);
	currentResult = (p_result_t*)&(bindAckPdu->p_result_list.p_results);

	for(i = 0; i < numResults; i++) {
		if(i == currentClientConnection->bindRequestAcceptedContextIndex) {
			memcpy((byte*)&(currentResult->transfer_syntax.if_uuid), GUID_NDR, GUID_LEN);
			currentResult->transfer_syntax.if_version = 2;
		} else {
			currentResult->result = provider_rejection;
			currentResult->reason = proposed_transfer_syntaxes_not_supported;
		}
		responseWritePointer += sizeof(p_result_t);
		generatedByteCount += sizeof(p_result_t);

		currentResult++;
	}

	currentClientConnection->rpcPendingState = RPC_NONE;

	bindAckPdu->frag_length = generatedByteCount;
	*byteCountPointer = generatedByteCount;
	return generatedByteCount;
}


int ProcessReadAndxRequest_File()
{
	byte* fileHandlePointer;
	byte fileHandle;
	uint length;
	byte error;
	struct smb_read_file_andx_request* readRequest = (struct smb_read_file_andx_request*)requestReadPointer;
	struct smb_read_file_andx_response* readResponse = (struct smb_read_file_andx_response*)responseWritePointer;
	byte* destination = responseWritePointer + sizeof(struct smb_read_file_andx_response) + 2; //+2 for byte count

	if(!GetCurrentTree()) {
		return -1;
	}

	fileHandle = (byte)readRequest->fid;
	fileHandlePointer = GetFileHandlePointer(fileHandle);
	if(fileHandlePointer == null) {
		return -1;
	}

	length = readRequest->max_count;
	if(length > 960) {
		length = 960;
	}

	regs.Bytes.B = fileHandle;
	regs.Bytes.A = 0;
	regs.UWords.HL = (uint)readRequest->offset;
	regs.UWords.DE = ((uint*)&(readRequest->offset))[1];
	DosCall(_SEEK, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	regs.Bytes.B = fileHandle;
	regs.Words.DE = (int)destination;
	regs.Words.HL = length;
	DosCall(_READ, &regs, REGS_MAIN, REGS_MAIN);
	length = regs.Words.HL;
	error = regs.Bytes.A;
	if(error != 0 && error != _EOF) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}
	length = regs.UWords.HL;

	readResponse->data_compaction_mode = 0xFFFF;
	readResponse->data_length = length;
	if(length != 0) {
		readResponse->data_offset = SMB_HEADER_LENGTH + sizeof(struct smb_read_file_andx_response) + 5 + 2;	//+wordcount, andx header, and byte count
	}

	responseWritePointer = destination + length;

	*(uint*)(destination-2) = length;
	return sizeof(struct smb_read_file_andx_response)/2;
}


int ProcessCloseRequest()
{
	int generatedWords;

	if(request->tid == IPC_TID) {
		generatedWords = ProcessCloseRequest_Ipc();
	} else {
		generatedWords = ProcessCloseRequest_File();
	}

	if(generatedWords != -1) {
		*((uint*)responseWritePointer) = 0;	//Byte count
		responseWritePointer += 2;
	}

	return generatedWords;
}


int ProcessCloseRequest_Ipc()
{
	unsigned short fid = ((struct smb_close_request*)requestReadPointer)->fid;

	if(!(fid == FID_SRVSVC || fid == FID_WKSSVC)) {
		SetError(ERRSRV, ERRbadfid);
		return -1;
	}

	currentClientConnection->rpcPendingState = RPC_NONE;

	return 0;
}


int ProcessCloseRequest_File()
{
	byte* fileHandlePointer;
	byte fileHandle;
	byte error;

	if(!GetCurrentTree()) {
		return -1;
	}

	fileHandle = *requestReadPointer;
	if(fileHandle == FID_DIRECTORY) {
		return 0;
	}
	fileHandlePointer = GetFileHandlePointer(fileHandle);
	if(fileHandlePointer == null) {
		return -1;
	}

	regs.Bytes.B = fileHandle;
	DosCall(_CLOSE, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	*fileHandlePointer = 0;
	responseWritePointer += 2; //zero byte count
	return 0;
}


int ProcessTransactionRequest()
{
	int generatedData;
	rpcconn_request_hdr_t* rpcRequest;
	struct smb_trans_response* transResponse = (struct smb_trans_response*)responseWritePointer;
	struct smb_trans_request* transRequest = (struct smb_trans_request*)requestReadPointer;
	uint opNum;
	ushort subCommand;

	if(request->tid != IPC_TID) {
		SetError(ERRSRV, ERRinvtid);
		return -1;
	}

	subCommand = transRequest->setup;
	if(subCommand == TRANS_WAIT_NMPIPE) {
		responseWritePointer += 2;	//zero byte count
		return 0;
	} else if(subCommand != TRANS_TRANSACT_NMPIPE) {
		SetError(ERRDOS, ERRgeneral);
		return -1;
	}

	rpcRequest = (rpcconn_request_hdr_t*)&((byte*)request)[((struct smb_trans_request*)requestReadPointer)->data_offset];
	opNum = rpcRequest->opnum;

	if(opNum == NetShareEnum) {
		generatedData = ProcessTrans_NetShareEnum(rpcRequest);
	} else if(opNum == NetSrvGetInfo) {
		generatedData = ProcessTrans_NetSrvGetInfo(rpcRequest);
	} else {
		SetError(ERRDOS, ERRgeneral);
		return -1;
	}

	transResponse->total_data_count = generatedData;
	transResponse->data_count = generatedData;
	transResponse->data_offset = sizeof(struct smb_header) + sizeof(struct smb_trans_response) + 1 + 2; //+1 for word count, +3 for byte count

	return sizeof(struct smb_trans_response) / 2;
}


int ProcessTrans_NetShareEnum(rpcconn_request_hdr_t* rpcRequest) 
{
	int generatedByteCount;
	rpcconn_response_hdr_t* responsePdu;
	unsigned short* byteCountPointer;
	byte numDrives = strlen(sharedDrives);
	byte i;

	responseWritePointer += sizeof(struct smb_trans_response) + 2;	//+2 for byte count
	byteCountPointer = &(((unsigned short*)responseWritePointer)[-1]);
	responseWritePointer++;	//padding
	responsePdu = (rpcconn_response_hdr_t*)responseWritePointer;

	responsePdu->rpc_vers = 5;
	responsePdu->PTYPE = rpc_response;
	responsePdu->pfc_flags = 3; //first and last fragment
	responsePdu->packed_drep[0] = 0x10;	//little endian, ASCII, IEEE
	responsePdu->call_id = rpcRequest->call_id;
	responsePdu->alloc_hint = 336;	//???

	responseWritePointer += sizeof(rpcconn_response_hdr_t);

	InsertLongInResponse(1);	//level
	InsertLongInResponse(1); 	//CTR ???
	InsertReferentIdInResponse();
	InsertLongInResponse(numDrives); 	//Array count
	InsertReferentIdInResponse();
	InsertLongInResponse(numDrives); 	//Max count (whole array)

	for(i = 0; i < numDrives; i++) {
		InsertReferentIdInResponse();	//refid of name
		InsertLongInResponse(0); 	//type = disk
		InsertReferentIdInResponse();	//refid of comment
	}

	for(i = 0; i < numDrives; i++) {
		//Share name
		responseWritePointer[0] = 2;	//Max count
		responseWritePointer[8] = 2;	//Actual count
		responseWritePointer[12] = sharedDrives[i];

		//Comment (empty)
		responseWritePointer[16] = 1;	//Max count
		responseWritePointer[24] = 1;	//Actual count

		responseWritePointer += 32;

		//Less optimized but clearer version:
		/*
		InsertLongInResponse(3); 	//Max count (in unicode chars)
		responseWritePointer += 4; 	//offset
		InsertLongInResponse(3); 	//Actual count (in unicode chars)
		*responseWritePointer++ = sharedDrives[i];
		responseWritePointer++;
		*responseWritePointer++ = ':';
		responseWritePointer += 5;	//upper half and letter, plus unicode null, plus 2 bytes for alignment

		//Comment
		InsertLongInResponse(1); 	//Max count (in unicode chars), comment
		responseWritePointer += 4; 	//offset
		InsertLongInResponse(1); 	//Actual count (in unicode chars)
		responseWritePointer += 4;	//upper half and letter, plus unicode null, plus 2 bytes for alignment
		*/
	}

	InsertLongInResponse(numDrives); 	//total entries
	responseWritePointer += 8;	//resume handle, error

	generatedByteCount = (int)(responseWritePointer-&((byte*)responsePdu));
	*byteCountPointer = generatedByteCount + 1; //+1 for the padding byte
	responsePdu->frag_length = generatedByteCount;
	return generatedByteCount;
}

#if true

int ProcessTrans_NetSrvGetInfo(rpcconn_request_hdr_t* rpcRequest)
{
	//TODO: Improve this method, or remove it (doens't seem to be necessary after all)

	int generatedByteCount;
	rpcconn_response_hdr_t* responsePdu;
	unsigned short* byteCountPointer;
	byte numDrives = strlen(sharedDrives);
	byte len = strlen(serverIP)+1;

	responseWritePointer += sizeof(struct smb_trans_response) + 2;	//+2 for byte count
	byteCountPointer = &(((unsigned short*)responseWritePointer)[-1]) - 1;
	responseWritePointer++;	//padding
	responsePdu = (rpcconn_response_hdr_t*)responseWritePointer;

	responsePdu->rpc_vers = 5;
	responsePdu->PTYPE = rpc_response;
	responsePdu->pfc_flags = 3; //first and last fragment
	responsePdu->packed_drep[0] = 0x10;	//little endian, ASCII, IEEE
	responsePdu->call_id = rpcRequest->call_id;
	responsePdu->alloc_hint = 92;	//???

	responseWritePointer += sizeof(rpcconn_response_hdr_t);

	InsertLongInResponse(0x65);	//Info   (???)
	InsertReferentIdInResponse();
	InsertLongInResponse(300);	//Platform, MS-DOS
	InsertReferentIdInResponse();	//Server name
	InsertLongInResponse(1);	//Version major
	responseWritePointer += 4;	//Version minor = 0;
	InsertLongInResponse(3);	//Server type
	InsertReferentIdInResponse();	//Comment
	InsertLongInResponse(len);	//Server name, max count
	responseWritePointer += 4;	//Server name, offset
	InsertLongInResponse(len);	//Server name, actual count
	responseWritePointer = InsertAsUnicode(serverIP, responseWritePointer);

	len = (len*2) & 3;
	if(len != 0) {
		responseWritePointer += 4 - len;		//align to 4 byte boundary
	}

	InsertLongInResponse(1);	//Comment, max count
	responseWritePointer += 4;	//Comment, offset
	InsertLongInResponse(1);	//Comment, actual count
	responseWritePointer += 8;	//empty comment, padding, and error

	generatedByteCount = (int)(responseWritePointer-&((byte*)responsePdu));
	*byteCountPointer = generatedByteCount + 1; //+1 for the padding byte
	responsePdu->frag_length = generatedByteCount;
	return generatedByteCount;
}

#endif


int ProcessTransaction2Request()
{
	byte sizeofTransHeaderExceptSetup = sizeof(struct smb_trans_response) - sizeof(ushort);
	ushort subCommand;
	ushort byteCount;
	ushort* byteCountPointer;
	bool subcommandOk;

	trans2Request = (struct smb_trans_request*)requestReadPointer;
	trans2Response = (struct smb_trans_response*)responseWritePointer;
	trans2RequestParameters = ((byte*)request) + trans2Request->parameter_offset;
	trans2RequestData = ((byte*)request) + trans2Request->data_offset;

	subCommand = trans2Request->setup;
	responseWritePointer += sizeofTransHeaderExceptSetup; // - for the "setup" field

	switch(subCommand) {
		case TRANS2_QUERY_FS_INFORMATION:
			subcommandOk = ProcessTrans2_QueryFsInformation();
			break;
		case TRANS2_FIND_FIRST2:
			subcommandOk = ProcessTrans2_Find2(true);
			break;
		case TRANS2_FIND_NEXT2:
			subcommandOk = ProcessTrans2_Find2(false);
			break;
		case TRANS2_QUERY_PATH_INFORMATION:
			subcommandOk = ProcessTrans2_QueryPathInformation();
			break;
#if 0
		case TRANS2_QUERY_FILE_INFORMATION:	//used by Samba
			subcommandOk = ProcessTrans2_QueryFileInformation();
#endif
		//TODO: Implement more subcommands

		default:
			subcommandOk = false;
			SetError(ERRDOS, ERRgeneral);
			break;
	}

	if(!subcommandOk) {
		return -1;
	}

	trans2Response->total_parameter_count = trans2Response->parameter_count;
	trans2Response->total_data_count = trans2Response->data_count;
	byteCount = trans2Response->parameter_count + trans2Response->data_count;
	byteCountPointer = (ushort*)&((byte*)trans2Response)[sizeofTransHeaderExceptSetup + (trans2Response->setup_count*2)];
	*byteCountPointer = byteCount;
	trans2Response->parameter_offset = sizeof(struct smb_header) + sizeofTransHeaderExceptSetup + (trans2Response->setup_count*2) + sizeof(ushort);
	trans2Response->data_offset = trans2Response->parameter_offset + trans2Response->parameter_count;

	return (sizeofTransHeaderExceptSetup/2) + trans2Response->setup_count;
}

// ProcessTrans2_* functions must:
//
// - Write the following at responseWritePointer:
//    - The setup bytes
//    - Then, two random bytes (the response byte count, will be set by the caller)
//    - Then, the the trans2 response parameters
//    - Then, the trans2 response data
// - Increase responseWritePointerby the total amount of bytes written
// - Set the setup_count, data_count and parameter_count fields on transResponse
//
// Additional global variables available: trans2Request, trans2Response, trans2RequestParameters, trans2RequestData

bool ProcessTrans2_QueryFsInformation()
{
	ushort informationLevel = *((ushort*)trans2RequestParameters);

	if(!GetCurrentTree()) {
		return false;
	}

	responseWritePointer += 2; //skip byte count

	switch(informationLevel) {
		case SMB_QUERY_FS_ATTRIBUTE_INFO:
			return ProcessTrans2_QueryFsInformation_FsAttributeInfo();

		case SMB_INFO_VOLUME:
			return ProcessTrans2_QueryFsInformation_InfoVolume();
		
		case SMB_INFO_ALLOCATION:
			return ProcessTrans2_QueryFsInformation_InfoAllocation();

		//TODO: Support more information levels
			
	}

	SetError(ERRDOS, ERRgeneral);
	return false;
}


bool ProcessTrans2_QueryFsInformation_FsAttributeInfo()
{
	responseWritePointer += 4;	//FileSystemAttributes
	InsertLongInResponse(12);	//Maximum size of file name (not sure if this is correct)
	InsertLongInResponse(8);	//Length of filesystem name field
	responseWritePointer[0] = 'F';
	responseWritePointer[2] = 'A';
	responseWritePointer[4] = 'T';
	responseWritePointer += 8;

	trans2Response->data_count = sizeof(long) + sizeof(long) + sizeof(long) + 8;
	return true;
}


bool ProcessTrans2_QueryFsInformation_InfoVolume()
{
	char* drive = "X:";
	byte len;

	*drive = currentTreeConnection->driveLetter;
	regs.Words.DE = (int)drive;
	regs.Bytes.B = SMB_FILE_ATTR_VOLUME;
	regs.Words.IX = (int)tempFIB;
	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
	if(regs.Bytes.A == _NOFIL) {
		tempFIB->filename[0] = '\0';
	} else if(regs.Bytes.A != 0) {
		SetSmbErrorFromMsxdosError(regs.Bytes.A);
		return false;
	}

	responseWritePointer += 4; //skip volume serial number
	len = strlen(tempFIB->filename) + 1;
	*responseWritePointer++ = len;
	strcpy(responseWritePointer, tempFIB->filename);
	responseWritePointer += len;

	trans2Response->data_count = sizeof(long) + 1 + len;
	return true;
}


bool ProcessTrans2_QueryFsInformation_InfoAllocation()
{
	struct smb_info_allocation* allocationInfo = (struct smb_info_allocation*)responseWritePointer;

	regs.Bytes.E = currentTreeConnection->driveLetter - 'A' + 1;
	DosCall(_ALLOC, &regs, REGS_MAIN, REGS_MAIN);

	allocationInfo->sector_per_unit = regs.Bytes.A;
	allocationInfo->units_total = regs.UWords.DE;
	allocationInfo->units_avail = regs.UWords.HL;
	allocationInfo->sectorsize = MSXDOS_SECTOR_SIZE;

	responseWritePointer += sizeof(struct smb_info_allocation);
	trans2Response->data_count = sizeof(struct smb_info_allocation);
	return true;
}


bool ProcessTrans2_QueryPathInformation()
{
	//NOTE: Assuming that information level is QUERY_FILE_BASIC_INFO
	char* fileName = trans2RequestParameters + sizeof(ushort) + sizeof(ulong) - 2;
	struct smb_file_basic_info* info;
	byte error;
	t_Date date;

	if(!GetCurrentTree()) {
		return false;
	}

	responseWritePointer += 2;	//response byte count
	info = (struct smb_file_basic_info*)responseWritePointer;
	if(fileName[2] == '\0') {
		info->attributes = SMB_FILE_ATTR_DIRECTORY;
	} else {
		fileName[0] = currentTreeConnection->driveLetter;
		fileName[1] = ':';
		regs.Words.DE = (int)fileName;
		regs.Bytes.B = SMB_FILE_ATTR_DIRECTORY;
		regs.Words.IX = (int)tempFIB;
		DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
		if((error = regs.Bytes.A) != 0) {
			SetSmbErrorFromMsxdosError(error);
			return false;
		}

		FillDateFromFib(&date, tempFIB);
		SetFiletimeField(&date, (byte*)&(info->last_write_time), true);
		copy((void*)&(info->change_time), (void*)&(info->last_write_time), 8);
		//*(ulong*)&(info->change_time) = *(ulong*)&(info->last_write_time);
		info->attributes = tempFIB->attributes;
	}
	responseWritePointer += sizeof(struct smb_file_basic_info);
	trans2Response->data_count = sizeof(struct smb_file_basic_info);
	return true;
}


#if 0

bool ProcessTrans2_QueryFileInformation()
{
	//NOTE: Assuming that information level is QUERY_FILE_ALL_INFO
	byte* fhPointer = GetFileHandlePointer(*trans2RequestParameters);
	byte* fileHandle
	if(fhPointer == null) {
		return false;
	}
	fileHandle = *fhPointer;

	//...how to extract the file name from the file handle?
}

#endif


bool ProcessTrans2_Find2(bool isFirst)
{
	//TODO: split this monstruous method in smaller submethods

	struct smb_findfirst_request* findFirstRequest;
	struct smb_findfirst_response* findFirstResponse;
	struct smb_findnext_request* findNextRequest;
	struct smb_findnext_response* findNextResponse;
	struct smb_file_directory_info* currentDirInfo = null;
	struct smb_both_file_directory_info* currentDirInfoWithShortName;
	struct smb_info_standard* currentStandardDirInfo;
	byte* firstDirInfoPointer;
	byte dosFunctionCall;
	t_FileInfoBlock* fib;
	t_FileInfoBlock** fibPointer;
	int i;
	bool persistentSearch = true;
	bool closeIfEnd;
	ushort maxCount;
	ushort count = 0;
	ushort infolevel;
	ushort sid = 0xFF;
	byte error;
	bool endReached = false;
	t_Date date;
	byte len;
	char* pointer;
	char ch;
	bool returnResumeKey;
	uint lastNameOffset = 0;

	if(!GetCurrentTree()) {
		return false;
	}

	CalculateBytesPerCluster();

	responseWritePointer += 2;  //byte count

	if(isFirst) {
		findFirstRequest = (struct smb_findfirst_request*)trans2RequestParameters;
		persistentSearch = ((findFirstRequest->flags & SMB_CLOSE_AFTER_FIRST) == 0);
		returnResumeKey = ((findFirstRequest->flags & SMB_REQUIRE_RESUME_KEY) == 0);
		debug2("*** persistent: %i\r\n", persistentSearch);
		if(persistentSearch) {
			fibPointer = currentTreeConnection->searches;
			for(i = 0; i < MAX_SEARCHES_PER_TREE; i++) {
				fib = *fibPointer;
				if(fib == null) {
					fib = malloc(sizeof(t_FileInfoBlock));
					if(fib == null) {
						debug("*** find: out of memory\r\n");
						SetError(ERRDOS, ERRnomem);
						return false;
					}
					*fibPointer = fib;
					sid = i;
					debug2("*** assigned sid: %i\r\n", sid);
					break;
				}
				fibPointer += 1;
			}
			if(sid == 0xFF) {
				debug("*** find: no free SIDs\r\n");
				SetError(ERRDOS, ERRnomem);
				return false;
			}
		} else {
			fib = tempFIB;
		}

		closeIfEnd = ((findFirstRequest->flags & SMB_CLOSE_IF_END) != 0);
		debug2("*** closeifend: %i\r\n", closeIfEnd);
		maxCount = findFirstRequest->search_count;
		debug2("*** maxcount: %i\r\n", maxCount);
		infolevel = findFirstRequest->infolevel;
		debug2("*** infolevel: %x\r\n", infolevel);
		dosFunctionCall = _FFIRST;

		findFirstResponse = (struct smb_findfirst_response*)responseWritePointer;
		responseWritePointer += sizeof(struct smb_findfirst_response);
		trans2Response->parameter_count = sizeof(struct smb_findfirst_response);
	} else {
		findNextRequest = (struct smb_findnext_request*)trans2RequestParameters;
		returnResumeKey = ((findNextRequest->flags & SMB_REQUIRE_RESUME_KEY) == 0);
		sid = findNextRequest->sid;
		debug2("*** findnext sid: %s\r\n", sid);
		fibPointer = &(currentTreeConnection->searches[sid]);
		fib = *fibPointer;
		if(fib == null) {
			SetError(ERRDOS, ERRbadfid);
			return false;
		}

		closeIfEnd = ((findNextRequest->flags & SMB_CLOSE_IF_END) != 0);
		debug2("*** closeifend: %i\r\n", closeIfEnd);
		maxCount = findNextRequest->search_count;
		debug2("*** maxcount: %i\r\n", maxCount);
		infolevel = findNextRequest->infolevel;
		debug2("*** infolevel: %x\r\n", infolevel);
		dosFunctionCall = _FNEXT;

		findNextResponse = (struct smb_findnext_response*)responseWritePointer;
		responseWritePointer += sizeof(struct smb_findnext_response);
		trans2Response->parameter_count = sizeof(struct smb_findnext_response);
	}

	if(maxCount > MAX_FIND_ENTRIES_IN_PACKET) {
		maxCount = MAX_FIND_ENTRIES_IN_PACKET;
	}

	firstDirInfoPointer = responseWritePointer;
	while(count < maxCount) {
		debug2("*** fib: %x\r\n", fib);
		if(dosFunctionCall == _FFIRST) {
			pointer = (char*)&(findFirstRequest->filename);
			pointer[-1] = ':';
			pointer[-2] = currentTreeConnection->driveLetter;
			len = strlen(pointer);

			if(StringEndsWith(pointer, "\\*")) {
				pointer[len] = '.';
				pointer[len+1] = '*';
				pointer[len+2] = '\0';
			}

			regs.Words.DE = (int)&(pointer[-2]);
			regs.Bytes.B = findFirstRequest->search_attributes;

			while((ch = *pointer) != '\0') {
				if(ch == '>') {
					*pointer = '?';
				} else if(ch == '"') {
					*pointer = '.';
				} else if(ch == '<') {
					*pointer = '*';
				}
				pointer++;
			}

			debug2("*** find first: %s\r\n", (char*)regs.Words.DE);

			debug3("*** searching: (%x) %s\r\n", regs.Words.DE, (char*)regs.Words.DE);
			debug2("*** search attrs: %x\r\n", regs.Bytes.B);
		}
		regs.Words.IX = (int)fib;
		DosCall(dosFunctionCall, &regs, REGS_ALL, REGS_AF);
		error = regs.Bytes.A;
		debug2("*** DOS error: %x\r\n", error);
		if(error == _NOFIL) {
			endReached = true;
			break;
		} else if(error != 0) {
			SetSmbErrorFromMsxdosError(error);
			if(fib != tempFIB) {
				debug3("*** error on FFIRST or FNEXT (%x), free fib: %x\r\n", error, fib);
				mfree(fib);
				fibPointer = null;
			}
			return false;
		}

		count++;
		dosFunctionCall = _FNEXT;
		debug2("*** found: %s\r\n", fib->filename);

		len = strlen(fib->filename) + 1;

		if(infolevel == SMB_INFO_STANDARD) {
			currentStandardDirInfo = (struct smb_info_standard*)responseWritePointer;

			currentStandardDirInfo->last_write_date = *((ushort*)&(fib->dateOfModification));
			currentStandardDirInfo->last_write_time = *((ushort*)&(fib->timeOfModification));
			currentStandardDirInfo->data_size = fib->fileSize;
			currentStandardDirInfo->allocation_size = currentTreeConnection->bytesPerCluster;
			currentStandardDirInfo->attributes = fib->attributes;
			currentStandardDirInfo->filename_length = len;
			copy((void*)&(currentStandardDirInfo->filename), (void*)&(fib->filename), len);

			responseWritePointer += sizeof(struct smb_info_standard) - sizeof(char) + len;
		}
		else {
			//NOTE: From here we are assuming the info level is either SMB_FIND_FILE_FULL_DIRECTORY_INFO or SMB_FIND_FILE_BOTH_DIRECTORY_INFO

			currentDirInfo = (struct smb_file_directory_info*)responseWritePointer;

			debug2("*** date: %x\r\n", *(int*)&(fib->dateOfModification));
			FillDateFromFib(&date, fib);
			SetFiletimeField(&date, (byte*)&(currentDirInfo->last_write_time), true);

		    *((long*)&(currentDirInfo->end_of_file)) = fib->fileSize;
			currentDirInfo->filename_length = len;
			currentDirInfo->ext_file_attributes = fib->attributes == 0 ? 0x80 : fib->attributes;
			*(long*)&(currentDirInfo->allocation_size) = currentTreeConnection->bytesPerCluster;

			if(infolevel == SMB_FIND_FILE_BOTH_DIRECTORY_INFO) {
				currentDirInfoWithShortName = (struct smb_both_file_directory_info*)currentDirInfo;
				currentDirInfoWithShortName->short_name_length = len - 1;
				copy((void*)&(currentDirInfoWithShortName->short_name), (void*)&(fib->filename), len);
				copy((void*)&(currentDirInfoWithShortName->filename), (void*)&(fib->filename), len);
				currentDirInfoWithShortName->next_entry_offset = sizeof(struct smb_both_file_directory_info) - sizeof(char) + len;
			} else {
				copy((void*)&(currentDirInfo->filename), (void*)&(fib->filename), len);
				currentDirInfo->next_entry_offset = sizeof(struct smb_file_directory_info) - sizeof(char) + len;
			}

			responseWritePointer += currentDirInfo->next_entry_offset;
		}
	}

	if(count != 0 && currentDirInfo != null) {
		currentDirInfo->next_entry_offset = 0;
	}

	if(!endReached) {
		lastNameOffset = (infolevel == SMB_INFO_STANDARD ? &(currentStandardDirInfo->filename) : &(currentDirInfo->filename)) - firstDirInfoPointer;
	}

	if(isFirst) {
		findFirstResponse->sid = sid;
		findFirstResponse->search_count = count;
		findFirstResponse->end_of_search = endReached;
		findFirstResponse->last_name_offset = lastNameOffset;
	} else {
		findNextResponse->search_count = count;
		findNextResponse->end_of_search = endReached;
		findNextResponse->last_name_offset = lastNameOffset;
	}

	if(closeIfEnd && persistentSearch && endReached) {
		mfree(fib);
		debug3("*** find end, free fib: %x, fib pointer: %x\r\n", fib, fibPointer);
		*fibPointer = null;
	}

	trans2Response->data_count = (int)responseWritePointer - (int)firstDirInfoPointer;
	return true;
}


int ProcessQueryInformationRequest()
{
	char* filename;
	byte error;
	bool isIpcTid = request->tid == IPC_TID;
	t_Date date;

	if(!isIpcTid && !GetCurrentTree()) {
		return -1;
	}

	filename = ++requestDataBytes;
	if(*filename == '\0') {	//Information about the filesystem itself (???)
		if(!CurrentTreeDriveIsAvailable())	{
			return -1;
		}

		*responseWritePointer = SMB_FILE_ATTR_DIRECTORY;
		responseWritePointer += 22;
		return 10;
	} else if(isIpcTid) {
		responseWritePointer += 22;
		return 10;
	}

	*--filename = ':';
	*--filename = currentTreeConnection->driveLetter;

	regs.Words.DE = (int)filename;
	regs.Bytes.B = SMB_FILE_ATTR_DIRECTORY | SMB_FILE_ATTR_HIDDEN | SMB_FILE_ATTR_SYSTEM;
	regs.Words.IX = (int)tempFIB;
	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
	debug3("*** QueryInfo for %s, ffirst error: %x\r\n", filename, regs.Bytes.A);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	*responseWritePointer++ = tempFIB->attributes;
	responseWritePointer++;
	FillDateFromFib(&date, tempFIB);
	SetUtimeField(&date, (unsigned long*)responseWritePointer);
	responseWritePointer += 4;
	InsertLongInResponse(tempFIB->fileSize);
	responseWritePointer += 12; //reserved + zero byte count

	return 10;
}


int ProcessFindClose2Request()
{
	ushort sid = *(ushort*)requestReadPointer;
	t_FileInfoBlock** fibPointer;
	t_FileInfoBlock* fib;

	if(sid < MAX_SEARCHES_PER_TREE) {
		fibPointer = &(currentTreeConnection->searches[sid]);
		fib = *fibPointer;
		if(fib != null) {
			debug3("*** ProcessFindClose2Request, fibPointer: %x, fib: %x\r\n", fibPointer, fib);
			mfree(fib);
			*fibPointer = null;
			responseWritePointer += 2; //zero byte count
			return 0;
		}
	}

	SetError(ERRDOS, ERRbadfid);
	return -1;
}


int ProcessQueryInformation2Request()
{
	struct smb_query_information2_response* queryInfo2Response = (struct smb_query_information2_response*)responseWritePointer;
	byte fileHandle;
	byte error;

	if(!GetCurrentTree()) {
		return -1;
	}

	fileHandle = *requestReadPointer;
	
	regs.Bytes.B = fileHandle;
	regs.Bytes.A = 0;
	DosCall(_HFTIME, &regs, REGS_MAIN, REGS_MAIN);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}
	queryInfo2Response->last_write_date = regs.UWords.HL;
	queryInfo2Response->last_write_time = regs.UWords.DE;

	regs.Bytes.B = fileHandle;
	regs.Bytes.A = 0;
	DosCall(_HATTR, &regs, REGS_MAIN, REGS_MAIN);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}
	queryInfo2Response->attributes = (ushort)regs.Bytes.L;

	regs.Bytes.B = fileHandle;
	regs.Bytes.A = 2;
	regs.Words.HL = 0;
	regs.Words.DE = 0;
	DosCall(_SEEK, &regs, REGS_MAIN, REGS_MAIN);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}
	queryInfo2Response->file_size = (ulong)regs.Words.HL;
	((uint*)&(queryInfo2Response->file_size))[1] = (ulong)regs.Words.DE;

	CalculateBytesPerCluster();
	queryInfo2Response->allocation_size = currentTreeConnection->bytesPerCluster;

	responseWritePointer += sizeof(struct smb_query_information2_response) + 2;	//+2 for empty byte count

	return sizeof(struct smb_query_information2_response)/2;
}


int ProcessCreateOrDeleteDirectoryRequest(bool isDelete)
{
	char* directoryName;
	byte error;
	byte functionCall;

	if(!GetCurrentTree()) {
		return -1;
	}

	if(IsReadOnlyServer()) {
		return -1;
	}

	directoryName = requestDataBytes + 1 - 2;	//+1 for "buffer format"
	directoryName[0] = currentTreeConnection->driveLetter;
	directoryName[1] = ':';

	regs.Words.DE = (int)directoryName;
	if(isDelete) {
		functionCall = _DELETE;
	} else {
		regs.Bytes.B = SMB_FILE_ATTR_DIRECTORY | 0x80;
		regs.Words.IX = (int)tempFIB;
		functionCall = _FNEW;
	}
	DosCall(functionCall, &regs, REGS_ALL, REGS_AF);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	responseWritePointer += 2; //zero byte count
	return 0;
}


int ProcessRenameOrDeleteRequest(bool isDelete)
{
	char* originPath;
	char* destinationPath;
	char* originFilename;
	char* destinationFilename;
	byte error;
	byte functionCall;
	bool mustMove;
	bool mustRename;

	if(!GetCurrentTree()) {
		return -1;
	}

	if(IsReadOnlyServer()) {
		return -1;
	}

	originPath = requestDataBytes + 1;	//+1 for "buffer format"
	originPath[-2] = currentTreeConnection->driveLetter;
	originPath[-1] = ':';
	if(!isDelete) {
		destinationPath = originPath + strlen(originPath) + 1 + 1;  //+ string terminator and buffer format
	}

	regs.Words.DE = (int)originPath - 2;
	regs.Bytes.B = *requestReadPointer;
	regs.Words.IX = (int)tempFIB;
	DosCall(_FFIRST, &regs, REGS_ALL, REGS_AF);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	if(isDelete) {
		functionCall = _DELETE;
	} else {
		//This SMB command can be used to move, rename, or both in one single operation.
		//MSX-DOS can't move and rename at the same time, so we must do it in two steps.
		//Also, paths must be adapted so that rename gets a pure filename and move gets a pure pathname.
		originFilename = SeparatePathAndFilename(originPath);
		destinationFilename = SeparatePathAndFilename(destinationPath);
		mustRename = !StringIs(destinationFilename, originFilename);
		mustMove = !StringIs(destinationPath, originPath);
	}

	regs.Words.DE = (int)tempFIB;

	while(error == 0) {
		if(isDelete) {
			DosCall(_DELETE, &regs, REGS_MAIN, REGS_AF);
			if((error = regs.Bytes.A) != 0) {
				SetSmbErrorFromMsxdosError(error);
				return -1;
			}
		} else {
			if(mustRename) {
				regs.UWords.HL = (uint)destinationFilename;
				DosCall(_RENAME, &regs, REGS_MAIN, REGS_AF);
				if((error = regs.Bytes.A) != 0) {
					SetSmbErrorFromMsxdosError(error);
					return -1;
				}
			}

			if(mustMove) {
				regs.UWords.HL = (uint)destinationPath;
				DosCall(_MOVE, &regs, REGS_MAIN, REGS_AF);
				if((error = regs.Bytes.A) != 0) {
					SetSmbErrorFromMsxdosError(error);
					return -1;
				}
			}
		}

		regs.Words.IX = (int)tempFIB;
		DosCall(_FNEXT, &regs, REGS_ALL, REGS_AF);
		error = regs.Bytes.A;
		if(error != 0 && error != _NOFIL) {
			SetSmbErrorFromMsxdosError(error);
			return -1;
		}
	}

	responseWritePointer += 2; //zero byte count
	return 0;
}


int ProcessSetInformationRequest()
{
	char* path;
	byte error;

	if(!GetCurrentTree()) {
		return -1;
	}

	if(IsReadOnlyServer()) {
		return -1;
	}

	path = requestDataBytes - 1;
	path[0] = currentTreeConnection->driveLetter;
	path[1] = ':';

	regs.Words.DE = (int)path;
	regs.Bytes.A = 1;
	regs.Bytes.L = *requestReadPointer;
	DosCall(_ATTR, &regs, REGS_MAIN, REGS_AF);
	if((error = regs.Bytes.A) != 0) {
		SetSmbErrorFromMsxdosError(error);
		return -1;
	}

	responseWritePointer += 2; //zero byte count
	return 0;
}


char* SeparatePathAndFilename(char* path)
{
	//Assuming that "path" is a path+file specifier,
	//terminate the string after the path
	//and return a pointer to the file.
	char* pointer = path + strlen(path);
	while(*pointer != '\\') {
		pointer--;
	}
	*pointer = '\0';
	return pointer + 1;
}


int ProcessEchoRequest()
{
	ushort echoCount = *((ushort*)requestReadPointer);
	ushort i;

	*((ushort*)responseWritePointer) = echoCount * requestDataBytesCount;	//data count
	responseWritePointer += 2;
	for(i = 0; i < echoCount; i++) {
		copy(responseWritePointer, requestDataBytes, requestDataBytesCount);
		responseWritePointer += requestDataBytesCount;
	}
	
	return 0;
}


int ProcessQueryInformationDiskRequest()
{
	struct smb_query_information_disk_response* response = (struct smb_query_information_disk_response*)responseWritePointer;

	if(!GetCurrentTree()) {
		return -1;
	}

	regs.Bytes.E = currentTreeConnection->driveLetter - 'A' + 1;
	DosCall(_ALLOC, &regs, REGS_MAIN, REGS_MAIN);

	response->total_units = regs.UWords.DE;
    response->blocks_per_unit = regs.Bytes.A;
    response->block_size = MSXDOS_SECTOR_SIZE;
    response->free_units = regs.UWords.HL;

	responseWritePointer += sizeof(struct smb_info_allocation) + 2;  //+2 for zero byte count
	return sizeof(struct smb_query_information_disk_response)/2;
}


void InsertLongInResponse(long value)
{
	*((long*)responseWritePointer) = value;
	responseWritePointer += 4;
}


void InsertReferentIdInResponse()
{
	InsertLongInResponse(++nextReferentId);
}


void InitializeResponse()
{
    response = (struct smb*)(responseBuffer + NETBIOS_HEADER_LENGTH);
    responseWritePointer = (byte*)response;
    Clear(responseBuffer, MAX_RESPONSE_SIZE + NETBIOS_HEADER_LENGTH);
    
    memcpy(response->protocol, "\xffSMB", 4);
    response->cmd = request->cmd;
    response->pidhigh = request->pidhigh;
    response->flags = SMB_SERVER_FLAGS;
    response->flags2 = SMB_SERVER_FLAGS2;
    memcpy(&(response->tid), &(request->tid), 8); //copy TID, PID, UID and MID in a row
}


void SendErrorResponse(byte errorClass, unsigned short errorCode)
{
    response->error_class = errorClass;
    response->error = errorCode;
    SendResponse();
}


void SendResponse()
{
    int responseLength = responseWritePointer - (byte*)response;
    int remainingSize = responseLength + NETBIOS_HEADER_LENGTH;
    int blockSize;
    byte* sendPointer = responseBuffer;
    responseBuffer[2] = (responseLength & 0xFF00) >> 8;
    responseBuffer[3] = responseLength & 0xFF;
    
    do {
        do {
            blockSize = remainingSize > 256  ? 256 : remainingSize;
            regs.Bytes.B = currentClientConnection->tcpConnNumber;
            regs.Words.DE = (int)sendPointer;
            regs.Words.HL = blockSize;
            regs.Bytes.C = 1;
            UnapiCall(&codeBlock, TCPIP_TCP_SEND, &regs, REGS_MAIN, REGS_MAIN);
            if(regs.Bytes.A != 0 && regs.Bytes.A != ERR_BUFFER) {
                CloseClientConnection(strConnLost);
                return;
            }
        } while(regs.Bytes.A == ERR_BUFFER);

        remainingSize -= blockSize;
        sendPointer += blockSize;
    } while(remainingSize > 0);
}


bool IsEstablishedConnection(byte tcpConnNumber)
{
    regs.Bytes.B = tcpConnNumber;
    regs.Words.HL = 0;
    UnapiCall(&codeBlock, TCPIP_TCP_STATE, &regs, REGS_MAIN, REGS_MAIN);
    return (regs.Bytes.A == 0 && regs.Bytes.B == 4);
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


void CloseFileHandle(byte handle)
{
    regs.Bytes.B = handle;
    DosCall(_CLOSE, &regs, REGS_MAIN, REGS_NONE);
}


bool StringEndsWith(char* string, char* substring)
{
	string += (strlen(string) - strlen(substring));
	return StringIs(string, substring);
}


bool GuidsAreEqual(byte* guid1, byte* guid2)
{
	int i;

	for(i = 0; i < GUID_LEN; i++) {
		if(*guid1++ != *guid2++) {
			return false;
		}
	}

	return true;
}


void SetFiletimeField(t_Date* date, byte* destination, bool startAt1980)
{
	unsigned long seconds = 0;
	unsigned long secondsHigh = 0;
    byte isLeapYear;
    int loopValue;
	longint nsecs;
	longint temp;

    //* Years

    loopValue = startAt1980 ? 1980 : 2011;
    while(loopValue < date->Year) {
        isLeapYear = (loopValue & 3) == 0;
        seconds += (isLeapYear ? SECS_IN_LYEAR : SECS_IN_YEAR);
        loopValue++;
    }
    
    //* Months
    
    isLeapYear = (date->Year & 3) == 0;
    loopValue = 1;
    while(loopValue < date->Month) {
        if(isLeapYear && (loopValue == 2)) {
            seconds += SECS_IN_MONTH_29;
        } else {
            seconds += SecsPerMonth[loopValue-1];
        }
        loopValue++;
    }
    
    //* Rest of parameters
    
    seconds += (SECS_IN_DAY) * (date->Day-1);
    seconds += (SECS_IN_HOUR) * date->Hour;
    seconds += (SECS_IN_MINUTE) * date->Minute;
    seconds += date->Second;

	if(startAt1980) {
		seconds -= timeZoneSeconds;
	}

	//--- Now seconds = secs since 2011/1/1

	//* Convert to 100 nanosecon units (*= 10 000 000)

	*((unsigned long*)temp) = seconds;
	*((unsigned long*)&(temp.word2)) = 0;
	MultBy10Milions(&nsecs, &temp);

	//--- Now secondsHigh : seconds = nanosecs since 2011/1/1

	//* Add nanosecs since 1601/1/1

	*((unsigned long*)temp) = startAt1980 ? NSECS_1601_TO_1980_LOW : NSECS_1601_TO_2011_LOW;
	*((unsigned long*)&(temp.word2)) = startAt1980 ? NSECS_1601_TO_1980_HIGH : NSECS_1601_TO_2011_HIGH;
	add64((longint*)destination, &nsecs, &temp);
}


void add64(longint* result, longint* a, longint* b)
{
    /* use an intermediate large enough to hold the result
       of adding two 16 bit numbers together. */
    unsigned long partial;

    /* add the chunks together, least significant bit first */
    partial = (unsigned long)a->word0 + (unsigned long)b->word0;

    /* extract thie low 16 bits of the sum and store it */
    result->word0 = (uint)partial;

    /* add the overflow to the next chunk of 16 */
    partial = ((uint*)&partial)[1] + (unsigned long)a->word1 + (unsigned long)b->word1;
    /* keep doing this for the remaining bits */
    result->word1 =(uint)partial;
    partial = ((uint*)&partial)[1] + (unsigned long)a->word2 + (unsigned long)b->word2;
    result->word2 = (uint)partial;
    partial = ((uint*)&partial)[1] + (unsigned long)a->word3 + (unsigned long)b->word3;
    result->word3 = (uint)partial;
    /* if the result overflowed, return nonzero */
    //return partial >> 16;
}


#define C10_MILIONS_LOW ((unsigned long)0x9680)
#define C10_MILIONS_HIGH ((unsigned long)0x98)

void MultBy10Milions(longint* destination, longint* a)
{
	unsigned long partial;
	longint result1, result2;

    partial = ((unsigned long)a->word0 * C10_MILIONS_LOW);
    result1.word0 = (uint)partial;

	partial = ((unsigned long)a->word1 * C10_MILIONS_LOW) + (((uint*)&partial)[1]);
	result1.word1 = (uint)partial;

	partial = ((unsigned long)a->word2 * C10_MILIONS_LOW) + (((uint*)&partial)[1]);
	result1.word2 = (uint)partial;

	partial = ((unsigned long)a->word3 * C10_MILIONS_LOW) + (((uint*)&partial)[1]);
	result1.word3 = (uint)partial;


	result2.word0 = 0;

	partial = ((unsigned long)a->word0 * C10_MILIONS_HIGH);
    result2.word1 = (uint)partial;

	partial = ((unsigned long)a->word1 * C10_MILIONS_HIGH) + (((uint*)&partial)[1]);
	result2.word2 = (uint)partial;

	partial = ((unsigned long)a->word2 * C10_MILIONS_HIGH) + (((uint*)&partial)[1]);
	result2.word3 = (uint)partial;


	add64(destination, &result1, &result2);
}


void GetSystemDate(t_Date* destination)
{
	DosCall(_GDATE, &regs, REGS_NONE, REGS_MAIN);
	destination->Year = regs.Words.HL;
	destination->Month = regs.Bytes.D;
	destination->Day = regs.Bytes.E;
	DosCall(_GTIME, &regs, REGS_NONE, REGS_MAIN);
	destination->Hour = regs.Bytes.H;
	destination->Minute = regs.Bytes.L;
	destination->Second = regs.Bytes.D;
}


void SetSmbErrorFromMsxdosError(byte errorCode)
{
	byte smbClass, msxdosError;
	ushort smbError;
	byte* pointer = MsxDosToSmbErrorMappings;

	while((msxdosError = *pointer++) != 0) {
		if(msxdosError == errorCode) {
			smbError = *(ushort*)pointer;
			smbClass = (((byte*)&smbError)[1] >> 6) & 3;
			smbError &= 0x3FFF;
			SetError(smbClass, smbError);
			return;
		}
		pointer += 2;
	}

	SetError(ERRDOS, ERRgeneral);
}


bool GetCurrentTree()
{
	byte i;
	t_TreeConnection* currentTree = currentClientConnection->treeConnections[0];
	for(i = 0; i < MAX_TREES_PER_CONN; i++) {
		currentTree = currentClientConnection->treeConnections[i];
		if(currentTree != null && currentTree->TID == request->tid) {
			currentTreeConnection = currentTree;
			return true;
		}
	}

	SetError(ERRSRV, ERRinvtid);
	return false;
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


void GetTimeZoneMinutes(byte* buffer)
{
	byte hours;
	byte minutes;
	unsigned int multiplier;

	timeZoneMinutes = 0;

	regs.Words.HL = (int)"TIMEZONE";
    regs.Words.DE = (int)buffer;
    regs.Bytes.B = 8;
    DosCall(_GENV, &regs, REGS_MAIN, REGS_AF);
    if(buffer[0] == '\0') {
		return;
    }

	hours = (((byte)(buffer[1])-'0')*10) + (byte)(buffer[2]-'0');
    if(hours > 12) {
		return;
	}
        
    minutes = (((byte)(buffer[4])-'0')*10) + (byte)(buffer[5]-'0');
    if(minutes > 59) {
        return;
    }
        
	if(buffer[0] == (unsigned char)'+') {
		multiplier = 1;
	} else if(buffer[0] == (unsigned char)'-') {
		multiplier = -1;
	} else {
		return;
	}

	timeZoneMinutes = multiplier * (minutes + (hours * 60));
	timeZoneSeconds = timeZoneMinutes * 60;
}


bool CurrentTreeDriveIsAvailable()
{
	regs.Bytes.B = currentTreeConnection->driveLetter - 'A' + 1;
	regs.Words.DE = (int)tempFIB;
	DosCall(_GETCD, &regs, REGS_MAIN, REGS_AF);
	if(regs.Bytes.A == 0) {
		return true;
	} else {
		SetSmbErrorFromMsxdosError(regs.Bytes.A);
		return false;
	}
}


void FillDateFromFib(t_Date* date, t_FileInfoBlock* fib)
{
	date->Year = ((fib->dateOfModification[1] >> 1) & 0x7F) + 1980;
	date->Month = ((*(ushort*)&(fib->dateOfModification)) >> 5) & 0x0F;
	date->Day = fib->dateOfModification[0] & 0x1F;
	date->Hour = ((fib->timeOfModification[1]) >> 3) & 0x1F;
	date->Minute = ((*(ushort*)&(fib->timeOfModification)) >> 5) & 0x3F;
	date->Second = fib->timeOfModification[0] & 0x1F;
}


void SetUtimeField(t_Date* date, unsigned long* destination)
{
	unsigned long seconds = SECS_1970_TO_2011;
    byte isLeapYear;
    int loopValue;

    //* Years

    loopValue = 2011;
    while(loopValue < date->Year) {
        isLeapYear = (loopValue & 3) == 0;
        seconds += (isLeapYear ? SECS_IN_LYEAR : SECS_IN_YEAR);
        loopValue++;
    }
    
    //* Months
    
    isLeapYear = (date->Year & 3) == 0;
    loopValue = 1;
    while(loopValue < date->Month) {
        if(isLeapYear && (loopValue == 2)) {
            seconds += SECS_IN_MONTH_29;
        } else {
            seconds += SecsPerMonth[loopValue-1];
        }
        loopValue++;
    }
    
    //* Rest of parameters
    
    seconds += (SECS_IN_DAY) * (date->Day-1);
    seconds += (SECS_IN_HOUR) * date->Hour;
    seconds += (SECS_IN_MINUTE) * date->Minute;
    seconds += date->Second;

	seconds -= timeZoneSeconds;

	*destination = seconds;
}


byte* InsertAsUnicode(char* string, byte* destination)
{
	char ch;

	do {
		*destination++ = (ch = *string++);
		destination++;
	} while(ch != 0);

	return destination;
}


byte* GetFileHandlePointer(byte fid)
{
	byte i;
	byte* pointer = &(currentTreeConnection->openFileHandles[0]);
	for(i = 0; i < MAX_OPENS_PER_TREE; i++) {
		if(*pointer == fid) {
			return pointer;
		}
		pointer++;
	}

	SetError(ERRDOS, ERRbadfid);
	return null;
}


void CalculateBytesPerCluster()
{
	if(currentTreeConnection->bytesPerCluster == 0) {
		regs.Bytes.E = currentTreeConnection->driveLetter - 'A' + 1;
		DosCall(_ALLOC, &regs, REGS_MAIN, REGS_AF);
		currentTreeConnection->bytesPerCluster = regs.Bytes.A * MSXDOS_SECTOR_SIZE;
	}
}


bool IsReadOnlyServer()
{
	if(readOnlyServer) {
		SetError(ERRDOS, ERRnowrite);
		return true;
	}
	return false;
}


void PatchInsertDiskPromptHook()
{
	byte* pointer = (byte*)0xF24F;
	oldInsertDiskPromptHook = *pointer;
	*pointer = 0xF1;
}


void RestoreInsertDiskPromptHook()
{
	byte* pointer = (byte*)0xF24F;
	*pointer = oldInsertDiskPromptHook;
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
