/*--------------------------------------------------------
    TCP console for InterNestor Lite using TCP functions
    By Konami Man, 12/2004
  --------------------------------------------------------*/

/*
This program will open a TCP connection to the specified port of the specified host,
then anything that you write will be sent to the connection and any data received will be sent to the screen.
There is no local echo when typing.
*/

#include "inl.h"
#include <stdio.h>
#include <stdlib.h>

byte KeyPressed() _naked;


/* Main function */

int main(char** argv, int argc)
{
        char strbuf[16];
        int ercode;
        byte KeyCode;
        TCPOpenInfo openinfo;
        TCPStateInfo stateinfo;
        TCPHandle tcph;
        uint DataLength;
        int i;

        puts("TCP console for InterNestor Lite 1.0 using C functions\r\n");
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
		puts("Usage: c-tcpcon <host> <port>");
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
        
        openinfo.PeerIP=DNSResult(1);
        printf("OK! Address: %s\r\n\r\n", IPToString(openinfo.PeerIP, strbuf));


        /* Open the TCP connection */
        
        openinfo.DestPort=atoi(argv[1]);
        openinfo.SrcPort=0xFFFF;        /* Random local port number */
        openinfo.Passive=0;
        openinfo.Timer=0;
	
	tcph=TCPOpen(&openinfo);
	if(tcph>TCPO_ERR_BASE)
	{
	        printf("*** Error when opening connection: %b", tcph-128);
	        return 0;
	}
	
	puts("Opening connection... ");
	

        /* Wait until the connection is established */
        
        do
        {
                WaitInt();
                TCPStatus(tcph, &stateinfo);
                if(stateinfo.State==TCPS_CLOSED)
                {
                        printf("*** Connection lost. Cause: %b", stateinfo.CloseCause);
                        return 0;
                }
        } while(stateinfo.State!=TCPS_ESTABLISHED);
        
	puts("Ok!\r\n\r\n*** Press ESC to exit\r\n\r\n");
        

        /* Main loop */
        
        while(1)
        {
        
        WaitInt();
        

        /* Check for incoming data and print it */
        
        DataLength=1024;
        TCPRcv(tcph, 0x8000, &DataLength);
        for(i=0;i<DataLength;i++)
        {
                putchar(((char*)0x8000)[i]);
        }
        

        /* Check for key pressing and send its code;
           if the code is 13, send also 10 (CRLF sequence) */
        
        KeyCode=KeyPressed();
        if(KeyCode!=0)
        {
                *((char*)0x8000)=KeyCode;
                *((char*)0x8001)=10;
                TCPSend(tcph, 0x8000, KeyCode==13?2:1 ,1);
        }


        /* Check the state of the connection */
        
        TCPStatus(tcph, &stateinfo);
	
	switch(stateinfo.State)
	{
		case TCPS_ESTABLISHED: break;
		
		case TCPS_CLOSED:	
	                printf("*** Connection lost. Cause: %b", stateinfo.CloseCause);
	                return 0;

		default:
			puts("*** Connection closed by peer.");
			TCPClose(tcph);
			return 0;
	}			

       
        /* If ESC es being pressed (bit 2 of 0xFBEC is 0), terminate */
        
        if((*((char*)0xFBEC) & 4)==0)
        {
                puts("\r\n\r\n*** ESC pressed, closing connection and exiting");
                TCPClose(tcph);
                return 0;
        }
	
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
