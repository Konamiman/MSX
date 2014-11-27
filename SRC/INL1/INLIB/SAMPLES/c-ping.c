/*-------------------------------------------------------
    Ping for InterNestor Lite using ICMP echo functions
    By Konami Man, 12/2004
  -------------------------------------------------------*/

#include "inl.h"
#include <stdio.h>

byte KeyPressed() _naked;


/* Main function */

int main(char** argv, int argc)
{
        char strbuf[16];
        int ercode;
        byte KeyCode;
        EchoInfo sndei;
        EchoInfo rcvei;

        puts("Ping for InterNestor Lite 1.0 using C ICMP echo functions\r\n");
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
		puts("Usage: c-ping <host>");
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
        
        sndei.PeerIP=DNSResult(1);
        printf("OK! Address: %s\r\n\r\n", IPToString(sndei.PeerIP,strbuf));

	
	/* Fill other fields of the EchoInfo structure */

	sndei.TTL=255;
	sndei.ICMPId=10;
	sndei.ICMPSeq=0;
	sndei.DataLen=64;


        /* Main loop */

	while(1)
	{
		WaitInt();
		

		/* Check for incoming echo reply and show information */
		
		if(RcvPING(&rcvei)==0)
		{
			printf("<- Received reply from %s, Seq=%u, ID=%u, TTL=%b, Data size=%u\r\n",
				IPToString(rcvei.PeerIP,strbuf), rcvei.ICMPSeq, rcvei.ICMPId, rcvei.TTL, rcvei.DataLen);
		}
		
		
                /* If Enter is pressed, send an echo reply */

		if((KeyCode=KeyPressed())==0) continue;
		if(KeyCode!=13) return 0;
		
                SendPING(&sndei);		
                printf("-> Echo request sent to %s, Seq=%u, Id=%u\r\n",
			IPToString(sndei.PeerIP, strbuf), sndei.ICMPSeq, sndei.ICMPId);
		
		sndei.ICMPSeq++;
		sndei.ICMPId++;

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
