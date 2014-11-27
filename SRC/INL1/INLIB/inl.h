/****************************************************
Header file for the InterNestor Lite library for SDCC
Version 1.0
By Konami Man, 12-2004
*****************************************************/

#ifndef __INL_H
#define __INL_H 1


/************************
 *   Type definitions   *
 ************************/

#ifndef uint
typedef unsigned int uint;
#endif

#ifndef ulong
typedef unsigned long ulong;
#endif

#ifndef byte
typedef unsigned char byte;
#endif

#ifndef NULL
#define NULL ((void*)0)
#endif

typedef unsigned long ip_address;

typedef unsigned char TCPHandle;

typedef struct {
        void* Src;
        void* Dest;
        uint Size;
        byte Final;
        long Cummulated;
} B64Info;

typedef struct {
        ip_address PeerIP;
        byte TTL;
        uint ICMPId;
        uint ICMPSeq;
        uint DataLen;
} EchoInfo;

typedef struct {
        ip_address PeerIP;
        uint DestPort;
        uint SrcPort;
        void* Data;
        uint DataLen;
} UDPInfo;

typedef struct {
        ip_address PeerIP;
        uint DestPort;
        uint SrcPort;
        byte Passive;
        uint Timer;
} TCPOpenInfo;

typedef struct {
        byte State;
        uint IncomingUsed;
        uint OutgoingFree;
        uint ReTXUsed;
        void* TCBAddress;
        byte CloseCause;
} TCPStateInfo;

typedef struct {
        ip_address PeerIP;
        byte Protocol;
        byte TTL;
        byte ToS;
        void* Data;
        uint DataLen;
} IPInfo;

typedef struct {
        uint IPHeaderLen;
        uint DataLen;
        uint TotalLen;
        void* Datagram;
        void* DataPart;
} RawRcvInfo;


/****************************
 *   Constant definitions   *
 ****************************/

/* Error codes for B64 functions */

#define B64E_INV_BLOCK_SIZE 1
#define B64E_INV_TOTAL_SIZE 2 /* B64Decode only */
#define B64E_INV_CHAR 3 /* B64Decode only */


/* Directions for INLCopyData */

#define INLC_INL_TO_TPA 0
#define INLC_TPA_TO_INL 1


/* Action/results for INLState */

#define INLSTAT_QUERY 0
#define INLSTAT_PAUSE 1
#define INLSTAT_ACTIVE 2


/* Results from NetworkState */

#define NETSTAT_UNAVAILABLE 0
#define NETSTAT_OPENING 1
#define NETSTAT_READY 2
#define NETSTAT_CLOSING 3


/* Flags for DNSQuery */

#define DNSF_ABORT_QUERY_ONLY 1
#define DNSF_ADDRESS_IS_IP 2
#define DNSF_NOT_ABORT_EXISTING 4


/* Error codes for DNSQuery */

#define DNSQ_SUCCESS 0
#define DNSQ_ERR_NO_NETWORK 1
#define DNSQ_ERR_QUERY_IN_PROGRESS 2
#define DNSQ_ERR_INVALID_IP 3
#define DNSQ_ERR_NO_SERVERS 4


/* Base status codes for DNSState */

#define DNSS_NO_STATE 0
#define DNSS_IN_PROGRESS 0x0100
#define DNSS_COMPLETED 0x0200
#define DNSS_ERROR 0x0300


/* Error codes for DNSState */

#define DNSS_ERR_INVALID_PACKET 1
#define DNSS_ERR_SERVER_FAILURE 2
#define DNSS_ERR_NAME_NOT_EXISTS 3
#define DNSS_ERR_UNSUPPORTED_QUERY 4
#define DNSS_ERR_QUERY_REJECTED 5
#define DNSS_ERR_UNRESPONSIVE_SERVER 16
#define DNSS_ERR_TIMEOUT 17
#define DNSS_ERR_USER_ABORTED 18
#define DNSS_ERR_NETWORK_LOST 19
#define DNSS_ERR_DEAD_END_ANSWER 20
#define DNSS_ERR_TRUNCATED_ANSWER 21


/* Error codes for TCPOpen */

#define TCPO_ERR_BASE 128
#define TCPO_ERR_TOO_MANY_CONNS (1+128)
#define TCPO_ERR_NO_NETWORK (2+128)
#define TCPO_ERR_CONN_EXISTS (3+128)
#define TCPO_ERR_INV_IP_FOR_ACTIVE (4+128)
#define TCPO_ERR_INV_TIMER (5+128)


/* Error codes for other TCP functions */

#define TCP_ERR_INVALID_HANDLE 1
#define TCP_ERR_CONN_CLOSED 2
#define TCP_ERR_CANT_SEND 3 /*TCPSend only*/
#define TCP_ERR_BUFFER_FULL 4 /*TCPSend only*/


/* TCP state codes */

#define TCPS_CLOSED 0
#define TCPS_LISTEN 1
#define TCPS_SYN_SENT 2
#define TCPS_SYN_RECEIVED 3
#define TCPS_ESTABLISHED 4
#define TCPS_FIN_WAIT_1 5
#define TCPS_FIN_WAIT_2 6
#define TCPS_CLOSE_WAIT 7
#define TCPS_CLOSING 8
#define TCPS_LAST_ACK 9
#define TCPS_TIME_WAIT 10


/* Causes for TCP connection close */

#define TCPCC_CONN_NEVER_USED 0
#define TCPCC_LOCAL_CLOSE 1
#define TCPCC_LOCAL_ABORT 2
#define TCPCC_REMOTE_ABORT 3
#define TCPCC_USER_TIMER_EXP 4
#define TCPCC_CONN_TIMER_EXP 5
#define TCPCC_NETWORK_LOST 6


/* Error codes for SendRaw and SendIP */

#define RAWS_SUCCESS 0
#define RAWS_NO_NETWORK 1
#define RAWS_INVALID_SIZE 2


/* Action codes for ControlRaw */

#define RAWC_QUERY_STAT 0
#define RAWC_REQUEST_CAP 1
#define RAWC_CANCEL_CAP 2


/* Return codes for ControlRaw */

#define RAWC_ERR_BASE 128
#define RAWC_ERR_NO_NETWORK (1+128)
#define RAWC_ERR_INV_ACTION (2+128)
#define RAWC_NO_CAPTURE 0
#define RAWC_CAPTURE_PENDING 1
#define RAWC_CAPTURED 2


/* Return codes for RcvRaw */

#define RAWR_SUCCESS 0
#define RAWR_NO_PACKETS 1


/* Some IP protocols for "raw" functions */

#define IPPROTO_ICMP 1
#define IPPROTO_IP 4
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17
#define IPPROTO_ALL 0
#define IPPROTO_ALL_NON_INL 255


/*****************************
 *   Function declarations   *
 *****************************/

/* INL control */

byte INLInit();
long INLVersion();
byte INLState(byte action);
byte NetworkState();
byte WaitInt();
uint INLGetData(void* address);
void INLSetByte(void* address, byte data);
void INLSetWord(void* address, uint data);
void INLCopyData(void* source, void* destination, uint length, byte direction);


/* Data manipulation */

uint hton(uint value);
#define ntoh(x) hton(x)
ulong htonl(ulong value);
#define ntohl(x) htonl(x)
char* IPToString(ip_address ip,char* buffer);
byte CalcMD5(void* source, void* dest, uint length);
uint CalcChecksum(void* source, uint length);
void B64Init(byte linelength);
byte B64Encode(B64Info* info);
byte B64Decode(B64Info* info);


/* Name resolution */

byte DNSQuery(char* host, byte flags);
uint DNSState();
ip_address DNSResult(byte clear);


/* Echo (PING) */

byte SendPING(EchoInfo* info);
byte RcvPING(EchoInfo* info);


/* UDP */

byte SendUDP(UDPInfo* info);
byte RcvUDP(UDPInfo* info);


/* TCP */

TCPHandle TCPOpen(TCPOpenInfo* info);
byte TCPClose(TCPHandle handle);
byte TCPAbort(TCPHandle handle);
byte TCPSend(TCPHandle handle, void* data, uint length, byte push);
byte TCPRcv(TCPHandle handle, void* data, uint* length);
byte TCPStatus(TCPHandle handle, TCPStateInfo* info);
byte TCPFlush(TCPHandle handle);


/* Raw packets */

byte SendIP(IPInfo* info);
byte SendRaw(void* packet, uint length);
byte ControlRaw(byte action, uint* size, byte* proto);
byte RcvRaw(RawRcvInfo* info);


/***************************************
 Basic routine for calling INL functions
 Usage: call _CALL_INL
        dw routine

 It is placed here instead of in inl_base.asm,
 to assure that it is assembled on page 0, before the program code
 (we assume that this file will be #include'd before the code).
 If it were placed on inl_base.asm, it would be assembled
 after the program code, so it could appear on page 1,
 and thus it would not work (segment switching is made on page 1).
****************************************/

void CALL_INL() _naked
{
        _asm
        exx
        ex      af,af
        ld      a,(_INL_SEG1)
        call    #_INL_PUT_P1
        pop     hl      ;Return address
        ld      e,(hl)  ;DE=Routine to call
        inc     hl
        ld      d,(hl)
        ex      de,hl   ;Now DE=return address, HL=routine to call
        ld      (#RUT_DIR+1),hl
        inc     de      ;Skip routine address
        push    de
        ex      af,af
        exx
RUT_DIR:        call    0
        ex      af,af
        ld      a,#1
        call    #_INL_PUT_P1
        ex      af,af
        ret
        _endasm;
}

/* We need INL_PUT_P1 and INL_SEG1 to be global, since
   these are initialized by INLInit on inl_base.asm.
   Therefore we define them as separate fake functions. */

void INL_PUT_P1() _naked
{
        _asm
        .ds     3
        _endasm;
}

void INL_SEG1() _naked
{
        _asm
        .ds     1
        _endasm;
}

#endif  /*defined __INL_H */
