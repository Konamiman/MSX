# InterNestor Lite - configuration

InterNestor Lite has several configuration variables that can be modified by any of the following means:
<br/><br/>

### Using INL.COM

The most obvios way to configure InterNestor Lite is to run INL.COM after installation, passing the appropriate option and the desired value to be configured. See ["control program reference"](control-program.md) for the full list of available options.
<br/><br/>


### Configuration file at install time

If a text file named `INL.CFG` exists in the same directory of `INL.COM` at install time, that file will be read and the options it contains will be applied. This file must contain one command per line, with the same syntax used to run the commands directly - for example, if the file contains the line `ip d 0`, this will disable the DHCP client as if `inl ip d 0` had been executed after installation. Blank lines and lines starting with a ";" or "#" character are ignored.

Not all options are valid for the configuration file. As a general rule, options that modify a configuration value (such as an IP address) are valid, while options that perform an action (such as closing a TCP connection) are not.
<br/><br/>


### Configuration file after install

Alternatively, the configuration file can be read and applied once InterNestor is installed by running `inl f [<filename>]`. If no filename is specified, the file `INL.CFG`
located at the same directory of `INL.COM` is used.
<br/><br/>


### Environment variable

In MSX-DOS 2 and Nextor some configuration environment variables will be scanned at install time and their values will be applied if found. These are:

* INL_IP: IP address of MSX.
* INL_MASK: Subnet mask.
* INL_GW: Default gateway.
* INL_DNS_P: Primary DNS server.
* INL_DNS_S: Secondary DNS server.
* INL_DHCP: DHCP configuration vector.

For example, if the IP addresses are to be manually configured, the
following line could be added to the AUTOEXEC.BAT file (or it could be
executed manually before installing INL):

```
SET INL_DHCP=0
SET INL_IP=192.168.0.2
SET INL_MASK=255.255.255.0
...
```

