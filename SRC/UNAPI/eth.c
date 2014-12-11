/* Ethernet UNAPI implementation controller
   By Konamiman 2/2010
   
    Compilation command line:
   
   sdcc --code-loc 0x170 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0_msxdos_advanced.rel msxchar.rel asm.lib eth.c
   hex2bin -e com eth.ihx
   
   ASM.LIB, MSXCHAR.REL and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com
   
   (You don't need MSXCHAR.LIB if you manage to put proper PUTCHAR.REL,
   GETCHAR.REL and PRINTF.REL in the standard Z80.LIB... I couldn't manage to
   do it, I get a "Library not created with SDCCLIB" error)
   
   Comments are welcome: konamiman@konamiman.com

*/

#include <stdio.h>
#include "asm.h"

#define LowerCase(c) ((c) | 32)

// Just in case you want to define a faster print function
// for printing plain strings (without formatting).
#define print(x) printf(x)

enum EthUnapiFunctions {
    ETH_GETINFO = 0,
    ETH_RESET,
    ETH_GET_HWADD,
    ETH_GET_NETSTAT,
    ETH_NET_ONOFF,
    ETH_DUPLEX,
    ETH_FILTERS,
    ETH_IN_STATUS,
    ETH_GET_FRAME,
    ETH_SEND_FRAME,
    ETH_OUT_STATUS,
    ETH_SET_HWADD
};

enum EthUnapiFilterFlags {
    FILTER_PROMISCUOUS = 16,
    FILTER_BROADCAST = 4,
    FILTER_SMALLFRAMES = 2
};

const char* strPresentation=
    "Ethernet UNAPI control program 1.0\r\n"
    "By Konamiman, 2/2010\r\n"
    "\r\n";

const char* strUsage=
    "Usage: eth r|i|[h<address>] [e0|1] [d0|1] [p0|1] [b0|1] [s0|1]\r\n"
    "\r\n"
    "r: Reset Ethernet hardware\r\n"
    "i: Show current configuration information\r\n"
    "h: Change the MAC address, <address>=XX-XX-XX-XX-XX-XX\r\n"
    "e: Enable (1) or disable (0) the Ethernet hardware\r\n"
    "d: Set Half-duplex (0) or Full-duplex (1) mode\r\n"
    "p: Enable (1) or disable (0) promiscuous mode\r\n"
    "b: Accept (1) or reject (0) broadcast frames\r\n"
    "s: Accept (1) or reject (0) small frames (<64 bytes)\r\n";

const char* strYES="YES";
const char* strNO="NO";
const char* strON="ON";
const char* strOFF="OFF";

Z80_registers regs;
int i;
int param;
unapi_code_block codeBlock;

byte filterFlags;
byte mustChangeMac=0;
byte newMac[6];
byte newEnableConfig=0;
byte newDuplexConfig=0;
byte newPromiscuousConfig=0;    //0=don't change, 1=disable, 2=enable
byte newBroadcastConfig=0;      //same as above
byte newSmallFrameConfig=0;     //same as above
uint specVersion;


// I know, these should be on an eth.h

void PrintUsageAndEnd();
void PrintImplementationName();
void DoRegisterFilterChange(byte* flagBufferAddress, char newState);
void DoRegisterNewMac(char* newMacString);
byte ParseHexDigit(char digit);
void DoResetHardware();
void DoShowInfo();
void MakeMacString(Z80_registers* regs, char* buffer);
void ByteToHexPlusColon(byte value, char* buffer);
char NibbleToHex(byte value);
void DoChangeMac();
void DoEnableDisableNetworking();
void DoChangeDuplexMode();
void DoGetFilterFlags();
void DoUpdateFilterFlags();
void DoUpdateOneFilterFlag(byte newConfigValue, byte filterMask);
void DoWriteFilterFlags();


/**********************
 ***  MAIN is here  ***
 **********************/
 
int main(char** argv, int argc)
{
    char paramLetter;

    print(strPresentation);
    if(argc==0) {
        PrintUsageAndEnd();
    }

    i = UnapiGetCount("ETHERNET");
    if(i==0) {
        print("*** No Ethernet UNAPI implementations found");
        return 0;
    }
    UnapiBuildCodeBlock(NULL, 1, &codeBlock);
    
    for(param=0; param<argc; param++) {
        paramLetter = LowerCase(argv[param][0]);
        if(paramLetter == 'r') {
            PrintImplementationName();
            DoResetHardware();
            return 0;
        } else if(paramLetter == 'i') {
            PrintImplementationName();
            DoShowInfo();
            return 0;
        } else if(paramLetter == 'h') {
            DoRegisterNewMac(argv[param]+1);
        } else if(paramLetter == 'e') {
            DoRegisterFilterChange(&newEnableConfig, argv[param][1]);
        } else if(paramLetter == 'd') {
            DoRegisterFilterChange(&newDuplexConfig, argv[param][1]);
        } else if(paramLetter == 'p') {
            DoRegisterFilterChange(&newPromiscuousConfig, argv[param][1]);
        } else if(paramLetter == 'b') {
            DoRegisterFilterChange(&newBroadcastConfig, argv[param][1]);
        } else if(paramLetter == 's') {
            DoRegisterFilterChange(&newSmallFrameConfig, argv[param][1]);
        } else {
            PrintUsageAndEnd();
        }
    }

    PrintImplementationName();
    
    if(mustChangeMac) {
        if(specVersion == 0x0100) {
            print("*** MAC address can't be changed.\r\n"
                  "    Ethernet UNAPI specification version implemented is 1.0.\r\n");
        } else if((newMac[0] & 1) == 1) {
            print("*** First byte of MAC must be an even number.\r\n");
        } else {
            DoChangeMac();
        }
    }
    
    if(newEnableConfig != 0) {
        DoEnableDisableNetworking();
    }
    
    if(newDuplexConfig != 0) {
        DoChangeDuplexMode();
    }
    
    if((newPromiscuousConfig | newBroadcastConfig | newSmallFrameConfig) != 0)
    {
        DoGetFilterFlags();
        DoUpdateFilterFlags();
        DoWriteFilterFlags();
    }
    
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
    
    UnapiCall(&codeBlock, ETH_GETINFO, &regs, REGS_NONE, REGS_MAIN);
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


void DoRegisterFilterChange(byte* flagBufferAddress, char newState)
{
    if(newState == '0') {
        *flagBufferAddress = 1;
    } else if(newState == '1') {
        *flagBufferAddress = 2;
    } else {
        PrintUsageAndEnd();
    }
}


void DoRegisterNewMac(char* newMacString)
{
    int i;
    char* newMacPtr;
    newMacPtr = newMac;
    
    newMacString[17] = ':';
    
    for(i=0; i<6; i++) {
        if(newMacString[2]!=':' && newMacString[2]!='-') {
            PrintUsageAndEnd();
        }
        
        *newMacPtr = (ParseHexDigit(newMacString[0]) * 16) + ParseHexDigit(newMacString[1]);
        
        *newMacPtr++;
        newMacString+=3;
    }
    
    mustChangeMac = 1;
}


byte ParseHexDigit(char digit)
{
    if(digit>='0' && digit<='9') {
        return digit-'0';
    }
    digit = LowerCase(digit);
    if(digit>='a' && digit<='f') {
        return digit-'a'+10;
    }
    PrintUsageAndEnd();
    return 0;   //Never reached, needed to avoid warning
}


void DoResetHardware()
{
    UnapiCall(&codeBlock, ETH_RESET, &regs, REGS_NONE, REGS_NONE);
    print("Ethernet hardware has been reset.");
}


void DoShowInfo()
{
    char macString[18];
    
    UnapiCall(&codeBlock, ETH_GET_HWADD, &regs, REGS_NONE, REGS_MAIN);
    MakeMacString(&regs, macString);
    printf("MAC address: %s\r\n", macString);
    
    UnapiCall(&codeBlock, ETH_GET_NETSTAT, &regs, REGS_NONE, REGS_AF);
    printf("Network link is: %s\r\n", regs.Bytes.A ? strON : strOFF);

    regs.Bytes.B = 0;    
    UnapiCall(&codeBlock, ETH_NET_ONOFF, &regs, REGS_MAIN, REGS_AF);
    printf("Network hardware is: %s\r\n", regs.Bytes.A==1 ? strON : strOFF);

    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, ETH_DUPLEX, &regs, REGS_MAIN, REGS_AF);
    print("Current duplex mode is: ");
    if(regs.Bytes.A == 1) {
        print("Half-duplex\r\n");
    } else if(regs.Bytes.A == 2) {
        print("Full-duplex\r\n");
    } else
        print("Unknown / does not apply\r\n");

    DoGetFilterFlags();
    printf("Promiscuous mode is: %s\r\n", (filterFlags & FILTER_PROMISCUOUS) ? strON : strOFF);
    printf("Boradcast frames are accepted: %s\r\n", (filterFlags & FILTER_BROADCAST) ? strYES : strNO);
    printf("Small frames are accepted: %s\r\n", (filterFlags & FILTER_SMALLFRAMES) ? strYES : strNO);
}


//This is needed because the printf implementation that I found
//does not allow padding numbers with zeros.
//Of course printf("MAC address: %02x:%02x...) would have been much nicer.
void MakeMacString(Z80_registers* regs, char* buffer)
{
    ByteToHexPlusColon(regs->Bytes.L, buffer);
    ByteToHexPlusColon(regs->Bytes.H, buffer+3);
    ByteToHexPlusColon(regs->Bytes.E, buffer+6);
    ByteToHexPlusColon(regs->Bytes.D, buffer+9);
    ByteToHexPlusColon(regs->Bytes.C, buffer+12);
    ByteToHexPlusColon(regs->Bytes.B, buffer+15);
    buffer[17] = 0;
}


void ByteToHexPlusColon(byte value, char* buffer)
{
    byte lowNibble;
    byte highNibble;
    
    lowNibble = value & 0x0F;
    highNibble = (value >> 4) & 0x0F;
    
    buffer[0] = NibbleToHex(highNibble);
    buffer[1] = NibbleToHex(lowNibble);
    buffer[2] = ':';
}


char NibbleToHex(byte value)
{
    if(value<10) {
        return value+'0';
    } else {
        return value-10+'A';
    }
}


void DoChangeMac()
{
    regs.UWords.HL = *(uint*)&(newMac[0]);
    regs.UWords.DE = *(uint*)&(newMac[2]);
    regs.UWords.BC = *(uint*)&(newMac[4]);
    UnapiCall(&codeBlock, ETH_SET_HWADD, &regs, REGS_MAIN, REGS_NONE);
    print("MAC address has been changed.\r\n");
}


void DoEnableDisableNetworking()
{
    regs.Bytes.B = newEnableConfig ^ 3;   //1->2, 2->1
    UnapiCall(&codeBlock, ETH_NET_ONOFF, &regs, REGS_MAIN, REGS_NONE);
    printf("Networking has been %s.\r\n", newEnableConfig==1 ? "disabled" : "enabled");
}


void DoChangeDuplexMode()
{
    regs.Bytes.B = newDuplexConfig;
    UnapiCall(&codeBlock, ETH_DUPLEX, &regs, REGS_MAIN, REGS_NONE);
    printf("%s-duplex mode has been set.\r\n", newDuplexConfig==1 ? "Half" : "Full");
}


void DoGetFilterFlags()
{
    regs.Bytes.B = 128;
    UnapiCall(&codeBlock, ETH_FILTERS, &regs, REGS_MAIN, REGS_AF);
    filterFlags = regs.Bytes.A;
}


void DoUpdateFilterFlags()
{
    DoUpdateOneFilterFlag(newPromiscuousConfig, FILTER_PROMISCUOUS);
    DoUpdateOneFilterFlag(newBroadcastConfig, FILTER_BROADCAST);
    DoUpdateOneFilterFlag(newSmallFrameConfig, FILTER_SMALLFRAMES);
}


void DoUpdateOneFilterFlag(byte newConfigValue, byte filterMask)
{
    if(newConfigValue == 1) {
        filterFlags &= (~filterMask);
    } else if(newConfigValue == 2) {
        filterFlags |= filterMask;
    }
}


void DoWriteFilterFlags()
{
    regs.Bytes.B = filterFlags;
    UnapiCall(&codeBlock, ETH_FILTERS, &regs, REGS_MAIN, REGS_AF);
    print("Filter flags have been modified.\r\n");
}
