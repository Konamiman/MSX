/*--------------------------------------------------------
    DNS querier for InterNestor Lite using UDP functions
    By Konami Man, 12/2004
  --------------------------------------------------------*/

/*
This program will query a name server for all the data available for a given host.
Please read RFC1035 for details about the packet format.
*/

#include "inl.h"
#include <stdio.h>
#include <stdlib.h>


/* Recognized resource record types */

#define RR_A 1
#define RR_NS 2
#define RR_MD 3
#define RR_MF 4
#define RR_CNAME 5
#define RR_SOA 6
#define RR_MB 7
#define RR_MG 8
#define RR_MR 9
#define RR_NULL 10
#define RR_WKS 11
#define RR_PTR 12
#define RR_HINFO 13
#define RR_MINFO 14
#define RR_MX 15
#define RR_TXT 16


/* Global variables */

uint* PacketBufferW = (uint*)0x8000;
byte* PacketBufferB = (byte*)0x8000;
char strbuf[16];


/* Auxiliary functions declaration */

byte* PrintCompressedString(byte* string);
byte* PrintLabel(byte* label);
byte* PrintRR(byte* RRpnt, byte number);


/* Main function */

int main(char** argv, int argc)
{
        int ercode;
        UDPInfo udpi;
        byte LabelLength;
        char* LabelIN;
        char* LabelOUT;
        char* LabelOUTsave;
        char* WalkPointer;
        byte TimeWaiting;
        uint Counter;
	uint Entries;

        puts("DNS querier for InterNestor Lite 1.0 using C functions\r\n");
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

        if(argc<2)
	{
		puts("Usage: c-dns <name server address> <host name> [<QTYPE>]\r\n");
		puts("       Default for Query Type is 255 (all records), see RFC1035 for details");
		return 0;
	}
        

        /* Clear the UDP buffer */

        udpi.Data=NULL;
        while(RcvUDP(&udpi)==0);

        
        /* Resolve the DNS server name */
        
        puts("Resolving DNS server name... ");
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
        
        udpi.PeerIP=DNSResult(1);
        printf("OK! Address: %s\r\n\r\n", IPToString(udpi.PeerIP, strbuf));


        /* Compose the query packet header */

        PacketBufferW[0]=hton(34);       /* Message Id */
        PacketBufferW[1]=hton(256);      /* Recursion required */
        PacketBufferW[2]=hton(1);        /* QDCOUNT */
        PacketBufferW[3]=hton(0);        /* ANCOUNT */
        PacketBufferW[4]=hton(0);        /* NSCOUNT */
        PacketBufferW[5]=hton(0);        /* ARCOUNT */


        /* Compose the question section, we must convert the format "text.text.text" 0
           to length "text" length "text" length "text" 0 */
        
        LabelIN=argv[1];
        LabelOUT=PacketBufferB+12+1;    /* Start of packet's question section */
        LabelOUTsave=PacketBufferB+12;
        
        while(1)
        {
                LabelLength=0;
                while(!(*LabelIN=='.' || *LabelIN==0))
                {
                        *LabelOUT++=*LabelIN++;
                        LabelLength++;
                }
                *LabelOUTsave=LabelLength;
                if(*LabelIN==0) break;
                LabelOUTsave=LabelOUT++;
                LabelIN++;
        }
        *LabelOUT++=0;
        
        ((uint*)LabelOUT)[0]=hton(argc=2 ? 255 : atoi(argv[2]));       /* QTYPE */
        ((uint*)LabelOUT)[1]=hton(1);         /* QCLASS */
        
        
        /* Send the query packet */
        
        udpi.DestPort=53;       /* DNS service port */
        udpi.SrcPort=1034;
        udpi.Data=PacketBufferB;
        udpi.DataLen=(uint)&(((uint*)LabelOUT)[2])-(uint)PacketBufferB;
        
        SendUDP(&udpi);
        
        
        /* Wait the reply up to 3 seconds */
        
        puts("Query sent, waiting for reply... ");
        
        TimeWaiting=0;
        while(1)
        {
                WaitInt();
                if((RcvUDP(&udpi)==0) && (udpi.SrcPort==53) && (udpi.DestPort==1034) &&
                   (ntoh(PacketBufferW[0])==34) && ((ntoh(PacketBufferW[1]) & 0x8000)==0x8000))
                {
                        if((PacketBufferW[1] & 0x0F00)!=0)
                        {
                                printf("*** Error returned by server: %b", ntoh(PacketBufferW[1] & 0x0F00));
                                return 0;
                        }
                        else break;
                }
                if(++TimeWaiting>=60*3)
                {
                        puts("*** Error: no reply received");
                        return 0;
                }
        }
        
        puts("Ok!\r\n\r\n");
        if((ntoh(PacketBufferW[1]) & 512)==512) puts("*** WARNING: The reply is truncated\r\n\r\n");
        if((ntoh(PacketBufferW[1]) & 128)==0) puts("*** WARNING: The server does not support recursive queries\r\n\r\n");

        /* Skip the question section */
        
        WalkPointer=PacketBufferB+12;
	puts("Qeuried host: ");
	WalkPointer=PrintCompressedString(WalkPointer);
        WalkPointer+=4;         /* Skip QTYPE and QCLASS */
        
        
        /* Print all the remaining sections */
        
        printf(">>> ANSWER section: %u entries\r\n\r\n", Entries=ntoh(PacketBufferW[3]));
        
        for(Counter=1; Counter<=Entries; Counter++)
        {
                WalkPointer=PrintRR(WalkPointer, Counter);
        }
        
        
        printf(">>> NAME SERVERS section: %u entries\r\n\r\n", Entries=ntoh(PacketBufferW[4]));
        
        for(Counter=1; Counter<=Entries; Counter++)
        {
                WalkPointer=PrintRR(WalkPointer, Counter);
        }


        printf(">>> ADDITIONAL section: %u entries\r\n\r\n", Entries=ntoh(PacketBufferW[5]));
        
        for(Counter=1; Counter<=Entries; Counter++)
        {
                WalkPointer=PrintRR(WalkPointer, Counter);
        }


        /* All data has been displayed, finish */
        
        puts("\r\nDone.");

        return 0;

} /* End of main */


/* Auxiliary functions */

/* This function prints a compressed string, and then prints two CRLF.
   The input is the string pointer, the returned value is the updated string pointer. */

byte* PrintCompressedString(byte* stringpnt)
{
	uint* uintpnt;

        while(*stringpnt!=0)
        {
                if((*stringpnt & 0xC0) == 0xC0)        /* Compressed? */
                {
			uintpnt=(uint*)stringpnt;
                        PrintCompressedString(PacketBufferB+(ntoh(*uintpnt & 0xFF3F)));
			return stringpnt+2;
                }
                stringpnt=PrintLabel(stringpnt);
                if(*stringpnt!=0) putchar('.');
        }
        puts("\r\n\r\n");
        return stringpnt+1;
}


/* This function prints a label with format length "label",
   returns the updated pointer */

byte* PrintLabel(byte* label)
{
        byte length;

	length=*((byte*)label++);
        while(length--) putchar(*((char*)label++));
        return label;
}

        
/* This function prints out the information for a RR,
   returns the updated RR pointer */
   
byte* PrintRR(byte* RRpnt, byte number)
{
        uint length;
        uint RRType;

        char* RRTypes[]={"A","NS","MD","MF","CNAME","SOA","MB","MG","MR","NULL","WKS","PTR","HINFO","MINFO","MX","TXT"};
        
        printf("++ Resource Record %b\r\n\r\n", number);

        /* Print basic information */
        
        puts("- Name: ");
        RRpnt=PrintCompressedString(RRpnt);
        if(((RRType=ntoh(*((uint*)RRpnt)))>16) || (RRType==0))
                printf("- Type: unknown (code %u)\r\n\r\n", RRType);
        else
                printf("- Type: %s\r\n\r\n", RRTypes[RRType-1]);
        RRpnt+=4;       /* Skip TYPE and CLASS */
        /*printf("- TTL: %l\r\n\r\n", ntohl(*((ulong*)RRpnt)));*/
        RRpnt+=4;       /* Skip TTL */
        
        length=ntoh(*((uint*)RRpnt));
        RRpnt+=2;       /* Skip RDLENGTH */
        
        printf("- Length: %u\r\n\r\n", length);
        
        /* Print RR-specific information */
        
        switch(RRType)
        {
                case RR_A:
                        printf("- IP address: %s\r\n\r\n", IPToString(*((ip_address*)RRpnt), strbuf));
                        return RRpnt+4;

                case RR_HINFO:
                        puts("- CPU: ");
			RRpnt=PrintLabel(RRpnt);
                        puts("\r\n\r\n- OS: ");
			RRpnt=PrintLabel(RRpnt);
			puts("\r\n\r\n");
			return RRpnt;

                case RR_MINFO:
                        puts("- RMAILBX: ");
                        RRpnt=PrintCompressedString(RRpnt);
                        puts("- EMAILBX: ");
                        return(RRpnt=PrintCompressedString(RRpnt));

                case RR_MX:
                        printf("- Preference: %u\r\n\r\n- Exchange: ", ntoh(*((uint*)RRpnt)));
                        RRpnt+=2;
                        return(RRpnt=PrintCompressedString(RRpnt));

                case RR_SOA:
                        puts("- MNAME: ");
                        RRpnt=PrintCompressedString(RRpnt);
                        puts("- RNAME: ");                        
                        RRpnt=PrintCompressedString(RRpnt);
                        /*printf("- Serial: %l\r\n\r\n", *((ulong*)RRpnt));
                        RRpnt+=4;
                        printf("- Refresh: %l\r\n\r\n", *((ulong*)RRpnt));
                        RRpnt+=4;
                        printf("- Retry: %l\r\n\r\n", *((ulong*)RRpnt));
                        RRpnt+=4;
                        printf("- Expire: %l\r\n\r\n", *((ulong*)RRpnt));
                        RRpnt+=4;
                        printf("- Minimum: %l\r\n\r\n", *((ulong*)RRpnt));
                        return RRpnt+4;*/
                        return RRpnt+20;
                        
                case RR_MB:
                case RR_MD:
                case RR_MF:
                case RR_CNAME:
                case RR_MG:
                case RR_MR:
                case RR_NS:                
                case RR_PTR:                
                        puts("- Name/text: ");
                        return (RRpnt=PrintCompressedString(RRpnt));

                case RR_TXT:
                	RRpnt=PrintLabel(RRpnt);
			puts("\r\n\r\n");
                	return RRpnt;
                
                default:
                        return RRpnt+length;
                        
        }
}
