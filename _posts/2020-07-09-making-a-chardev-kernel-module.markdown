---
layout: post
title:  "Making a character device kernel module"
date:   2020-07-09 20:20:00 -0400
categories: jekyll update
---

**Disclaimer: this post is a WIP. Stay tuned!**

The [introduction on kernel modules](/posts/2020/06/17/making-a-simple-kernel-module) focused primarily on how to integrate an out-of-tree driver into a modern Linux system, using only the bare miminum code to demonstrate a working module. 

With the basic kernel development framework laid out, it's now feasible to work on a more complex driver implementation. This post shall use more extensive kernel interfaces to implement character device driver, which will be used to demonstrate how to create an device file that can respond to typical file operations by a user process.


# Writing the driver code

First, the individual header files and function signatures. There are many more headers to be included compared to the module from the previous post as there are numerous interfaces required for a driver to be able to interact with sysfs, procfs, and devfs:

{% highlight c %}

#include <linux/module.h> 
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/kdev_t.h>
#include <linux/cdev.h>

static int chardev_start(void);
static void chardev_end(void);
static void cleanup(void);

static int uevent(struct device *dev, struct kobj_uevent_env *env);
static int device_open(struct inode *, struct file *);
static int device_release(struct inode *, struct file *);
static ssize_t device_read(struct file *, char *, size_t, loff_t *);
static ssize_t device_write(struct file *, const char *, size_t, loff_t *);

{% endhighlight %}

Now some C macros will be defined for naming the various paths on the filesystem the driver will be registering to:

{% highlight c %}

#define CHRDEV_NAME "chrdev"    // Device name will appear in /proc/devices
#define DEVICE_NAME "chardev"   // Device will be located at /dev/chardev
#define CLASS_NAME "chardevice" // Device will be located at /sys/class/chardevice
#define SUCCESS 0
#define BUF_LEN 20              // Maximum buffer string length

static int Device_Open = 0;	// Check if device is open in case of concurrent access

static dev_t first;             // Global variable for the first device number
static struct cdev c_dev;       // Global variable for the character device structure
static struct class *cl;        // Global variable for the device class

static char msg[BUF_LEN];
static char *msg_Ptr;

static int counter = 5;

// Permission docs found at https://man7.org/linux/man-pages/man2/fchmod.2.html
#define READ_WRITE_USER S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP
#define READABLE_EVERYONE S_IRUSR|S_IRGRP|S_IROTH

module_param(counter, int, READ_WRITE_USER);
MODULE_PARM_DESC(counter, "Test param (default = 5)");

static int uevent(struct device *dev, struct kobj_uevent_env *env)
{
    add_uevent_var(env, "DEVMODE=%#o", READABLE_EVERYONE);
    return 0;
}

{% endhighlight %}


By convention, character devices are defined with the file_operations struct which implements common operations such as reading and writing. These struct members are implicitly-defined; to keep the driver implementation simple, only the following will be implemented:
{% highlight c %}

static struct file_operations fops = {
	.owner   = THIS_MODULE,
	.read    = device_read,
	.write   = device_write,
	.open    = device_open,
	.release = device_release
};

{% endhighlight %}

A more complete driver could explicitly implement other struct members which in turn can be found by running the following command:

```
$ grep -Pzo "struct file_operations {(.|\n)*__randomize_layout;\n" /usr/src/kernels/$(uname -r)/include/linux/fs.h
struct file_operations {
	struct module *owner;
	loff_t (*llseek) (struct file *, loff_t, int);
	ssize_t (*read) (struct file *, char __user *, size_t, loff_t *);
	ssize_t (*write) (struct file *, const char __user *, size_t, loff_t *);
	ssize_t (*read_iter) (struct kiocb *, struct iov_iter *);
	ssize_t (*write_iter) (struct kiocb *, struct iov_iter *);
	int (*iopoll)(struct kiocb *kiocb, bool spin);
	int (*iterate) (struct file *, struct dir_context *);
	int (*iterate_shared) (struct file *, struct dir_context *);
	__poll_t (*poll) (struct file *, struct poll_table_struct *);
	long (*unlocked_ioctl) (struct file *, unsigned int, unsigned long);
	long (*compat_ioctl) (struct file *, unsigned int, unsigned long);
	int (*mmap) (struct file *, struct vm_area_struct *);
	unsigned long mmap_supported_flags;
	int (*open) (struct inode *, struct file *);
	int (*flush) (struct file *, fl_owner_t id);
	int (*release) (struct inode *, struct file *);
	int (*fsync) (struct file *, loff_t, loff_t, int datasync);
	int (*fasync) (int, struct file *, int);
	int (*lock) (struct file *, int, struct file_lock *);
	ssize_t (*sendpage) (struct file *, struct page *, int, size_t, loff_t *, int);
	unsigned long (*get_unmapped_area)(struct file *, unsigned long, unsigned long, unsigned long, unsigned long);
	int (*check_flags)(int);
	int (*flock) (struct file *, int, struct file_lock *);
	ssize_t (*splice_write)(struct pipe_inode_info *, struct file *, loff_t *, size_t, unsigned int);
	ssize_t (*splice_read)(struct file *, loff_t *, struct pipe_inode_info *, size_t, unsigned int);
	int (*setlease)(struct file *, long, struct file_lock **, void **);
	long (*fallocate)(struct file *file, int mode, loff_t offset,
			  loff_t len);
	void (*show_fdinfo)(struct seq_file *m, struct file *f);
#ifndef CONFIG_MMU
	unsigned (*mmap_capabilities)(struct file *);
#endif
	ssize_t (*copy_file_range)(struct file *, loff_t, struct file *,
			loff_t, size_t, unsigned int);
	loff_t (*remap_file_range)(struct file *file_in, loff_t pos_in,
				   struct file *file_out, loff_t pos_out,
				   loff_t len, unsigned int remap_flags);
	int (*fadvise)(struct file *, loff_t, loff_t, int);
} __randomize_layout;
```

{% highlight c %}
static void cleanup(void) {
        cdev_del(&c_dev);
        device_destroy(cl, first);
        class_destroy(cl);
        unregister_chrdev_region(first, 1);
}
{% endhighlight %}


{% highlight c %}

{% endhighlight %}


A character device must be able to open so that a program like `cat` can attempt to read its contents. The following function checks if the device is open with a global variable representing open/close state, and will in turn respond depending on the state:

{% highlight c %}
static int device_open(struct inode *inode, struct file *file)
{
	if (Device_Open) {
		return -EBUSY;
        }
	Device_Open++;
	if (counter == 0) {
		sprintf(msg, "Blastoff!\n");
	} else {
		sprintf(msg, "%d\n", counter);
		counter--;
	}
	msg_Ptr = msg;

	return SUCCESS;
}

{% endhighlight %}

Devices and files generally should be checked to see if they're opened to avoid issues with concurrent access. This driver will copy a string into `msg`, when is then accessed when attempting to read the device:

{% highlight c %}
static ssize_t device_read(struct file *filp, char *buffer, size_t length, loff_t * offset)
{
	int bytes_read = 0;

	if (*msg_Ptr == 0) {
		return 0;
	}

	while (length && *msg_Ptr) {
		put_user(*(msg_Ptr++), buffer++);

		length--;
		bytes_read++;
	}
	return bytes_read;
}
{% endhighlight %}


The code for `device_read()` may seem a bit complicted, but the gist is that the `msg` string gets copied into userspace with `put_user()`, and by convention its byte length will be returned to signify success unless it was zero bytes long.

Once the file contents have been read, it's now time to release the device so that other programs may access it. Implementing this logic is very simple:

{% highlight c %}
static int device_release(struct inode *inode, struct file *file)
{
	Device_Open--;
	return SUCCESS;
}
{% endhighlight %}

The character device is going be to read-only for now, so it should print an informative log message and return an error status:

{% highlight c %}
static ssize_t device_write(struct file *filp, const char *buff, size_t len, loff_t * off)
{
	printk(KERN_ALERT "Sorry, device isn't writable.\n");
	return -EINVAL;
}
{% endhighlight %}

Now it's time to bring it all together. There's some setup required for allowing the character device to tie into procfs, devfs, and sysfs once the kernel module is initialized:

{% highlight c %}
static int __init chardev_start(void) 
{
	int ret;
	struct device *dev_ret;

       	printk(KERN_INFO "Initializing countdown module with starting value %d.\n", counter);
	if ((ret = alloc_chrdev_region(&first, 0, 1, CHRDEV_NAME)) < 0)
	{
		return ret;
	}
	if (IS_ERR(cl = class_create(THIS_MODULE, CLASS_NAME)))
	{
		unregister_chrdev_region(first, 1);
		return PTR_ERR(cl);
	}
	cl->dev_uevent = uevent;
	if (IS_ERR(dev_ret = device_create(cl, NULL, first, NULL, DEVICE_NAME)))
	{
		class_destroy(cl);
		unregister_chrdev_region(first, 1);
		return PTR_ERR(dev_ret);
	}
	cdev_init(&c_dev, &fops);
	if ((ret = cdev_add(&c_dev, first, 1)) < 0)
	{
		device_destroy(cl, first);
		class_destroy(cl);
		unregister_chrdev_region(first, 1);
		return ret;
	}
	return SUCCESS;
}
{% endhighlight %}

The kernel module in turn must do some cleanup on shutdown:

{% highlight c %}
static void cleanup(void) {
        cdev_del(&c_dev);
        device_destroy(cl, first);
        class_destroy(cl);
        unregister_chrdev_region(first, 1);
}

static void __exit chardev_end(void)
{
	cleanup();
	printk(KERN_INFO "Done!");
}
{% endhighlight %}

