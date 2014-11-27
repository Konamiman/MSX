/* TCP/IP UNAPI implementations control program
   By Konamiman 5/2010
   
   Compilation command line:
   
   sdcc --code-loc 0x170 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.rel asm.lib tcpip.c
   hex2bin -e com tcpip.ihx
   
   ASM.LIB, MSXCHAR.REL and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "asm.h"

#define _TERM0 0

enum TcpipUnapiFunctions {
    UNAPI_GET_INFO = 0,
    TCPIP_GET_CAPAB = 1,
    TCPIP_GET_IPINFO = 2,
    TCPIP_NET_STATE = 3,
    TCPIP_DNS_Q = 6,
    TCPIP_CONFIG_AUTOIP = 25,
    TCPIP_CONFIG_IP = 26,
    TCPIP_CONFIG_TTL = 27,
    TCPIP_CONFIG_PING = 28,
};

enum TcpipErrorCodes {
    ERR_OK,			    
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

enum IpAddresses {
    IP_LOCAL = 1,
    IP_REMOTE = 2,
    IP_MASK = 3,
    IP_GATEWAY = 4,
    IP_DNS1 = 5,
    IP_DNS2 = 6
};

const char* strPresentation=
    "TCP/IP UNAPI control program 1.0\r\n"
    "By Konamiman, 5/2010\r\n"
    "\r\n";

const char* strUsage=
    "Usage: tcpip f | s\r\n"
    "       tcpip ip [l<address>] [r<address>] [m<address>] [g<address>]\r\n"
    "                [p<address>] [s<address>] [a(0|1|2|3)]]\r\n"
    "       tcpip set [p(0|1)] [ttl<TTL value>] [tos<TOS value>]\r\n"
    "\r\n"
    "f: Show implementation capabilities and features\r\n"
    "s: Show current configuration and status information\r\n"
    "ip l/r/m/g/p/s: Change the IP address (local, remote, subnet mask,\r\n"
    "                primary DNS server, secondary DNS server)\r\n"
    "ip a: Configure IP addresses to retrieve automatically\r\n"
    "      (0=none, 1=local+subnet+gateway, 2=DNS servers, 3=all)\r\n"
    "set p: Enable (1) or disable (0) reply to incoming PINGs\r\n"
    "set ttl: Set TTL for outgoing deatagrams (0-255)\r\n"
    "set tos: Set ToS for outgoing deatagrams (0-255)\r\n";

const char* strMissingParams = "Missing parameters";
const char* strInvParam = "Invalid parameter";

const char* strYES="YES";
const char* strNO="NO";
const char* strON="ON";
const char* strOFF="OFF";

Z80_registers regs;
int i;
int param;
unapi_code_block codeBlock;

byte mustChangeIP[6];
byte newIP[6*4];
byte mustChangeAutoIP = 0;
byte newAutoIP;
byte mustChangeTTL = 0;
byte newTTL;
byte mustChangeTOS = 0;
byte newTOS;
byte mustChangePingReply = 0;
byte newPingReply;
uint specVersion;


// I know, these should be on a tcpip.h

void PrintUsageAndEnd();
void PrintImplementationName();
void DoShowInfo();
void Terminate(char* errorMessage);
int strcmpi(const char *a1, const char *a2);
int strncmpi(const char *a1, const char *a2, unsigned size);
void DoShowFeatures();
void DoShowStatus();
void ParseFlagParam(char* param, byte* flagAddress, byte* flagValue);
void ParseIP(char* IP, byte* flagAddress, byte* ipAddress);
void ParseAutoIP(char* param, byte* flagAddress, byte* flagValue);
void ParseByteParam(char* param, byte* flagAddress, byte* valueAddress);
void DoChangeIP(byte IPindex, byte* IPvalue);
void DoChangeAutoIP(byte autoIP);
void DoChangePingReply(byte newPingReply);
void DoChangeTtlTos(byte mustChangeTTL, byte newTTL, byte mustChangeTOS, byte newTOS);
void print(char* str);

#define print(x) printf(x)


/**********************
 ***  MAIN is here  ***
 **********************/
 
int main(char** argv, int argc)
{
    memset(mustChangeIP, 0, 6);
    print(strPresentation);
    if(argc==0) {
        PrintUsageAndEnd();
    }

    i = UnapiGetCount("TCP/IP");
    if(i==0) {
        print("*** No TCP/IP UNAPI implementations found");
        return 0;
    }
    UnapiBuildCodeBlock(NULL, 1, &codeBlock);
    
    if(strcmpi(argv[0], "f")==0) {
        PrintImplementationName();
        DoShowFeatures();
        Terminate(NULL);
    }
    else if(strcmpi(argv[0], "s")==0) {
        PrintImplementationName();
        DoShowStatus();
        Terminate(NULL);
    }
    else if(strcmpi(argv[0], "ip")==0) {
        if(argc == 1) {
            Terminate(strMissingParams);
        }
        for(param=1; param<argc; param++) {
            if(tolower(argv[param][0]) == 'l') {
                ParseIP(argv[param]+1, &mustChangeIP[IP_LOCAL-1], &newIP[(IP_LOCAL-1)*4]);
            } else if(tolower(argv[param][0]) == 'r') {
                ParseIP(argv[param]+1, &mustChangeIP[IP_REMOTE-1], &newIP[(IP_REMOTE-1)*4]);
            } else if(tolower(argv[param][0]) == 'm') {
                ParseIP(argv[param]+1, &mustChangeIP[IP_MASK-1], &newIP[(IP_MASK-1)*4]);
            } else if(tolower(argv[param][0]) == 'g') {
                ParseIP(argv[param]+1, &mustChangeIP[IP_GATEWAY-1], &newIP[(IP_GATEWAY-1)*4]);
            } else if(tolower(argv[param][0]) == 'p') {
                ParseIP(argv[param]+1, &mustChangeIP[IP_DNS1-1], &newIP[(IP_DNS1-1)*4]);
            } else if(tolower(argv[param][0]) == 's') {
                ParseIP(argv[param]+1, &mustChangeIP[IP_DNS2-1], &newIP[(IP_DNS2-1)*4]);
            } else if(tolower(argv[param][0]) == 'a') {
                ParseAutoIP(argv[param]+1, &mustChangeAutoIP, &newAutoIP);
            } else {
                Terminate(strInvParam);
            }
        }
    }
    else if(strcmpi(argv[0], "set")==0) {
        if(argc == 1) {
            Terminate(strMissingParams);
        }
        for(param=1; param<argc; param++) {
            if(tolower(argv[param][0]) == 'p') {
                ParseFlagParam(argv[param]+1, &mustChangePingReply, &newPingReply);
            }
            else if(strncmpi(argv[param], "ttl", 3)==0) {
                ParseByteParam(argv[param]+3, &mustChangeTTL, &newTTL);
            } else if(strncmpi(argv[param], "tos", 3)==0) {
                ParseByteParam(argv[param]+3, &mustChangeTOS, &newTOS);
            } else {
                Terminate(strInvParam);
            }
        }
    }
    else {
        Terminate(strInvParam);
    }
    
    PrintImplementationName();
    
    for(i=IP_LOCAL-1; i<=IP_DNS2-1; i++) {
        if(mustChangeIP[i]) {
            DoChangeIP(i+1, &newIP[i*4]);
        }
    }
    if(mustChangeAutoIP) {
        DoChangeAutoIP(newAutoIP);
    }
    if(mustChangePingReply) {
        DoChangePingReply(newPingReply);
    }
    if(mustChangeTTL || mustChangeTOS) {
        DoChangeTtlTos(mustChangeTTL, newTTL, mustChangeTOS, newTOS);
    }
    
    printf("Done.");
    return 0;    
}


/****************************
 ***  FUNCTIONS are here  ***
 ****************************/

void PrintUsageAndEnd()
{
    print(strUsage);
    DosCall(0, &regs, REGS_MAIN, REGS_NONE);
}


void PrintImplementationName()
{
    byte readChar;
    byte versionMain;
    byte versionSec;
    uint nameAddress;
    
    print("Implementation name: ");
    
    UnapiCall(&codeBlock, UNAPI_GET_INFO, &regs, REGS_NONE, REGS_MAIN);
    versionMain = regs.Bytes.B;
    versionSec = regs.Bytes.C;
    nameAddress = regs.UWords.HL;
    
    specVersion = regs.UWords.DE;   //Also, save specification version implemented
    
    while(1) {
        readChar = UnapiRead(&codeBlock, nameAddress);
        if(readChar == 0) {
            break;
        }
        putchar(readChar);
        nameAddress++;
    }
    
    printf(" v%u.%u\r\n\r\n", versionMain, versionSec);
}


void Terminate(const char* errorMessage)
{
    if(errorMessage != NULL) {
        printf("\r\n*** %s\r\n", errorMessage);
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


void PrintYesNoBit(char* message, uint flags, int bitIndex)
{
    printf("%s: %s\r\n", message, (flags & (1<<bitIndex)) ? strYES : strNO);
}


void DoShowFeatures()
{
    regs.Bytes.B = 1;
    UnapiCall(&codeBlock, TCPIP_GET_CAPAB, &regs, REGS_MAIN, REGS_MAIN);
    
    print("Capabilities:\r\n\r\n");
    
    PrintYesNoBit("Send ICMP echo messages (PINGs) and retrieve the replies", regs.UWords.HL, 0);
    PrintYesNoBit("Resolve host names by querying a local hosts file or database", regs.UWords.HL, 1);
    PrintYesNoBit("Resolve host names by querying a DNS server", regs.UWords.HL, 2);
    PrintYesNoBit("Open TCP connections in active mode", regs.UWords.HL, 3);
    PrintYesNoBit("Open TCP connections in passive mode, with specified remote socket", regs.UWords.HL, 4);
    PrintYesNoBit("Open TCP connections in passive mode, with unespecified remote socket", regs.UWords.HL, 5);
    PrintYesNoBit("Send and receive TCP urgent data", regs.UWords.HL, 6);
    PrintYesNoBit("Explicitly set the PUSH bit when sending TCP data", regs.UWords.HL, 7);
    PrintYesNoBit("Send data to a TCP connection before the ESTABLISHED state is reached", regs.UWords.HL, 8);
    PrintYesNoBit("Flush the output buffer of a TCP connection", regs.UWords.HL, 9);
    PrintYesNoBit("Open UDP connections", regs.UWords.HL, 10);
    PrintYesNoBit("Open raw IP connections", regs.UWords.HL, 11);
    PrintYesNoBit("Explicitly set the TTL and TOS for outgoing datagrams", regs.UWords.HL, 12);
    PrintYesNoBit("Explicitly set the automatic reply to PINGs on or off", regs.UWords.HL, 13);
    PrintYesNoBit("Automatically obtain the IP addresses", regs.UWords.HL, 14);

    print("Features:\r\n\r\n");
    
    PrintYesNoBit("Physical link is point to point", regs.UWords.DE, 0);
    PrintYesNoBit("Physical link is wireless", regs.UWords.DE, 1);
    PrintYesNoBit("Connection pool is shared by TCP, UDP and raw IP", regs.UWords.DE, 2);
    PrintYesNoBit("Checking network state is time-expensive", regs.UWords.DE, 3);
    PrintYesNoBit("The TCP/IP handling code is assisted by external hardware", regs.UWords.DE, 4);
    PrintYesNoBit("The loopback address (127.x.x.x) is supported", regs.UWords.DE, 5);
    PrintYesNoBit("A host name resolution cache is implemented", regs.UWords.DE, 6);
    PrintYesNoBit("IP datagram fragmentation is supported", regs.UWords.DE, 7);
    PrintYesNoBit("User timeout suggested when opening a TCP connection is actually applied", regs.UWords.DE, 8);
    
    print("\r\nLink level protocol: ");
    if(regs.Bytes.B == 0) {
        print("Unespecified\r\n");
    } else if(regs.Bytes.B == 1) {
        print("SLIP\r\n");
    } else if(regs.Bytes.B == 2) {
        print("PPP\r\n");
    } else if(regs.Bytes.B == 3) {
        print("Ethernet\r\n");
    } else {
        printf("Unknown (%i)\r\n", regs.Bytes.B);
    }
    
    regs.Bytes.B = 2;
    UnapiCall(&codeBlock, TCPIP_GET_CAPAB, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.B != 0) {
        printf("TCP connections (total / free): %i / %i\r\n", regs.Bytes.B, regs.Bytes.D);
    }
    if(regs.Bytes.C != 0) {
        printf("UDP connections (total / free): %i / %i\r\n", regs.Bytes.C, regs.Bytes.E);
    }
    if(regs.Bytes.H != 0) {
        printf("Raw IP connections (total / free): %i / %i\r\n", regs.Bytes.H, regs.Bytes.L);
    }

    regs.Bytes.B = 3;
    UnapiCall(&codeBlock, TCPIP_GET_CAPAB, &regs, REGS_MAIN, REGS_MAIN);
    printf("Maximum incoming datagram size supported: %i bytes\r\n", regs.UWords.HL);
    printf("Maximum outgoing datagram size supported: %i bytes\r\n", regs.UWords.DE);
}


void DoShowStatus()
{
    regs.Bytes.B = IP_LOCAL;
    UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
    printf("Local IP address: %i.%i.%i.%i\r\n", regs.Bytes.L, regs.Bytes.H, regs.Bytes.E, regs.Bytes.D);
    
    regs.Bytes.B = IP_REMOTE;
    UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == 0) {
        printf("Remote IP address: %i.%i.%i.%i\r\n", regs.Bytes.L, regs.Bytes.H, regs.Bytes.E, regs.Bytes.D);
    }

    regs.Bytes.B = IP_MASK;
    UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == 0) {
        printf("Subnet mask: %i.%i.%i.%i\r\n", regs.Bytes.L, regs.Bytes.H, regs.Bytes.E, regs.Bytes.D);
    }
    
    regs.Bytes.B = IP_GATEWAY;
    UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == 0) {
        printf("Default gateway address: %i.%i.%i.%i\r\n", regs.Bytes.L, regs.Bytes.H, regs.Bytes.E, regs.Bytes.D);
    }

    regs.Bytes.B = IP_DNS1;
    UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
    printf("Primary DNS server address: %i.%i.%i.%i\r\n", regs.Bytes.L, regs.Bytes.H, regs.Bytes.E, regs.Bytes.D);

    regs.Bytes.B = IP_DNS2;
    UnapiCall(&codeBlock, TCPIP_GET_IPINFO, &regs, REGS_MAIN, REGS_MAIN);
    printf("Secondary DNS server address: %i.%i.%i.%i\r\n", regs.Bytes.L, regs.Bytes.H, regs.Bytes.E, regs.Bytes.D);
    
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_CONFIG_AUTOIP, &regs, REGS_MAIN, REGS_MAIN);
    regs.Bytes.C &= 3;
    print("\r\nAddresses configured for automatic retrieval: ");
    if(regs.Bytes.C == 0) {
        print("None\r\n");
    } else if(regs.Bytes.C == 1) {
        print("Local, mask and gateway\r\n");
    } else if(regs.Bytes.C == 2) {
        print("DNS servers\r\n");
    } else {
        print("All\r\n");
    }
    
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_CONFIG_TTL, &regs, REGS_MAIN, REGS_MAIN);
    printf("\r\nTTL for outgoing datagrams: %i\r\n", regs.Bytes.D);
    printf("ToS for outgoing datagrams: %i\r\n", regs.Bytes.E);
    
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_CONFIG_PING, &regs, REGS_MAIN, REGS_MAIN);
    printf("Reply incoming PING requests: %s\r\n", regs.Bytes.C ? strYES : strNO);
    
    UnapiCall(&codeBlock, TCPIP_NET_STATE, &regs, REGS_MAIN, REGS_MAIN);
    print("Network state: ");
    if(regs.Bytes.B == 0) {
        print("CLOSED\r\n");
    } else if(regs.Bytes.B == 1) {
        print("Opening\r\n");
    } else if(regs.Bytes.B == 2) {
        print("OPEN\r\n");
    } else if(regs.Bytes.B == 3) {
        print("Closing\r\n");
    } else {
        print("Unknown\r\n");
    }
}


void ParseFlagParam(char* param, byte* flagAddress, byte* flagValue)
{
    *flagAddress = 1;

    if(param[0]=='0') {
        *flagValue = 0;
    } else if(param[0]=='1') {
        *flagValue = 1;
    } else {
        Terminate(strInvParam);
    }
}


void ParseIP(char* IP, byte* flagAddress, byte* ipAddress)
{
    *flagAddress = 1;
    
    regs.Words.HL = (int)IP;
    regs.Bytes.B = 2;   //Error if not an IP address
    UnapiCall(&codeBlock, TCPIP_DNS_Q, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        Terminate(strInvParam);
    }
    *((int*)ipAddress) = regs.Words.HL;
    *(((int*)ipAddress)+1) = regs.Words.DE;
}


void ParseAutoIP(char* param, byte* flagAddress, byte* flagValue)
{
    *flagAddress = 1;

    if(param[0] >= '0' && param[0] <= '3') {
        *flagValue = (byte)param[0] - (byte)'0';
    } else {
        Terminate(strInvParam);
    }
}


void DoChangeIP(byte IPindex, byte* IPvalue)
{
    regs.Bytes.B = IPindex;
    regs.Words.HL = *((int*)IPvalue);
    regs.Words.DE = *(((int*)IPvalue)+1);
    UnapiCall(&codeBlock, TCPIP_CONFIG_IP, &regs, REGS_MAIN, REGS_MAIN);
}


void DoChangeAutoIP(byte autoIP)
{
    regs.Bytes.B = 1;
    regs.Bytes.C = autoIP;
    UnapiCall(&codeBlock, TCPIP_CONFIG_AUTOIP, &regs, REGS_MAIN, REGS_MAIN);
}


void ParseByteParam(char* param, byte* flagAddress, byte* valueAddress)
{
    int value;

    *flagAddress = 1;
    value = atoi(param);
    if(value>255 || (*valueAddress == 0 && (param[0]!='0' || param[1]!='\0'))) {
        Terminate(strInvParam);
    }
    *valueAddress = (byte)value;
}


void DoChangePingReply(byte newPingReply)
{
    regs.Bytes.B = 1;
    regs.Bytes.C = newPingReply;
    UnapiCall(&codeBlock, TCPIP_CONFIG_PING, &regs, REGS_MAIN, REGS_MAIN);
}


void DoChangeTtlTos(byte mustChangeTTL, byte newTTL, byte mustChangeTOS, byte newTOS)
{
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_CONFIG_TTL, &regs, REGS_MAIN, REGS_MAIN);
    
    if(mustChangeTTL) {
        regs.Bytes.D = newTTL;
    }
    if(mustChangeTOS) {
        regs.Bytes.E = newTOS;
    }
    
    regs.Bytes.B = 1;
    UnapiCall(&codeBlock, TCPIP_CONFIG_TTL, &regs, REGS_MAIN, REGS_MAIN);
}

