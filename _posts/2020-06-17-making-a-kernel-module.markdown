---
layout: post
title:  "Making a simple kernel module"
date:   2020-06-17 20:20:00 -0400
categories: jekyll update
---

The Linux kernel is considered to be monolithic in design, however much of its functionality is implemented as kernel modules which can typically be loaded and unloaded on demand without requiring a reboot. Writing kernel modules requirs compiling against kernel headers, which in turn often requires frequent recompilation or even source code updates when maintaining out-of-tree modules due to the kernel's unstable API. Writing kernel modules may seem daunting at first, but once the conventions are understood it can actually be fairly straightforward.

This post shall serve as a starting point by using standard kernel interfaces to create the simplest possible example module. 

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
filename:       /home/jstone/Projects/kernel-module-hello/kmodhello.ko
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
