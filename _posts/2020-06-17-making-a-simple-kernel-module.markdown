---
layout: post
title:  "Making a simple kernel module"
date:   2020-06-17 20:20:00 -0400
categories: jekyll update
---

The Linux kernel is considered to be monolithic in design, however much of its functionality is implemented as kernel modules which can typically be loaded and unloaded on demand without rebooting. Writing kernel modules requires compiling against kernel headers, which in turn often requires frequent recompilation or even source code updates when maintaining out-of-tree modules due to the kernel's unstable API. 

Writing kernel modules may seem daunting at first, but once the conventions are understood it can actually be fairly straightforward. This post shall serve as a starting point by using standard kernel interfaces to create the simplest possible example module that can be loaded onto a modern Linux distribution. 

**Note:** [All testing is done on Fedora 32](https://download.fedoraproject.org/pub/fedora/linux/releases/32/Workstation/x86_64/iso/)

# Setting up a virtual machine

Due to the nature of kernel modules requiring root permissions for accessing the kernel and boot firmware, testing should be done inside a virtual machine to prevent accidental damage to the host system.

First, install the following packages:

```
$ sudo dnf install edk2-ovmf virt-install virt-manager virt-viewer
```

Libvirtd should also be running:

```
$ sudo systemctl enable --now libvirtd.service
```

Now to set up a Kickstart file to automate the VM install process with the name **kickstart.cfg**:

{% highlight shell %}
# Use graphical install
graphical
# Use network installation
url --url="https://download.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os"

%packages
# Base Fedora image
@^workstation-product-environment
# extra packages
gcc
kernel-devel
kernel-headers
make
mokutil
%end

# Keyboard layouts
keyboard --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --hostname=developmentvm.localdomain

# Run the Setup Agent on first boot
firstboot --enable
# System services
services --enabled="chronyd"

ignoredisk --only-use=vda
autopart
# Partition clearing information
clearpart --none --initlabel

# System timezone
timezone America/New_York --utc

#Root password
rootpw --lock
# Password is '123456'
user --groups=wheel --name=user --password=$6$BILcHTJg8gRQ5bkk$9Kd7wsdgmb8sjzxjqMb4wxYnsSN6TYMOHOio6qn8abhQ9Pm/DI6qyeYiBWa.sBrKrDHq/q8yO.ew.iVS01jLL1 --iscrypted --gecos="user"

%addon com_redhat_kdump --disable --reserve-mb='128'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

%post
# Update to the latest packages now to avoid updating on reboot
dnf upgrade --assumeyes
%end

reboot
{% endhighlight %}

Once the Kickstart file is made, it's time to start the new VM:

```
sudo virt-install --name f32-kmod \
                  --memory 4096 \
                  --vcpus 2 \
                  --os-variant fedora32 \
                  --boot hd,cdrom,loader=/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd,loader_ro=yes,loader_type=pflash,nvram=/usr/share/edk2/ovmf/OVMF_VARS.secboot.fd \
                  --disk size=20 \
                  --location https://download.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os \
                  --initrd-inject=kickstart.cfg \
                  --extra-args="ks=file:/kickstart.cfg"
```

The installer usually completes and reboots into a new system after about 20 minutes, depending on the hardware and download mirror speeds. All steps from this point forward can now be completed inside the new Fedora VM.

# Building a kernel module:

To get started, first ensure that basic development tools and libraries are already installed:

```
$ sudo dnf install gcc make kernel-headers kernel-devel
```

Next, create a simple kernel module stub named **kmodhello.c**:

{% highlight c %}
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init hello_start(void)
{
        printk(KERN_INFO "Hello World!\n");
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

# Signing a kernel module:
Fedora's kernel has the [Lockdown feature](https://kernelnewbies.org/Linux_5.4#Kernel_lockdown_mode) enabled to prevent untrusted modules from being loaded:

```
$ sudo insmod kmodhello.ko
insmod: ERROR: could not insert module kmodhello.ko: Operation not permitted
$ journalctl --boot --dmesg | grep insmod
Jun 17 23:14:48 joshua-laptop kernel: Lockdown: insmod: unsigned module loading is restricted; see man kernel_lockdown.7
```

Disabling the loading of arbitrary modules makes some sense from a security standpoint; however, it is an inconvenience as the module must now be signed with self-generated keys.

The first step to signing the kernel module is to create a signing key configuration file:

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
$ openssl req -new \
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

# Enrolling a new key for Secure Boot and Lockdown

Since the kernel module is self-signed, it won't be recognized as a trusted source by Secure Boot or by the kernel. To get around this, the newly-generated key will have to be enrolled:

```
$ openssl x509 -outform der -in certs/kernel_key.crt --out certs/kernel_key.der
$ sudo mokutil --import certs/kernel_key.der
$ reboot
```

The system should now reboot into the UEFI key management utility:

{% include image.html url="/assets/image/mok-management.png" %}

# Loading a trusted kernel module

Once the signing key is enrolled, the kernel module should now be ready for loading and unloading:

```
$ sudo insmod kmodhello.ko
$ lsmod | grep kmodhello
kmodhello              16384  0
$ sudo rmmod kmodhello
$ journalctl --boot --dmesg --lines=3
-- Logs begin at Fri 2020-06-19 21:48:25 EDT, end at Fri 2020-06-19 23:24:01 EDT. --
Jun 19 23:11:12 developmentvm.localdomain kernel: kmodhello: loading out-of-tree module taints kernel.
Jun 19 23:11:12 developmentvm.localdomain kernel: Hello World!
Jun 19 23:19:51 developmentvm.localdomain kernel: Goodbye World!
```

And done! There's a surprising amount of work needed to get a Hello World kernel module going, as most of the work involved had more to do with understanding the underlying system plumbing instead of writing actual code. 

There is definitely a lot of upfront learning involved here, but at least adding functionality on top should be a relatively simple exercise. which shall be demonstrated in an upcoming post. Stay tuned!
