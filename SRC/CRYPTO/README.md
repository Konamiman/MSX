## Cryptographic functions

Back in 2012 I started a project for implementing TLS for MSX. After I read tons of documentation and wrote some code I had to give up when I realized that a Z80 (or a R800, for that matter) is in no way capable to run the required cryptographic algorithms in a reasonable amount of time.

However, it was not at all wasted time: not only did I learn a lot about how TLS works, but also I got some nice hashing and ciphering routines working and ready to use for any other project.

So here you will find code for MD5, SHA1 and HMAC hashing, DES and Triple DES ciphering, and the TLS pseudo-random function. Enjoy!
