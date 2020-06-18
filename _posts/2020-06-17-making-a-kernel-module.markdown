---
layout: post
title:  "Making a simple kernel module"
date:   2020-06-17 20:20:00 -0400
categories: jekyll update
---

The Linux kernel is considered to be monolithic in design, however much of its functionality is implemented as kernel modules which can typically be loaded and unloaded on demand without rebooting. Writing kernel modules requires compiling against kernel headers, which in turn often requires frequent recompilation or even source code updates when maintaining out-of-tree modules due to the kernel's unstable API. 

Writing kernel modules may seem daunting at first, but once the conventions are understood it can actually be fairly straightforward. This post shall serve as a starting point by using standard kernel interfaces to create the simplest possible example module that can be loaded onto a modern Linux distribution. 

To get started, first install some basic development tools and libraries: 

```
$ sudo dnf install gcc make kernel-headers kernel-core
```

Next, create a simple kernel module stub named **kmodhello.c**:

{% highlight c %}
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init hello_start(void)
{
        printk(KERN_INFO "Hello world!\n");
        return 0;
}

static void __exit hello_end(void)
{
        printk(KERN_INFO "Goodbye World!\n");
}

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Joshua Stone");
MODULE_DESCRIPTION("Hello World kernel module");
MODULE_VERSION("0.1");

module_init(hello_start);
module_exit(hello_end);
{% endhighlight %}

Now to create **Makefile**:

{% highlight make %}
# Selects headers based on the current running kernel version
KDIR := /lib/modules/$(shell uname -r)/build

obj-m += kmodhello.o

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean
{% endhighlight %}

The kernel module should now be able to be built with **make**:

```
$ make
make -C /lib/modules/5.6.18-300.fc32.x86_64/build M=/home/jstone/Projects/kernel-module-demo modules
make[1]: Entering directory '/usr/src/kernels/5.6.18-300.fc32.x86_64'
  MODPOST 1 modules
make[1]: Leaving directory '/usr/src/kernels/5.6.18-300.fc32.x86_64'
```

Next, verify that the module has the proper information:

```
$ modinfo kmodhello.ko
filename:       /home/jstone/Projects/kernel-module-demo/kmodhello.ko
version:        0.1
description:    Hello World kernel module
author:         Joshua Stone
license:        GPL
srcversion:     247CEF653A79DE2D129B3E4
depends:        
retpoline:      Y
name:           kmodhello
vermagic:       5.6.18-300.fc32.x86_64 SMP mod_unload 
```

Fedora's Linux kernel configuration has some confinement enabled which prevents unsigned module loading:

```
$ sudo insmod kmodhello.ko
insmod: ERROR: could not qinsert module kmodhello.ko: Operation not permitted
$ journalctl --boot --dmesg | grep insmod
Jun 17 23:14:48 joshua-laptop kernel: Lockdown: insmod: unsigned module loading is restricted; see man kernel_lockdown.7
```

Disabling the loading of arbitrary modules makes some sense from a security standpoint, however it is an inconvenience as the module must now be signed with our own keys.

The first step to signing the kernel module is to create a signing key config:

```
$ mkdir certs
$ cat <<EOF > certs/x509.genkey
[ req ]
default_bits = 4096
distinguished_name = req_distinguished_name
prompt = no
string_mask = utf8only

[ req_distinguished_name ]
O = Test Organization
CN = Test signing key
emailAddress = joshua.gage.stone@gmail.com
EOF
```

With a signing config, it's now possible to generate a signing key pair:

```
openssl req -new \
            -nodes \
            -utf8 \
            -sha256 \
            -days 36500 \
            -batch \
            -x509 \
            -outform PEM \
            -out certs/kernel_key.crt \
            -keyout certs/kernel_key.priv
```

After the keys have been generated, the kernel module can now be signed:

```
$ /usr/src/kernels/$(uname -r)/scripts/sign-file sha512 \
                                                 certs/kernel_key.priv \
                                                 certs/kernel_key.crt \
                                                 kmodhello.ko
$ modinfo kmodhello.ko
filename:       /home/jstone/Projects/kernel-module-demo/kmodhello.ko
version:        0.1
description:    Hello World kernel module
author:         Joshua Stone
license:        GPL
srcversion:     247CEF653A79DE2D129B3E4
depends:        
retpoline:      Y
name:           kmodhello
vermagic:       5.6.18-300.fc32.x86_64 SMP mod_unload 
sig_id:         PKCS#7
signer:         Default Company Ltd
sig_key:        57:87:D2:05:88:50:E3:00:10:0E:F1:13:69:7F:48:F7:0E:64:FE:36
sig_hashalgo:   sha512
signature:      7A:5F:70:F0:45:72:94:11:C0:F0:A8:0C:3B:A3:C6:DE:F4:E0:E9:95:
		26:DC:17:A9:DB:E4:A1:AB:21:73:33:CA:1A:08:AD:8A:7F:F8:6C:A0:
		FF:75:67:3A:BD:D4:75:D2:F8:18:CA:C7:A4:3E:86:3A:35:24:CB:5D:
		87:F6:E5:76:38:27:47:1F:DE:F4:C7:A6:32:0D:1D:8A:18:AA:F2:E0:
		A0:5B:33:5D:31:BA:A9:9D:63:B6:6D:73:00:15:E8:FB:87:5E:3E:30:
		67:0A:76:EC:41:C6:05:49:5F:99:F9:C5:DE:65:5A:FF:F2:37:53:FD:
		1F:9B:2A:E2:FA:82:B1:59:31:E6:2A:9B:1B:E3:F5:ED:6D:3F:AB:EC:
		B5:D8:5D:92:1E:C0:F8:BD:18:E8:FA:E7:39:49:09:D0:3C:CF:B4:D6:
		D2:16:63:DA:03:D8:6B:F7:13:F8:47:42:77:80:23:15:EA:EE:13:0B:
		0C:74:92:E7:CE:63:75:1C:E7:2C:00:28:64:A1:EF:81:0D:3D:05:A0:
		DB:AA:2B:81:31:5F:1D:F0:5D:67:BD:B7:16:70:4C:41:B3:44:49:25:
		56:45:88:32:13:C6:7D:79:D3:10:95:68:7A:BD:63:B3:97:55:4D:A5:
		73:93:D1:7E:13:56:00:CB:B0:8D:DE:A9:6E:3A:15:BB
```

Now to find the ID for the Fedora kernel signing key:

```
 $ sudo cat /proc/keys | grep builtin_trusted_keys
0cf5a3e1 I------     2 perm 1f0b0000     0     0 keyring   .builtin_trusted_keys: 1
```

The ID is a hexadecimal value which can be verified like so:

```
$ sudo keyctl list 0x0cf5a3e1
1 key in keyring:
863900930: ---lswrv     0     0 asymmetric: Fedora kernel signing key: 2c1010ea8e2195f747d24f90dcd5b00e781a332d
```
