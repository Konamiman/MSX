# InterNestor Lite - getting started


Two variants of InterNestor Lite are available depending on the underlying hardware supported:

* InterNestor Lite for serial port (RS-232) port allows Internet connection via ISP using a modem, as well as direct connection to another computer using a null-modem cable. This version uses PPP as the link layer protocol.

* InterNestor Lite for Ethernet allows communication with other machines in an Ethernet network, as well as Internet connection by means of an ADSL or cable router.

Both variants implement the [TCP/IP UNAPI specification](https://github.com/Konamiman/MSX-UNAPI-specification/blob/master/docs/TCP-IP%20UNAPI%20specification.md), therefore after installing it you can use any standard [networking application](https://www.konamiman.com/msx/msx-e.html#networking).


### Prerrequisites

InterNestor Lite needs the following environment to work:

- An MSX computer with at least 128K of mapped RAM
- MSX-DOS 1 or 2, or [Nextor](https://www.konamiman.com/msx/msx-e.html#nextor)
- MSX-DOS 2 compatible mapper support routines (as of version 2.1), two RAM segments must be free
- The UNAPI RAM helper
- For the RS-232 variant: an RS-232 card, optionally a modem, and the Fossil driver by Erik Maas
- For the Ethernet variant: Ethernet UNAPI compatible hardware (e.g. ObsoNET)

And that's the software that you need to get, all of it is available at [Konamiman's MSX page](http://www.konamiman.com/msx/msx-e.html#inl2):

- The appropriate variant of `INL.COM`, the InterNestor Lite installer and control program
- For the RS-232 variant: Erik Maas' Fossil driver
- If you are running MSX-DOS 1: `MSR.COM` (installs mapper support routines and an UNAPI RAM helper). If you are running MSX-DOS or Nextor: `RAMHELPR.COM` (installs an UNAPI RAM helper)


### Installing

1. Install the Fossil driver (for the RS-232 variant only)

2. Install the UNAPI RAM helper, or the mapper support routines + UNAPI RAM helper pack, with `RAMHELPR I` or `MSR I`

3. Install InterNestor Lite with `INL I`

Hint: you can combine steps 2 and 3 and simply run `RAMHELPR I INL I` or `MSR I INL I`.


### Opening a connection (RS-232 variant)

If you use the RS-232 variant and have a modem, you can establish a connection to Internet using the following command:

```
INL PPP O /N:<number> /U:<user> /P:<password> /I
```

where `<number>` is your ISP (Internet Service Provider) phone number, and `<user>` and `<password>` are the account data as provided to you by your ISP.

For direct null-modem cable connection you use the same command, but you do not need the `/N` parameter (and probably, you don't need the `/U` and `/P` parameters either).

To close the connection use this command: `INL PPP C`.


### Configuring the IP addresses (Ehternet variant)

If there's a DHCP server in your network (which is the most common case when using an ADSL or cable router), you don't need to configure anything since InterNestor will have retrieved all the needed IP addresses automatically. Otherwise, you need to run the following commands:

```
inl ip d 0
inl ip l <IP address of MSX>
inl ip m <subnet mask>
inl ip g <default gateway IP address>
inl ip p <primary DNS server IP address>
inl ip s <secondary DNS server IP address>
```

This will also work if there's a DHCP server in your network but for some reason you want to set the IP addresses manually (the first command, `inl ip d 0`, disables the InterNestor's DHCP client).

Alternatively to running these commands manually, you can create a text file containing them (minus the `inl` at the beginning of each line) named `INL.CFG` in the same directory of `INL.COM`. This way, InterNestor will atuomatically read and apply the configuration at install time. See ["configuration"](configuration.md) for more details.


### Next steps

You can obtain information about the InterNestor state, including the configured (automatically or not) IP addresses, by running `INL S`. If everything looks good, you're all set! InterNestor Lite is now running as a background process and you are able to use any TCP/IP UNAPI compatible networking application, for example the ones in [Konamiman's MSX page](https://www.konamiman.com/msx/msx-e.html#networking).

`INL.COM` provides quite a few commands to configure and control the behavior of InterNestor Lite, see [the control program reference](control-program.md) for details.
