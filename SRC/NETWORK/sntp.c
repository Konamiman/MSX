/* SNTP client for Ethernet UNAPI
   By Konamiman 2/2010
   v1.1 by Oduvaldo Pavan Junior ( ducasp@gmail.com )
   v1.1 fixes when the count of seconds will end with HH:MM:60 when
   it should be HH:MM+1:00

   Compilation command line:

   sdcc --code-loc 0x180 --data-loc 0 -mz80 --disable-warning 196
        --no-std-crt0 crt0msx_msxdos_advanced.rel printf_simple.rel
       putchar_msxdos.rel asm.lib sntp.c

   hex2bin -e com sntp.ihx

   ASM.LIB, MSXCHAR.REL and crt0msx_msxdos_advanced.rel
   are available at www.konamiman.com

   Comments are welcome: konamiman@konamiman.com
*/

#include <stdio.h>
#include "asm.h"

#define LowerCase(c) ((c) | 32)
#define BUFFER ((byte*)(0x8000))

#define _GENV 0x6B
#define _TERM0 0
#define _SDATE 0x2B
#define _STIME 0x2D

#define SNTP_PORT 123
#define TICKS_TO_WAIT (3*50)
#define SYSTIMER ((uint*)0xFC9E)

#define SECS_IN_MINUTE ((unsigned long)(60))
#define SECS_IN_HOUR ((unsigned long)(SECS_IN_MINUTE * 60))
#define SECS_IN_DAY ((unsigned long)(SECS_IN_HOUR * 24))
#define SECS_IN_MONTH_28 ((unsigned long)(SECS_IN_DAY * 28))
#define SECS_IN_MONTH_29 ((unsigned long)(SECS_IN_DAY * 29))
#define SECS_IN_MONTH_30 ((unsigned long)(SECS_IN_DAY * 30))
#define SECS_IN_MONTH_31 ((unsigned long)(SECS_IN_DAY * 31))
#define SECS_IN_YEAR ((unsigned long)(SECS_IN_DAY * 365))
#define SECS_IN_LYEAR ((unsigned long)(SECS_IN_DAY * 366))
//Secs from 1900-1-1 to 2010-1-1
#define SECS_1900_TO_2010 ((unsigned long)(3471292800))
//Secs from 2036-1-1 0:00:00 to 2036-02-07 6:28:16
#define SECS_2036_TO_2036 ((unsigned long)(3220096))

// Just in case you want to define a faster print function
// for printing plain strings (without formatting).
#define print(x) printf(x)

enum TcpipUnapiFunctions {
    TCPIP_GET_CAPAB = 1,
    TCPIP_DNS_Q = 6,
    TCPIP_DNS_S = 7,
    TCPIP_UDP_OPEN = 8,
    TCPIP_UDP_CLOSE = 9,
    TCPIP_UDP_STATE = 10,
    TCPIP_UDP_SEND = 11,
    TCPIP_UDP_RCV = 12,
    TCPIP_WAIT = 29
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

const char* strPresentation=
    "SNTP time setter for the TCP/IP UNAPI 1.1\r\n"
    "\r\n";

const char* strUsage=
    "Usage: sntp [<host>] [/z <time zone>] [/d] [/v] [/h]\r\n"
    "\r\n"
    "<host>: Name or IP address of the SNTP time server.\r\n"
    "        If nothing is specified, the environment item TIMESERVER will be used.\r\n"
    "/z <time zone>: Formatted as [+|-]hh:mm where hh=00-12, mm=00-59\r\n"
    "    This value will be added or substracted from the received time.\r\n"
    "    The time zone can also be specified in the environment item TIMEZONE.\r\n"
    "/d: Do not change MSX clock, only display the received value\r\n"
    "/v: Verbose mode\r\n"
    "/h: This help\r\n"
    "\r\n"
    "by Oduvaldo\r\n"
    "based on SNTP 1.0 by Konamiman\r\n";

const char* strInvalidParameter = "Invalid parameter(s)";
const char* strNoNetwork = "No network connection available";
const char* strInvalidTimeZone = "Invalid time zone";
const char* strOK = "OK\r\n";

Z80_registers regs;
int i;
int param;
unapi_code_block codeBlock;
int verbose;
int displayOnly;
char paramLetter;
uint conn;
byte* buffer;
int year;
byte month, day, hour, minute, second;
long seconds;
uint timeZoneSeconds;
uint timeZoneHours;
uint timeZoneMinutes;
int ticksWaited;
int sysTimerHold;

byte* timeServerBuffer;
byte timeZoneBuffer[8];
byte paramsBlock[8];

#define PrintIfVerbose(x) if(verbose) {print(x);}

// TODO: move this to ntp.h

void PrintUsageAndEnd();
void SecondsToDate(unsigned long seconds, int* year, byte* month, byte* day, byte* hour, byte* minute, byte* second);
int IsValidTimeZone(byte* timeZoneString);
int IsDigit(char theChar);
void getTime();
int queryTimeServer();
void CheckYear();
void CloseConnection();
void Terminate(char* errorMessage);
char* TimeServerEnv();
char* TimeZoneEnv();

/**********************
 ***  MAIN is here  ***
 **********************/

int main(char** argv, int argc)
{
    char paramLetter;
    int skipNext;
    char* timeZoneString;
    char* timeServerString;

    //* Initialize variables
    skipNext = 0;
    verbose = 0;
    displayOnly = 0;
    timeZoneString = TimeZoneEnv();
    timeServerString = TimeServerEnv();
    buffer = BUFFER;
    conn = 0;

    //* Parse parameters after the host name

    if(argc == 0 && timeServerString[0] == '\0') {
        PrintUsageAndEnd();
    }

    for(param=0; param<argc; param++) {
        if (skipNext == 1) {
            skipNext = 0;
            continue;
        }
        if(argv[param][0] == '/') {
            paramLetter = LowerCase(argv[param][1]);
            if(paramLetter == 'v') {
                verbose = 1;
            } else if(paramLetter == 'd') {
                displayOnly = 1;
            } else if(paramLetter == 'z') {
                timeZoneString = argv[param + 1];
                skipNext = 1;
                if(!IsValidTimeZone(timeZoneString)) {
                    Terminate(strInvalidTimeZone);
                }
            } else if(paramLetter == 'h') {
                PrintUsageAndEnd();
            } else {
                Terminate(strInvalidParameter);
            }
        } else {
          timeServerString = argv[param];
        }
    }

    PrintIfVerbose(strPresentation);

    if(timeServerString[0] == '\0') {
        Terminate("No time server specified and no TIMESERVER environment item was found.");
    }

    if(verbose) {
        printf("Time server is: %s\r\n", timeServerString);
    }

    //* Parse time zone

    if(timeZoneString != NULL) {
        timeZoneHours = (((byte)(timeZoneString[1])-'0')*10) + (byte)(timeZoneString[2]-'0');
        if(timeZoneHours > 12) {
            Terminate(strInvalidTimeZone);
        }

        timeZoneMinutes = (((byte)(timeZoneString[4])-'0')*10) + (byte)(timeZoneString[5]-'0');
        if(timeZoneMinutes > 59) {
            Terminate(strInvalidTimeZone);
        }

        timeZoneSeconds = ((timeZoneHours * (int)SECS_IN_HOUR)) + ((timeZoneMinutes * (int)SECS_IN_MINUTE));
    }

    //* Initialize TCP/IP, close transient UDP connections, open connection for time server port

    i = UnapiGetCount("TCP/IP");
    if(i==0) {
        Terminate("No TCP/IP UNAPI implementations found");
    }
    UnapiBuildCodeBlock(NULL, i, &codeBlock);

    CloseConnection();

    regs.Words.HL = SNTP_PORT;
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_UDP_OPEN, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == ERR_NO_FREE_CONN) {
        Terminate("No free UDP connections available");
    }
    else if(regs.Bytes.A == ERR_CONN_EXISTS) {
        Terminate("There is a resident UDP connection which uses the SNTP port");
    }
    else if(regs.Bytes.A != 0) {
        sprintf(buffer, "Unknown error when opening UDP connection (code %i)", regs.Bytes.A);
        Terminate(buffer);
    }
    conn = regs.Bytes.B;

    //* Resolve the host name

    PrintIfVerbose("Resolving host name... ");

    regs.Words.HL = (int)timeServerString;
    regs.Bytes.B = 0;
    UnapiCall(&codeBlock, TCPIP_DNS_Q, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A == ERR_NO_NETWORK) {
        Terminate(strNoNetwork);
    } else if(regs.Bytes.A == ERR_NO_DNS) {
        Terminate("There are no DNS servers configured");
    } else if(regs.Bytes.A == ERR_NOT_IMP) {
        Terminate("This TCP/IP UNAPI implementation does not support resolving host names.\r\nSpecify an IP address instead.");
    } else if(regs.Bytes.A != (byte)ERR_OK) {
        sprintf(buffer, "Unknown error when resolving the host name (code %i)", regs.Bytes.A);
        Terminate(buffer);
    }

    do {
        UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_NONE, REGS_NONE);
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
            sprintf(buffer, "Unknown error returned by DNS server (code %i)", regs.Bytes.B);
            Terminate(buffer);
        }
    }

    paramsBlock[0] = regs.Bytes.L;
    paramsBlock[1] = regs.Bytes.H;
    paramsBlock[2] = regs.Bytes.E;
    paramsBlock[3] = regs.Bytes.D;

    if(verbose) {
        printf("OK, %i.%i.%i.%i\r\n", paramsBlock[0], paramsBlock[1], paramsBlock[2], paramsBlock[3]);
    }

    getTime();

    //* Parse the obtained time and add the time zone offset

    ((byte*)&seconds)[0]=buffer[43];
    ((byte*)&seconds)[1]=buffer[42];
    ((byte*)&seconds)[2]=buffer[41];
    ((byte*)&seconds)[3]=buffer[40];

    if(verbose) {
        SecondsToDate(seconds, &year, &month, &day, &hour, &minute, &second);
        CheckYear();
        printf("Time returned by time server: %i-%i-%i, %i:%i:%i\r\n", year, month, day, hour, minute, second);
    }

    if(timeZoneString != NULL) {
        if(timeZoneString[0] == '-') {
            seconds -= timeZoneSeconds;
        } else {
            seconds += timeZoneSeconds;
        }
    }

    SecondsToDate(seconds, &year, &month, &day, &hour, &minute, &second);
    CheckYear();
    if(verbose && timeZoneString != NULL) {
        printf("Time adjusted to time zone:   %i-%i-%i, %i:%i:%i\r\n", year, month, day, hour, minute, second);
    }

    //* Change the MSX clock if necessary

    if(displayOnly) {
        if(!verbose) {
            printf("Time obtained from time server: %i-%i-%i, %i:%i:%i\r\n", year, month, day, hour, minute, second);
        }
    } else {
        regs.UWords.HL = year;
        regs.Bytes.D = month;
        regs.Bytes.E = day;
        DosCall(_SDATE, &regs, REGS_MAIN, REGS_AF);
        if(regs.Bytes.A != 0) {
            Terminate("Invalid date for the MSX clock");
        }

        regs.Bytes.H = hour;
        regs.Bytes.L = minute;
        regs.Bytes.D = second;
        DosCall(_STIME, &regs, REGS_MAIN, REGS_AF);
        if(regs.Bytes.A != 0) {
            Terminate("Invalid time for the MSX clock");
        }

        if(verbose) {
            print("The clock has been set to the adjusted time.");
        } else {
            printf("The clock has been set to: %i-%i-%i, %i:%i:%i\r\n", year, month, day, hour, minute, second);
        }
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
    print(strUsage);
    DosCall(0, &regs, REGS_MAIN, REGS_NONE);
}

char* TimeServerEnv()
{
  timeServerBuffer = BUFFER;
  timeServerBuffer[0] = '\0';
  regs.Words.HL = (int)"TIMESERVER";
  regs.Words.DE = (int)timeServerBuffer;
  regs.Bytes.B = 255;
  DosCall(_GENV, &regs, REGS_MAIN, REGS_AF);

  return timeServerBuffer;
}

char* TimeZoneEnv()
{
  timeZoneBuffer[0] = '\0';
  regs.Words.HL = (int)"TIMEZONE";
  regs.Words.DE = (int)timeZoneBuffer;
  regs.Bytes.B = 8;
  DosCall(_GENV, &regs, REGS_MAIN, REGS_AF);
  if(timeZoneBuffer[0] != (unsigned char)'\0' && IsValidTimeZone(timeZoneBuffer)) {
      return timeZoneBuffer;
  }
  return '\0';
}

void getTime()
{
    int retries;
    int queryErrorCode;
    int currentTry;

    retries = 1;
    currentTry = 0;

    PrintIfVerbose("Querying the time server...");

    do {
        PrintIfVerbose(".");
        currentTry++;
        queryErrorCode = queryTimeServer();
    } while (queryErrorCode != 0 && currentTry <= retries);

    switch(queryErrorCode) {
        case 1 :
            sprintf(buffer, "Unknown error when sending request to time server (code %i)", regs.Bytes.A);
            Terminate(buffer);
            break;
        case 2 :
            sprintf(buffer, "Unknown error when waiting a reply from the time server (code %i)", regs.Bytes.A);
            Terminate(buffer);
            break;
        case 3 :
            Terminate("The server returned a too short packet");
            break;
        case 4 :
            Terminate("The server returned a \"Kiss of death\" packet\r\n(are you querying the server too often?)");
            break;
    }
}

int queryTimeServer()
{
    //* Open a new UDP connection and send request
    *buffer=0x1B;
    for(i=1; i<48; i++) {
        buffer[i]=0;
    }

    paramsBlock[4] = SNTP_PORT;
    paramsBlock[5] = 0;
    paramsBlock[6] = 48;
    paramsBlock[7] = 0;

    regs.Bytes.B = conn;
    regs.Words.HL=(int)buffer;
    regs.Words.DE=(int)paramsBlock;

    UnapiCall(&codeBlock, TCPIP_UDP_SEND, &regs, REGS_MAIN, REGS_MAIN);
    if(regs.Bytes.A != 0) {
        return 1;
    }

    //* Wait for a reply and check that it is correct
    ticksWaited = 0;
    do {
        sysTimerHold = *SYSTIMER;

        UnapiCall(&codeBlock, TCPIP_WAIT, &regs, REGS_MAIN, REGS_NONE);
        while(*SYSTIMER == sysTimerHold);

        ticksWaited++;
        if(ticksWaited >= TICKS_TO_WAIT) {
            break;
        }
        regs.Bytes.B = conn;
        regs.Words.HL = (int)buffer;
        regs.Words.DE = 48;
        UnapiCall(&codeBlock, TCPIP_UDP_RCV, &regs, REGS_MAIN, REGS_MAIN);
    } while(regs.Bytes.A == ERR_NO_DATA);

    if(regs.Bytes.A != 0) {
        return 2;
    }

    if(regs.UWords.BC < 48) {
        return 3;
    }

    if(buffer[1] == 0) {
        return 4;
    }

    PrintIfVerbose(strOK);

    if(buffer[0] & 0xC0 == 0xC0 && verbose) {
        print("WARNING: Error returned by server: clock is not synchronized\r\n");
    }

    return 0;
}

void SecondsToDate(unsigned long seconds, int* year, byte* month, byte* day, byte* hour, byte* minute, byte* second)
{
    int IsLeapYear = 0;
    unsigned long SecsInCurrentMoth;
    unsigned long SecsPerMonth[12];

    SecsPerMonth[0]=SECS_IN_MONTH_31;
    SecsPerMonth[1]=SECS_IN_MONTH_28;
    SecsPerMonth[2]=SECS_IN_MONTH_31;
    SecsPerMonth[3]=SECS_IN_MONTH_30;
    SecsPerMonth[4]=SECS_IN_MONTH_31;
    SecsPerMonth[5]=SECS_IN_MONTH_30;
    SecsPerMonth[6]=SECS_IN_MONTH_31;
    SecsPerMonth[7]=SECS_IN_MONTH_31;
    SecsPerMonth[8]=SECS_IN_MONTH_30;
    SecsPerMonth[9]=SECS_IN_MONTH_31;
    SecsPerMonth[10]=SECS_IN_MONTH_30;
    SecsPerMonth[11]=SECS_IN_MONTH_31;

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

     while(seconds >= SECS_IN_MINUTE) {
         seconds -= SECS_IN_MINUTE;
         *minute = (byte)(*minute + 1);
     }

     //* The remaining are the seconds

     *second = (byte)seconds;
}


int IsValidTimeZone(byte* timeZoneString)
{
    if(!(timeZoneString[0]==(byte)'+' || timeZoneString[0]==(byte)'-')) {
        return 0;
    }

    if(!(IsDigit(timeZoneString[1]) && IsDigit(timeZoneString[2]) && IsDigit(timeZoneString[4]) && IsDigit(timeZoneString[5])))
    {
        return 0;
    }

    if(timeZoneString[3] != (byte)':' || timeZoneString[6] != 0)
    {
        return 0;
    }

    return 1;
}


int IsDigit(char theChar)
{
    return (theChar>='0' && theChar<='9');
}


void Terminate(char* errorMessage)
{
    if(errorMessage != NULL) {
        if(verbose) {
            printf("\r\n*** ERROR: %s\r\n", errorMessage);
        } else {
            printf("*** SNTP ERROR: %s\r\n", errorMessage);
        }
    }

    CloseConnection();

    DosCall(_TERM0, &regs, REGS_NONE, REGS_NONE);
}


void CheckYear()
{
    if(year < 2010) {
        Terminate("The server returned a date that is before year 2010");
    }

    if(year > 2079) {
        Terminate("The server returned a date that is after year 2079");
    }
}

void CloseConnection()
{
    regs.Bytes.B = conn;
    UnapiCall(&codeBlock, TCPIP_UDP_CLOSE, &regs, REGS_MAIN, REGS_NONE);

    if(regs.Bytes.A == ERR_NOT_IMP) {
        Terminate("This TCP/IP UNAPI implementation does not support UDP connections");
    }
}
