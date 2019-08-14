# InterNestor Lite - architecture and limitations

InterNestor Lite is a resident program: once installed, it works as a background task, coupled to the timer interrupt hook. On each interrupt (at 50Hz or 60Hz) it updates timers, retrieves incoming data from the network, does all the necessary processing, and if necessary sends data back to the network. Interfacing with networking applications is done by implementing the [TCP/IP UNAPI specification](http://konamiman.com/msx/msx-e.html#tcpipunapi).

For the serial version, Internet access is obtained by means of a standard modem and an account subscribed with any Internet Service Provider (ISP). For this reason, besides of the TCP/IP protocols it supports the PPP protocol, which is the link layer protocol used to establish connections with ISPs; additionally, InterNestor can also send commands to the modem to dial the ISP's phone number.

On the other hand, the serial version of InterNestor may also be used to perform a direct point-to-point connection with another computer. A null-modem cable is required for this, and the other computer must also support PPP and TCP/IP (for example another MSX running InterNestor, or a PC running Linux). In this case, a little of additional work is required before establishing the connection, since the IP addresses must be configured manually (when connecting via ISP, these addresses are obtained automatically).

As for the Ethernet version, Internet access os obtained by means of an ADSL or cable router; connection to an Ethernet local network is also possible. The DHCP protocol is supported for obtaining the IP address and other parameters; of course, manual configuration is also possible, for connections to simple networks.

The serial version uses the Fossil driver developed by Erik Maas for low level access to the serial port. The Ethernet version performs low level network access by using the services exposed by an [Ethernet UNAPI implementation](http://konamiman.com/msx/msx-e.html#unapi) and supports ARP and DHCP.

InterNestor consists of one single file, INL.COM, which allows to install/uninstall InterNestor (the resident code itself is also embedded in INL.COM), to open/close PPP connections (serial version only), to managing the ARP and routing tables (Ethernet version only), to set/obtain various configuration parameters, to obtain the state of the TCP connections, and to resolve host names.

InterNestor installs itself in two RAM segments located always in the primary mapper: one for code and another one for data buffers and variables.


## Limitations

InterNestor Lite provices all the TCP/IP functionality needed for the most common network applications, but it has limitations imposed by the memory and processing power available in a MSX computer.


### General

- ICMP is not supported, except for "Destination unreachable" messages and echo messages(PINGs). The size of these messages may be choosen, but not its contents. On the other hand, the size of the replies received may be obtained, but not its contents.
- Raw datagram sending and capturing is supported, but only one raw datagram can be captured at the same time.
- Serial version: the maximum transmission rate is 9600 bauds for Z80, and 19200 bauds for R800.
- Serial version: the implementation of the PPP protocol is a simplified version of the complete specification; it should work well in normal circumstances. For example, a simplified automaton of only five states is used (closed, LCP negotiation, authentication, IPCP negotiation and opened).
- Serial version: although the PPP standard states that incoming data packets up to 1500 bytes long must be accepted until a smaller size is negotiated, INL will always discard all the incoming packets that are larger than 582 bytes.
- Ethernet version: the ARP table is limited to 32 entries, and the routing table is limited to 16 entries.


### IP

- The maximum datagram size supported is 576 bytes.
- IP fragmentation is not supported, nor it is the reassembly of incoming fragmented datagrams; received datagram fragments are aways ignored (except when sending and receiving raw datagrams).
- It is not possible to include IP options in the outgoing datagrams; besides, the IP options of the received datagrams are always ignored (except when sending and receiving raw datagrams).
- The loopback address (127.x.x.x) is not supported and InterNestor cannot send datagrams to itself.


### UDP

- INL may open up to three UDP connections, each having buffer space assigned to hold up to two packets of up to 556 bytes each. These packets must be consumed by an pplication in a reasonable time; new packets arriving when there are already two pending packets stored for the associated connection will be lost.


### TCP

- Only four TCP connections can be opened simultaneously.
- Each TCP connection has assigned a fixed-length buffer of 1024 bytes for outgoing data, and another buffer of the same size for incoming data.
- The TIME-WAIT state does not exist. Connections enter directly the closed state when they should enter the TIME-WAIT state.
- Only the TCP option MSS is recognized (but INL will send segments larger than 448 bytes). On connection initiation, a MSS=448 option is always sent.
- It is not possible to send urgent data. Besides, the URG flag and the urgent data pointer of the received datagrams are always ignored.
- It is possible to send data to a TCP connection only when it is in the ESTABLISHED state or in the CLOSE-WAIT state.
- It is not possible to convert a passive connection into an active connection (neither by reopening it as active, nor by sending data to it).
- The initial sending sequence number for new connections is always zero.
- Only one data segment is sent at a time. That is, once a segment is sent, no more segments are sent (except retransmissions) until the acknowledgment for the sent segment is received, regardless of the transmission window.
- The retransmission timeout is fixed to three seconds. The zero window probing interval is fixed to 10 seconds.
- A simplified approach to the "SWS Avoidance" algorithm is used: the receive window announced is equal to the free space on the receive buffer, with the seven low order bits set to zero. That is, the announced receive window increases and decreases in steps of 128 bits. When the free space is smaller than 128 bytes, the real value is announced.
- A simplified approach to the Nagle algorithm is used. If the outgoing data has the PUSH bit set, data is sent immediately. Otherwise, it is sent when
enough bytes are available to send a maximum sized segment or when 0.5 seconds elapses since the older outgoing data was enqueued, whatever happens first.
- The Slow Start/Congestion Avoidance algorithms have not been implemented, but an ACK segment is sent immediately when out-of-order segments are received, so if the peer's TCP module implements these algorithms, it will work correclty when interacting with InterNestor.
- The TCP Delayed ACK algorithm is implemented an ACK segment is sent when at least 256 bytes of new data have been received, or when 0.1 seconds elapses since the older unacknowledged new data arrived, whatever happens first.
- TLS is supported only indirectly, when [proxying through a SOCKS server](socks.md). SOCKS is supported only for active TCP connections.


### DNS

- Only translations from host names to IP addresses are possible.
- Only one query can be performed at the same time.
- When a query returns a list of servers instead of a reply (non recursive queries), only the first of them is queried, and if no reply is obtained then the query is considered to have failed.
- Only UDP is used. Fallback to TCP when a truncated datagram is received is not supported.
