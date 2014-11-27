/*-------------------------------------------------------------------
    Ping for InterNestor Lite using raw packet management functions
    By Konami Man, 12/2004
  -------------------------------------------------------------------*/

#include "inl.h"
#include <stdio.h>

#define BUF_IPLOCAL 0x8000         /* Refers to INL data segment */

byte KeyPressed() _naked;
#define netinc(x) x=hton(ntoh(x)+1)     /* Increase an integer stored in network byte order */


/* These structures represent IP and ICMP headers,
   see RFC791 and RFC792 for details */

typedef struct {
        byte VersionIHL;
        byte ToS;
        uint Length;
        uint Id;
        uint FragOffset;
        byte TTL;
        byte Proto;
        uint Checksum;
        ip_address SourceIP;
        ip_address DestIP;
        } IPHeader;

typedef struct {
        byte Type;
        byte Code;
        uint Checksum;
        uint Id;
        uint Seq;
        } ICMPHeader;

typedef struct {
        IPHeader IP;
        ICMPHeader ICMP;
        } PingPacket;


/* Main function */

int main(char** argv, int argc)
{
        byte ercode;
        char strbuf[16];
        byte KeyCode;
        uint RcvSize;
        byte RequestedProto;
        PingPacket PingSend;
        PingPacket* PingRcv=(PingPacket*)0x8000;
        RawRcvInfo rcvinfo;

        puts("Ping for InterNestor Lite 1.0 using C raw packet management functions\r\n");
        puts("By Konami Man, 12/2004\r\n\r\n");


	/* Initialize INL and check various conditions */

	if(INLInit()==0)
	{
		puts("*** INL is not installed.");
		return 0;
	}

	if(INLState(INLSTAT_QUERY)!=INLSTAT_ACTIVE)
        {
                puts("*** INL is paused.");
                return 0;
        }

        if(NetworkState()!=NETSTAT_READY)
        {
                puts("*** Network not available.");
                return 0;
        }

        if(argc<1)
	{
		puts("Usage: c-rping <host>");
		return 0;
	}
        
        
        /* Resolve the specified host name */
        
        puts("Resolving host name... ");
        ercode=DNSQuery(argv[0],0);
        if(ercode!=DNSQ_SUCCESS)
        {
                printf("*** Error from DNS_Q: %d", ercode);
                return 0;
        }
        
        while(((ercode=DNSState()) & 0xFF00) == DNSS_IN_PROGRESS)
        {
                WaitInt();
        }
        
        if((ercode & 0xFF00) == DNSS_ERROR)
        {
                printf("*** Error from DNS_S: %d", ercode & 0xFF);
                return 0;
        }
        

        /* Store and show the obtained IP address */
        
        PingSend.IP.DestIP=DNSResult(1);
        printf("OK! Address: %s\r\n\r\n", IPToString(PingSend.IP.DestIP, strbuf));


        /* Obtain the local IP address from INL's data segment */
        
        INLCopyData(BUF_IPLOCAL, &(PingSend.IP.SourceIP), 4, INLC_INL_TO_TPA);
        
        
        /* Fill other fields of PingSend */
        
        PingSend.IP.VersionIHL=0x45;
        PingSend.IP.ToS=0;
        PingSend.IP.Length=hton(sizeof(PingPacket));
        PingSend.IP.Id=0;       /* To be strict: hton(0); */
        PingSend.IP.FragOffset=0;       /* hton(0); */
        PingSend.IP.TTL=255;
        PingSend.IP.Proto=IPPROTO_ICMP;
        
        PingSend.ICMP.Type=8;   /* Echo request type */
        PingSend.ICMP.Code=0;
        PingSend.ICMP.Id=0;     /* hton(0); */
        PingSend.ICMP.Seq=0;    /* hton(0); */

        puts("\r\n*** Press Enter to send echo requests, any other key to exit\r\n\r\n");
        

        /* Clear any possible old capture */

        rcvinfo.Datagram=PingRcv;
        RcvRaw(&rcvinfo);

        
        /* Main loop */
        
        while(1) {

        WaitInt();


        /* If there is a captured packet available, retrieve it and show info */
        
        switch(ControlRaw(RAWC_QUERY_STAT, &RcvSize, &RequestedProto))
        {
                case RAWC_CAPTURE_PENDING: break;
                
                case RAWC_CAPTURED:
                        rcvinfo.Datagram=PingRcv;
                        RcvRaw(&rcvinfo);
                        if(PingRcv->ICMP.Type==0)       /* Ignore packet if it is not echo reply */
                        {
                               printf("<- Received reply (%d bytes), from %s, IP Id=%u, ICMP Seq=%u, TTL=%b\r\n",
                                        RcvSize, IPToString(PingRcv->IP.SourceIP,strbuf),
                                        ntoh(PingRcv->IP.Id), ntoh(PingRcv->ICMP.Seq), PingRcv->IP.TTL);
                        }
                
                        /* No "break" here on purpose */
                
                case RAWC_NO_CAPTURE:
			RequestedProto=IPPROTO_ICMP;
                        ControlRaw(RAWC_REQUEST_CAP, &RcvSize, &RequestedProto);
                        break;
                
                default:        /* Anything else can be an error only */
                        puts("\r\n***Error: Network connection lost");
                        return 0;
        }
        

        /* If Enter is pressed, send ping packet */
        
        if((KeyCode=KeyPressed())==0) continue;
        if(KeyCode!=13) return 0;
        
        PingSend.ICMP.Checksum=0;       /* Note that hton is not necessary for checksums */
        PingSend.ICMP.Checksum=CalcChecksum(&(PingSend.ICMP), sizeof(ICMPHeader));
        PingSend.IP.Checksum=0;
        PingSend.IP.Checksum=CalcChecksum(&PingSend, sizeof(PingPacket));
        
        SendRaw(&PingSend, sizeof(PingPacket));
        printf("-> Sent ping with IP Id=%u, ICMP Seq=%u\r\n", ntoh(PingSend.IP.Id), ntoh(PingSend.ICMP.Seq));
        netinc(PingSend.IP.Id);
        netinc(PingSend.ICMP.Seq);
        
        } /* while(1) */

} /* End of main */


/* This function returns the code of the key being pressed, or 0 if no key is being pressed */

byte KeyPressed() _naked
{
	_asm
	ld	c,#6
	ld	e,#0xFF
	jp	5
	_endasm;
}
