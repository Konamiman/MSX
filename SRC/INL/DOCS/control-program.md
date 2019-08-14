# InterNestor Lite - control program reference

This is a reference of all the configuration and control commands provided by INL.COM. See also ["configuration"](configuration.md).

InterNestor Lite is referred to as "INL" in this document.

## Index

### General options

[Install InterNestor Lite](#install-internestor-lite)

[Uninstall InterNestor Lite](#uninstall-internestor-lite)

[Pause InterNestor Lite execution](#pause-internestor-lite-execution)

[Resume InterNestor Lite execution](#resume-internestor-lite-execution)

[Get information about the PPP/network connection and the IP addresses](#get-information-about-the-pppnetwork-connection-and-the-ip-addresses)

[Get information about the INL configuration variables](#get-information-about-the-inl-configuration-variables)

[Restore INL to its initial state](#restore-inl-to-its-initial-state)

[Set the checksums calculation vector](#set-the-checksums-calculation-vector)

[Read a configuration file](#read-a-configuration-file)

### Modem and PPP connection options (serial version only)

[Send a command to the modem](#send-a-command-to-the-modem)

[Set the RS-232 inteface transmission rate](#set-the-rs-232-inteface-transmission-rate)

[Set the ISP phone number](#set-the-isp-phone-number)

[Set the positive modem reply](#set-the-positive-modem-reply)

[Set the PPP user name](#set-the-ppp-user-name)

[Set the PPP password](#set-the-ppp-password)

[Open a PPP connection](#open-a-ppp-connection)

[Close a PPP connection](#close-a-ppp-connection)

[Activate or deactivate the automatic PPP echo](#activate-or-deactivate-the-automatic-ppp-echo)

[Activate or deactivate the Van Jacobson compression negotiation](#activate-or-deactivate-the-van-jacobson-compression-negotiation)

### IP protocol options

[IP addresses initialization](#ip-addresses-initialization)

[Set the local IP address](#set-the-local-ip-address)

[Set the remote IP address (serial version only)](#set-the-remote-ip-address-serial-version-only)

[Set the subnet mask (Ethernet version only)](#set-the-subnet-mask-ethernet-version-only)

[Set the default gateway (Ethernet version only)](#set-the-default-gateway-ethernet-version-only)

[Set the IP address of the primary DNS server](#set-the-ip-address-of-the-primary-dns-server)

[Set the IP address of the secondary DNS server](#set-the-ip-address-of-the-secondary-dns-server)

[Activate or deactivate the negotiation of the DNS servers (serial version only)](#activate-or-deactivate-the-negotiation-of-the-dns-servers-serial-version-only)

[Activate or deactivate the automatic reply to PINGs](#activate-or-deactivate-the-automatic-reply-to-pings)

[Set the TTL for outgoing datagrams](#set-the-ttl-for-outgoing-datagrams)

[Set the TOS for outgoing datagrams](#set-the-tos-for-outgoing-datagrams)

[Set the DHCP configuration vector (Ethernet version only)](#set-the-dhcp-configuration-vector-ethernet-version-only)

### Name resolution options

[Host name resolution](#host-name-resolution)

### TCP protocol options

[Get TCP connections state information](#get-tcp-connections-state-information)

[Close TCP connection](#close-tcp-connection)

[Abort TCP connection](#abort-tcp-connection)

[Set SOCKS servers addresses and ports](#set-socks-servers-addresses-and-ports)

### Ethernet layer options (Ethernet version only)

[Obtain the Ethernet hardware address](#obtain-the-ethernet-hardware-address)

[Set the Ethernet frame type for outgoing packets](#set-the-ethernet-frame-type-for-outgoing-packets)

[Activate or deactivate the periodic network connection check](#activate-or-deactivate-the-periodic-network-connection-check)

[Reinitialize the Ethernet hardware](#reinitialize-the-ethernet-hardware)

### ARP protocol options (Ethernet version only)

[Establishing the lifetime of dynamic ARP entries](#establishing-the-lifetime-of-dynamic-arp-entries)

[Show the ARP table](#show-the-arp-table)

[Clear the ARP table](#clear-the-arp-table)

[Add an entry to the ARP table](#add-an-entry-to-the-arp-table)

[Erase an entry from the ARP table](#erase-an-entry-from-the-arp-table)

### Routing table options (Ehternet version only)

[Show the routing table](#show-the-routing-table)

[Clear the routing table](#clear-the-routing-table)

[Add an entry to the routing table](#add-an-entry-to-the-routing-table)

[Erase an entry from the routing table](#erase-an-entry-from-the-routing-table)


## General options

### Install InterNestor Lite

```
inl i
```

Installs InterNestor Lite, leaving it ready for use. See ["getting started"](getting-started.md) for details.
<br/><br/>

### Uninstall InterNestor Lite

```
inl u
```

Uninstalls InterNestor, freeing the segments that were allocated.
<br/><br/>


### Pause InterNestor Lite execution

```
inl p
```

This option decouples INL from the system's timer interrupt hook. What is
achieved with this action is to pause INL, that is, its resident code is not
executed 50/60 times per second so it does not perform any process. This may
be useful when it is necessary to perform a long task (for example to copy
some big files), since when INL is installed and active it slows down the
computer.

Note: on the Ethernet version, Ethernet hardware may continue capturing
incoming packets while INL is paused, so its internal buffer may overflow
and in this case no more packets will be captured.

The normal execution of INL may be resumed with `inl r`.
<br/><br/>


### Resume InterNestor Lite execution

```
inl r
```

This option couples again INL to the system's timer interrupt hook, so it
reverts to the normal execution mode that was previously interrupted when
pausing INL with `inl p`. It does nothing if INL is already active.
<br/><br/>


### Get information about the PPP/network connection and the IP addresses

```
inl s
```

_For the serial version:_

This option shows information about the current PPP connection status, the
reason of the last connection close, and the IP addresses established (local,
remote and the ones of the DNS servers). It also tells if INL is active or
paused.

The information about the IP addresses is shown even if there is no opened
PPP connection currently. In this case, this information refers to the IP
addresses that were used in the last connection, or to the IP addresses that
the user has established for being used in the next connection. See the
description of the IP protocol related options for more details.

_For the Ethernet version:_

This option shows the following information:

- State of the network connection (ON or OFF).
- IP addresses in use (address of MSX, subnet mask, default gateway and DNS
servers addresses).
- DHCP automaton state (only if any parameter is configured by using DHCP).

If the automatic checking of the network state every ten seconds is switched
off, then the state is checked when this command is executed. Otherwise,
simply the result of the last performed checking is shown. See the `inl eth c`
command.

The DHCP automaton state will be one of the following (see [RFC2131](https://tools.ietf.org/html/rfc2131) for more
details):

- INIT: Initial state, the configuration process will start immediately.
- SELECTING: DHCP servers are being searched in the net.
- REQUESTING: A DHCP server has been found in the net, and an IP address and
the desired configuration parameters are being requested to him.
- BOUND: The DHCP server has assigned an IP address to us and has given to us
the required parameters. This is the "stable" state of the automaton.
- RENEWING: Part of the lease time of the IP address has passed, and an
extension of the lease is being requested to the DHCP server.
- REBINDING: The DHCP server is not replying to the requests made to him in
the RENEWING state, so the requests are now sent to the broadcast address
(thus an alternative server is being searched).

Note that it is possible that the server denies the IP address lease extension
and that it instead assigns a new address to us. If this happens, all the
opened TCP connections will be closed.

If the IP address is manually configured and we are only intereseted in
obtaining other parameters by using DHCP, the automaton will only pass by
these two states, besides of INIT:

- INFORMING: Similar to SELECTING, but now we simply inform about our IP
address and request the other parameters.
- CONFIGURED: The requested parameters have been obtained. This state is
similar to BOUND, but contrarywise to BOUND, this state is permanent.

Note that the DHCP server may not permit us to manually configure our IP
address, and thus it may not accept the requests made to him in the INFORMING
state.

See the description of the `inl ip d` command for more information about the
configuration process when using DHCP.
<br/><br/>


### Get information about the INL configuration variables

```
inl v
```

This option shows information about the variables that govern the global
functionning of INL in which regard to the PPP connection/Ethernet layer and 
the IP protocol. There is an option of `INL.COM` asociated to each variable 
that allows modifying it.
<br/><br/>


### Restore INL to its initial state

```
inl d
```

This option restores INL to its initial state, it is equivalent to
uninstalling and reinstalling it. The actions it performs are:

1. Resets the Ethernet hardware (Ethernet version only).

2. Closes all the TCP and UDP connections and discards all the received and 
ICMP packets. For the Ethernet version, empties the ARP and routing tables.

3. Restores all the configuration parameters to their default values:

Serial version:

* ISP phone number: Empty string
* Modem positive reply: CONNECT
* PPP user name: Empty string
* PPP password: Empty string
* Negotiate DNS servers IP addresses: Yes
* Periodically send PPP echo requests: Yes
* Negotiate the use of Van Jacobson compression: Yes

Ethernet version:

* Send Ethernet frames with IEEE802.3 encapsulation: No
* Check the network connection state every ten seconds: Yes
* DHCP configuration vector: 63
* Dynamic ARP entries lifetime: 300 seconds (5 minutes)

All versions:

* All the IP addresses: 0.0.0.0
* Automatically reply incoming PINGs (ICMP echo requests): Yes
* TTL for outgoing datagrams: 64
* TOS for outgoing datagrams: 0
* Default size for outgoing PINGs (data part): 64
* Checksums calculation vector: 31

4. Reads and applies the environment item recognized during installation and
the `INL.CFG` file, if they exist (see ["configuration"](configuration.md)).

Note for the serial version: do not use this function when there is an open
connection, since all IP addresses will revert to 0.0.0.0 as well.
<br/><br/>


### Set the checksums calculation vector

```
inl o <vector>
```

By modifying this value it is possible to force INL to accept as valid the
incoming data packets without calculating one or more of the associated
checksums. In this way some execution speed is gained, but there is the risk
of accepting damaged packets as if they were correct. It may be useful when
directly connecting two computers, since in this case the probability of
receiving damaged packets is small.

`<vector>` is a number in the range 0 to 30 that must be interpreted as a
five bit vector. Each bit controls the calculation of a given checksum type:
if it is one, the checksum is calculated for all the incoming packets; if it
is zero, the checksum is not calculated, assuming that if it were calculated
it would be valid.

The `<vector>` bits are assigned as follows:

* Bit 0 (value 1): FCS of PPP frames (serial version only)
* Bit 1 (value 2): Checksum of IP datagrams header
* Bit 2 (value 4): Checksum of TCP segments
* Bit 3 (value 8): Checksum of UDP packets header
* Bit 4 (value 16): Checksum of ICMP messages

For example, if you want only the TCP and UDP checksums to be calculated, use
vector 4+8=12: `inl o 12`.

Default value is 31, meaning that all checksums are calculated. Normally this
is the value that should be used, unless you note speed problems in your
computer.
<br/><br/>


### Read a configuration file

```
inl f [<filename>]
```

This option allows executing multiple options with one single execution of
`INL.COM`; the options to be executed are stored in a text file, whose path and
name is passed as an argument. If no filename is specified, the file `INL.CFG`
located at the same directory of `INL.COM` is used.

The text file must contain the options to be executed, with the same syntax as
if they were executed directly. For example, if you want to set the checksums
calculation vector to 31, to disable the periodic network connection state
checking (Ethernet version only), and to set the local IP address to 1.2.3.4,
then the configuration  file contents should be as follows:

```
o 31
eth c 0
ip l 1.2.3.4
```

Blank lines and lines starting with a ";" or "#" character are ignored.

It is not possible to nest configuration file reads (that is, you can't
execute `inl f` option from a configuration file). Also, you can't uninstall
INL (`inl u`) from a configuration file.
<br/><br/>


## Modem and PPP connection options (serial version only)

### Send a command to the modem

```
inl ppp m <command>
```

This option sends the string `<command>` to the modem, waits the reply and
shows it. It may be useful, for example, to silent the modem speaker before
performing the connection (this is achieved with the command ATM0).
<br/><br/>


### Set the RS-232 inteface transmission rate

```
inl ppp b <bauds code>
```

This option establishes the RS-232 interface transimission rate according to
the specified `<bauds code>`:

* 0 for 75 bauds
* 1 for 300 bauds
* 2 for 1200 bauds
* 3 for 1200 bauds
* 4 for 2400 bauds
* 5 for 4800 bauds
* 6 for 9600 bauds
* 7 for 19200 bauds
* 8 for 38400 bauds
* 9 for 57600 bauds
* 10 or 11 for 115200 bauds

INL supports up to 19200 bauds for R800 and up to 9600 bauds for Z80, at
higher speeds there is data loss. After INL installation the speed will have
been established to the appropriate value according to the processor
detected.
<br/><br/>


### Set the ISP phone number

```
inl ppp n [<number>]
```

This option establishes the phone number that the modem will dial when
opening a connection by executing `inl ppp o`. If `<number>` is an empty string,
no dial will be performed, and the PPP connection will be attempted directly
(assuming that at the other side there is another computer connected via null-
modem cable).

The maximum length for `<number>` is 15 characters. If a larger string is
specified, only ther first 15 characters will be taken in account.
<br/><br/>


### Set the positive modem reply

```
inl ppp r <reply>
```

This option sets the starting part of the string that the modem will
return after a sucessful dialing to the ISP while opening a connection with
`inl ppp o`. INL.COM needs to know this string in order to decide whether to
display an error, or to continue and attempt to open the PPP connection after
the dialing process has finished, depending on the modem reply. In most
modems this string is "CONNECT", and so this is the string that INL
sets by default.

It is not necessary to specify the full reply, the first characters are
enough. For example, modems normally reply with something like "CONNECT
48000/V24BIS", but it is enough to specify "CONNECT".

The maximum length for `<reply>` is 15 characters. If a larger string is
specified, only ther first 15 characters will be taken in account. It is not
possible to specify an empty string.
<br/><br/>


### Set the PPP user name

```
inl ppp u [<name>]
```

This option sets the PPP user name that will be used when a connection
is opened by executing `inl ppp o`; in other words, the user name of the
internet access account supplied by the ISP.

If an empty string is specified, INL will abort the connection if
authentication is required.

The maximum length for `<name>` is 31 characters. If a larger string is
specified, only ther first 31 characters will be taken in account.
<br/><br/>


### Set the PPP password

```
inl ppp p [<password>]
```

This option sets the PPP password that will be used when a connection
is opened by executing `inl ppp o`; in other words, the password of the
internet access account supplied by the ISP.

The maximum length for `<password>` is 31 characters. If a larger string is
specified, only ther first 31 characters will be taken in account.
<br/><br/>


### Open a PPP connection

```
inl ppp o [/n:[<number>]] [/u:[<user>]] [/p:[<password>]]
	      [/r:<modem reply>] [/i]
```

This option starts a PPP connection, either to Internet via ISP or to another
machine using a null-modem cable.

`<number>` is the ISP phone number that the modem will dial. If it is an empty
string, no dial will be performed (that is, INL will assume that there is
another computer at the other side, connected directly with a null-modem
cable). The maximum length is 15 characters.

`<user>` and `<password>` are the PPP authentication data that will be used (that
is, the Internet account data supplied by the ISP). If `<user>` is not
specified, `INL.COM` will abort the connection if authentication is required.
The maximum length for both parameters is 31 characters.

`<modem reply>` is the start of the string that the modem will return if a
successful dialing to the ISP is achieved. In most modems this string is
"CONNECT", which is the string that INL establishes by default, and it is not
necessary to modify it. The maximum length is 15 characters.

/I causes all the IP addresses (local, remote and the ones for the DNS
servers) to be reset to 0.0.0.0, and the negotiation of the IP addresses of
the DNS servers to be activated, all of this before initiating the
connection. This is the most usual behavior, since usually we will connect
via an ISP that will dinamically supply us all the IP addresses. However it
is possible that we want to directly connect to other computer via null-modem
cable and that we already know (or want to supply to the other computer) one
or more of the IP addresses to use. In this case, we must first establish the
desired addresses using any of the INL IP x commands, and then open the
connection without specifying /I.

If any of the parameters /N, /U, /P and/or /R is are not specified, then the
value previously established with `inl ppp n`, `inl ppp u`, `inl ppp p` and/or `inl ppp r`,
respectively, will be used. That is, the following execution sequences
are equivalent:

- Sequence 1:
  - inl ppp n 12345
  - inl ppp u kyoko
  - inl ppp p jap0paya
  - inl ppp o /R:OK

- Sequence 2:
  - inl ppp o /n:12345 /u:kyoko /p:jap0paya /r:OK

Note that specifying a null value for a parameter is not the same that not
specifying the parameter at all (/N alone means that no number will be
dialed; not specifying /N means that the number previously specified with `inl ppp n` will be used).
<br/><br/>


### Close a PPP connection

```
inl ppp c
```

This option closes the Internet connection (or the connection to the other
computer in case of direct connection); normally the modem will automatically
disconnect from the ISP in few seconds. The IP addresses are not modified,
nor are any of the INL parameters that were established before or during the
connection.
<br/><br/>


### Activate or deactivate the automatic PPP echo

```
inl ppp e 0|1
```

INL cannot detect the physical drop of the connection (that is, the modem
carrier loss or the sutdown or crash of the other computer in case of direct
connection). For this reason it uses a connection checking mechanism provided
by the PPP protocol, consisting on periodically sending echo packets to the
ISP or to the other computer (note that they are PPP protocol level packets;
do not confuse with PINGs, which are IP protocol level packets).

INL has this feature activated by dafault, but it may be deactivated by
executing `inl ppp e 0`, and activated again with `inl ppp e 1`. When activated,
INL will send PPP echo packets to the other side every five seconds; if four
consecutive packets are sent without receiving any reply, INL will assume
that the connection is lost and will close it automatically.
<br/><br/>


### Activate or deactivate the Van Jacobson compression negotiation

```
inl ppp v 0|1
```

This option activates (1) or deactivates (0) the negotiation of the Van
Jacobson compression for TCP/IP headers during the PPP connection
establishment; if it is negotiated and the remote side supports this
compression as well, then it will be used during all the connection lifetime.

The Van Jacobson compression is specific of the point to point connections
and allows to reduce the size of the TCP/IP headers, originally 40 bytes
long, down to an average of five bytes. In exchange, additional processing is
required for all the incoming and outgoing TCP segments.

Changes in this option will have effect the next time a PPP connection is
open; it is not possible to activate or deactivate the Van Jacobson
compression for an already opened connection.
<br/><br/>


## IP protocol options

### IP addresses initialization

```
inl ip i
```

This option initializes (sets to 0.0.0.0) all the IP addresses. For the
serial version, these are: local, remote and DNS servers. For the Ethernet
version, these are: local, subnet mask, default gateway, and DNS servers.

Serial version: by protocol specification, announcing an address of 0.0.0.0
during the PPP negotiation means that we don't know the address of interest
and that we request that the peer assign one for us (all the connections to
ISPs work in this way).

Ethernet version: this option must not be executed if one or more of these
addresses are to be obtained by using DHCP (see `inl ip d`  command).
<br/><br/>


### Set the local IP address

```
inl ip l <IP address>
```

This option establishes the local IP address (the address of the MSX itself)
to the specified value.

Serial version: using this option makes sense only with direct cable
connections, and only if we know that the peer is unable of supplying us our
IP address. If the peer supplies us an address during the connection
establishment (this will always occur in ISP connections), this address will
have preference over the address that we have established manually. Do not
use this option when there is a connection opened.

Ethernet version: this option must not be executed if the local address is to
be obtained by using DHCP (see `inl ip d` command).
<br/><br/>


### Set the remote IP address (serial version only)

```
inl ip r <IP address>
```

This option establishes the remote IP address (that is, the address of the
other side of the connection) to the specified value. It must never be used
when there is a connection opened.

Using this option makes sense only with direct cable connections, and only if
we know that the peer does not know its own IP address and we must supply one
to him. If the peer announces us his own IP address during the connection
establishment (this will always occur in ISP connections), this address will
have preference over the address that we have established manually.
<br/><br/>


### Set the subnet mask (Ethernet version only)

```
inl ip m <mask>
```

This option establishes the subnet mask (that is, the mask that will be
applied to IP addresses to decide whether they are local or not) to the
specified value. Must not be executed if this parameter is to be obtained by
using DHCP (see `inl ip d` command).
<br/><br/>


### Set the default gateway (Ethernet version only)

```
inl ip g <IP address>
```

This option establishes the default gateway address (that is, the address of
the computer to which non local datagrams will be sent in absence of an
appropriate entry in the routing table) to the specified value. Must not be
executed if this parameter is to be obtained by using DHCP (see `inl ip d`
command).
<br/><br/>


### Set the IP address of the primary DNS server

```
inl ip p <IP address>
```

This option establishes the IP address of the primary DNS server, that is, the
name server that the INL built-in resolver queries when a host name resolution
is requested.

Ethernet version: this option must not be executed if this parameter is to be
obtained by using DHCP (see `inl ip d` command).

_Serial version:_

The logic behind this parameter is similar to the logic behind the `ip l` and
`ip r` parameters (local and remote IP addresses): any address proposed by the
peer during the connection establishment will have preference over the
addresses manualy established by us before opening the connection. However
there are two important differences:

1. There is no problem on modifying the IP address of the DNS server once the
PPP connection is opened.

2. It is possible to deactivate the negotiation of this address by executing
`inl ip n 0` before opening the connection. In this case, the address that we
assign by executing `inl ip p` will still be valid once the connection is
opened (actually, we don't even give the peer an opportunity to propose an
alternative address). This is true even when connecting via ISP.

The use of `inl ip n 0` followed by `inl ip p <address>` prior to opening the
connection is useful when we want to use DNS servers other than the ones
supplied by the ISP.

Note: The /I parameter of `inl ppp o` not only establishes all the IP addresses
to 0.0.0.0, but also activates the DNS addresses negotiation. Therefore, if
you want to connect to an ISP without negotiating the DNS addresses you must
use this execution sequence:

```
inl ip i
inl ip n 0
inl ppp o /n:<number> /u:<user> /p:<password>
```
<br/><br/>


### Set the IP address of the secondary DNS server

```
inl ip s <IP address>
```

This option works like `inl ip p`, but refers to the secondary DNS server
address. The resolver of INL always queries the primary DNS server as the
first try; only if this one does not reply, the query will be repeated using
the secondary DNS server.
<br/><br/>


### Activate or deactivate the negotiation of the DNS servers (serial version only)

```
inl ip n 0|1
```

This option activates or deactivates the negotiation of the IP addresses of
the DNS servers for the future PPP connections. By default it is activated;
it can be deactivated by executing `inl ip n 0` and activated again with `inl ip n 1`.
The /I option of `inl ppp o` activates this negotiation as well.

Supressing the negotiation of the DNS servers may be useful when we want to
use servers other than the ones supplied by the ISP. See the description of
`inl ip p` above for more details.
<br/><br/>


### Activate or deactivate the automatic reply to PINGs

```
inl ip e 0|1
```

This option activates or deactivates the automatic sending of replies for all
the ICMP echo requests (PINGs) received from any computer of Internet. By
default it is activated; it can be deactivated by executing `inl ip e 0` and
activated again with `inl ip e 1`.
<br/><br/>


### Set the TTL for outgoing datagrams

```
inl ip t <value>
```

This option establishes the value of the TTL (Time To Live) field for all the
outgoing datagrams; it must be a number in the range 1 to 255. The default
value is 64 and in normal circumstances it should not be modified.
<br/><br/>


### Set the TOS for outgoing datagrams

```
inl ip o <value>
```

This option establishes the value of the TOS (Type Of Service) field for all
the outgoing datagrams; it must be a number in the range 0 to 15. The default
value is 0 and in normal circumstances it should not be modified.
<br/><br/>


### Set the DHCP configuration vector (Ethernet version only)

```
inl ip d <vector>
```

This option establishes the DHCP configuration vector, which is a value that
indicates what configuration parameters will be obtained by using DHCP.

`<vector>` is a number in the range 0 to 63 that must be interpreted as a six
bit vector. Each bit controls the configuration of a given parameter: if it is
one, the parameter will be tried to be obtained by using DHCP; if it is zero,
the parameter must be configured manually.

The `<vector>` bits are assigned as follows:

* Bit 0 (value 1): IP address of MSX
* Bit 1 (value 2): Subnet mask
* Bit 2 (value 4): Default gateway
* Bit 3 (value 8): DNS servers
* Bit 4 (value 16): Lifetime of dynamic ARP entries
* Bit 5 (value 32): Ethernet encapsulation type for outgoing frames (Ethernet II or IEEE802.3)

For example, if you want only the local IP address, the subnet mask and the
DNS servers addresses to be obtained by using DHCP, use vector 1+2+8=11: `inl ip d 11`.
The most usual case is to either use value 0 (completely manual
configuration) or value 63 (obtain everything by DHCP). The default value for
the vector is 63.

It is possible that the DHCP server do not provide us all the requested
parameters. Parameters that are configured to be obtained by using DHCP but
that are not supplied by the server are established to their default values:
0.0.0.0 for the IP addresses, five minutes for the lifetime of dynamic ARP
entries, and Ethernet II encapsulation for outgoing frames.

It is recommended to execute this command at installation time only (see the
`inl i` command). To switch from DHCP configuration to manual configuration, it
is recommended to reinitialize INL (`inl d` command) instead of executing `inl ip d 0`.

The behavior of the DHCP automaton will be different depending on the value of
bit 0 of the vector. See `inl s` for more details.
<br/><br/>


## Name resolution options

### Host name resolution

```
inl dns r <host name>
```

This option asks the INL built-in resolver to resolve the specified host name,
and shows the resulting IP address if the query has success, or an error
message otherwise. While the query is in progress it is possible to abort the
process by pressing any key; this will cause the program to terminate
immediately without displaying any result.
<br/><br/>


## TCP protocol options

### Get TCP connections state information

```
inl tcp s [<connection>]
```

This options shows information about the state of the specified connection (a
number between 0 and 3), or about the state of all the connections if no
connection number is given.

If the connection does not exist (its state is CLOSED), the cause of the
connection closing is shown or otherwise the fact that this connection has
never been used is indicated. Otherwise, the TCP connection state, the local
port and the remote IP address and port are shown.
<br/><br/>


### Close TCP connection

```
inl tcp c <connection>
```

This option closes the specified connection (a number between 0 and 3) via a
standard TCP CLOSE call.

The fact of closing a TCP connection does not imply that the connection will
cease to exist immediately, since for this it is necessary that the other side
of the connection close it as well. On the other hand, if there is still
pending outgoing data not yet sent, the close request will not become
effective until all the data has been sent. Therefore, if what you wish is to
immediately destroy the connection so it becomes free immediately, you should
abort the connection rather than closing it (see the TCP A option next).
<br/><br/>


### Abort TCP connection

```
inl tcp a <connection>
```

This option aborts the specified connection (a number between 0 and 3) via a
standard TCP ABORT call. The connection reaches the CLOSED state immediately
and it becomes available for further re-opening.
<br/><br/>


### Set SOCKS servers addresses and ports

```
inl tcp x1 <IP address> <port>
inl tcp x2 <IP address> <port>
```

This option must be used to configure INL as a SOCKS5 client. It sets the address and port of the SOCKS server to use for regular TCP connections (with `x1`) or for TLS connections (with `x2`). You can remove this configuration, so that INL stops acting as a SOCKS5 client, with `inl tcp x1 0` or `inl tcp x2 0`.

See ["acting as a SOCKS client"](socks.md) for more details.
<br/><br/>


## Ethernet layer options (Ethernet version only)

### Obtain the Ethernet hardware address

```
inl eth h
```

This option simply shows the Ethernet hardware address (also called pysical
address, Ethernet address or MAC). The hardware address is unique for each
card, it's assigned in the factory and cannot be changed.
<br/><br/>


### Set the Ethernet frame type for outgoing packets

```
inl eth f 0|1
```

This option establishes the Ethernet encapsulation type to be used for the
packets to be sent: Ethernet II (0) or IEEE802.3 (1). Must not be executed if
this parameter is to be obtained by using DHCP (see `inl ip d` command).

The default value (0, Ethernet II frames) must be left unmodified unless we
know for sure that the other machines of the net work with the IEEE802.3.
encapsulation only. INL recognizes and can process both frame types in the
received packets.
<br/><br/>


### Activate or deactivate the periodic network connection check

```
inl eth c 0|1
```

This option activates (1) o deactivates (0) the periodic checking of the
network connection status.

If active, the Ethernet UNAPI routine for checking the physical network
connection (this routine may send a test packet) is executed every ten
seconds. If the test fails, then the network is considered to be unavailable
and all the TCP connections are closed.

The arrival of any packet resets the timer used for the checking, so the tests
are performed only when there is no network traffic.

If the checking is deactivated, INL will always assume that the network is
available.
<br/><br/>


### Reinitialize the Ethernet hardware

```
inl eth r
```

This option resets the Ethernet hardware. It may be used after executing an
application that directly uses the Ethernet UNAPI routines, if it is not
sure in which state the application has left the hardware. In these cases it
is not necessary to reset the whole INL (with the `inl d` command), and it is
enough to use this command.
<br/><br/>


## ARP protocol options (Ethernet version only)

### Establishing the lifetime of dynamic ARP entries

```
inl arp t <time>h|m|s
```

When INL wants to send a local datagram, it must learn which is the hardware
address of the computer whose IP address is the destination of the datagram.
For this purpose it uses the ARP protocol, and when the information has been
obtained, INL stores the pair hardware address-IP address in a table for being
used when later delivering other datagrams to the same IP address.

The entries in the table have a given lifetime, and when it expires, the entry
is erased; this is done in prevision of the fact that any machine may retire
from the network or change its Ethernet card. This command allows to specify
that lifetime, and must not be executed if this parameter is to be obtained by
using DHCP (see `inl ip d` command).

The lifetime can be indicated in three ways:

- A number between 1 and 18, followed by "h", indicating hours.
- A number between 1 and 1080, followed by "m", indicating minutes.
- A number between 1 and 65535, followed by "s", indicating seconds.

The default value is five minutes.
<br/><br/>


### Show the ARP table

```
inl arp s
```

This option shows the current contents of the ARP table. For each entry the IP
address, the associated hardware address, and the entry type, static or
dynamic (static entries are added with INL ARP A) are shown.
<br/><br/>


### Clear the ARP table

```
inl arp c
```

This option erases the whole contents of the ARP table; the dynamic entries as
well as the static entries are deleted.
<br/><br/>


### Add an entry to the ARP table

```
inl arp a <IP address> <hardware address>
```

This option adds the indicated IP address-hardware address pair to the ARP
table. The entries added in this way are static, that is, their lifetime is
infinite: they remain until they are explicitly deleted (with `inl arp c` or `inl arp d`)
or until INL is reset or uninstalled (with `inl d` or `inl u`, respectively).

If there is already an entry whose IP address equals the one specified in the
command, then the entry is updated with the specified hardware address, and if
the entry is dynamic it becomes static.

The ARP table has room for 32 entries in this code version of INL, and up to
30 can be static entries.
<br/><br/>


### Erase an entry from the ARP table

```
inl arp d <IP address>
```

This option erases from the ARP table the entry whose IP address equals the
specified address. Static entries as well as dynamic entries can be deleted.
<br/><br/>


## Routing table options (Ehternet version only)

### Show the routing table

```
inl rou s
```

When INL wants to send a datagram, it first checks if the destination IP
address corresponds to a computer attached to the same physical network of the
MSX; this will happen if (IP of MSX) AND (subnet mask) = (destination IP) AND
(subnet mask). In that case the datagram is sent directly, previously
resolving the physical address by using ARP if necessary.

Otherwise, the datagram must be sent to a router that will in turn resend the
datagram to its destination. To know the address of the router, the routing
table is examined; this table consists of terns net address-subnet mask-router
address. If an entry is found for which (destination IP AND entry mask) =
(entry net address AND entry mask) applies, then the datagram is sent to the
router whose address appears in the entry (which must be in the same physical
network), previously resolving its physical address by using ARP if necessary.

If no appropriate entry is found in the routing table, then the datagram is
sent to the default gateway (whose address can be established with `inl ip g`).

This option shows the contents of the routing table. New entries can be added
with `inl rou a`, and existing entries can be deleted with `inl rou c` and `inl rou d`.
<br/><br/>


### Clear the routing table

```
inl rou c
```

This option erases the whole contents of the routing table. The default
gateway address is not modified.
<br/><br/>


### Add an entry to the routing table

```
inl rou a <network address> <subnet mask> <router IP address>
```

This option adds the indicated IP network address-subnet mask-router IP
address tern to the routing table. The entries remain until they are
explicitly deleted (with `inl rou c` or `inl rou d`) or until INL is reset or
uninstalled (with `inl d` or `inl u`, respectively).

If there is already an entry whose pair network address-subnet mask matches
the pair specified in the command, then the entry is updated with the
specified router address.

If more than one entry in the table is appropriate for a given outgoing
datagram, then the information of the first entry found will be used. For
example, if the following is executed:

```
inl ip l 192.168.0.7
inl ip m 255.255.255.0
inl rou a 1.2.0.0 255.255.0.0 192.168.0.1
inl rou a 1.2.0.0 255.255.255.0 192.68.0.2
```

then a datagram destinated to 1.2.0.34 will be sent to touter 192.168.0.1.

The routing table has room for 16 entries in this code version of INL.
<br/><br/>


### Erase an entry from the routing table

```
inl rou d <network address> <subnet mask>
```

This option erases from the routing table the entry whose IP network address-
subnet mask pair matches the specified pair.
