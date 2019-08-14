# InterNestor Lite

InterNestor Lite is a TCP/IP stack that works on MSX2/2+/Turbo-R with at least 128K RAM. It supports two kinds of hardware: serial port (RS-232) with modem, and the [Ethernet UNAPI](http://konamiman.com/msx/msx-e.html#unapi).

InterNestor Lite implements the [TCP/IP UNAPI specification](http://konamiman.com/msx/msx-e.html#tcpipunapi), therefore you can use it to run the compatible [networking software](../NETWORK).

Binaries for InterNestor Lite are available at [Konamiman's MSX page](http://www.konamiman.com#inl2). As for the documentation, that's what you'll need:

- [Getting started](DOCS/getting-started.md): Prerrequisites and installation instructions.

- [InterNestor Lite control program reference](DOCS/control-program.md): How to configure and control InterNestor Lite using INL.COM

- [Proxying through a SOCKS server](https://github.com/Konamiman/MSX/pull/11), useful to provide WiFi or TLS support by using an additional device

Additionally, if you want to dig deeper in the technical side you can look at these:

- [How to build InterNestor Lite from the sources](DOCS/building.md)

- [InterNestor Lite architecture and limitations](DOCS/architecture.md)

- [UNAPI implementation-specific routines and data segment reference](DOCS/unapi-routines.md)


### Note about the RS-232 variant

The latest published version o InterNestor Lite for Ethernet is 2.2, but the RS-232 varfiant is currently stuck at version 2.0. That's because I no longer have the hardware needed to test it. I don't want to publish software I haven't been able to test, therefore the RS-232 variant of InterNestor Lite is discontinued for now.

However, if you want to [build](DOCS/building.md) the RS-232 variant of version 2.2 from the sources and test it yourself, I'll be glad to publish it.
