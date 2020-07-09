---
layout: post
title:  "X1 Carbon Gen8 review"
date:   2020-07-08 21:15:00 -0400
categories: kernel-modules
---

{% include image.html url="/assets/image/x1-carbon-1.jpg" %}

For the past month, I've been running the latest generation X1 Carbon from Lenovo. Since Lenovo has been making announcements about [shipping Linux on their machines](https://fedoramagazine.org/coming-soon-fedora-on-lenovo-laptops/) and expanding on their [certifications](https://news.lenovo.com/pressroom/press-releases/lenovo-brings-linux-certification-to-thinkpad-and-thinkstation-workstation-portfolio-easing-deployment-for-developers-data-scientists/), I decided to purchase the [X1 Carbon Gen8](https://www.lenovo.com/us/en/laptops/thinkpad/thinkpad-x/X1-Carbon-Gen-8-/p/22TP2X1X1C8) as my newest daily driver.

In today's post, I'll go over my findings with the X1 Carbon Gen8. Here goes!

# Chassis:

The X1 Carbon has excellent build quality. Despite being an ultrathin laptop, it feels quite solid in my hands and is well-balanced when grasping with one hand. Weighing in at 2.38 lbs, it's much lighter and smaller than my T480 (4.03 lbs) which makes it more ideal for traveling. The laptop doesn't flex or wobble when typing either.

For extra points, I've tested how rigid the lid is while shaking the laptop in mid-air. The lid will immediately snap back into position once the laptop is stationary, further suggesting high build quality.

# Ports:

The number of ports is quite good compared to other ultrathin laptops like the Dell XPS 13 and Macbook. Two USB-C ports are available which are its main method of charging (very useful for sharing cables too). There are two also standard USB-A ports, as well as an HDMI port and headphone jack. There isn't native ethernet which is a bit of a disappointment, but fortunately this is mitigated with a dongle that comes with the laptop. There isn't an SD card slot or even a microSD slot either, but the SD card reader dongle I already use with my desktop can be used instead. 

# Monitor:

The FHD 400 nit screen is very good. [Costa Rica 4K](https://www.youtube.com/watch?v=LXb3EKWsInQ) -- which is typically used as a benchmark for demonstrating display quality -- looks quite nice on it. I don't have a [colorimeter](https://www.amazon.com/X-Rite-Color-Munki-Smile-ColorMunki/dp/B009APMNB0/) on hand for measuring the full capabilities of the screen in a more empirical fashion, but it should be capable of showing the full sRGB range as well as covering most of Adobe RGB. The 4K HDR 500 nit configuration should be more ideal if color reproduction and HDR are of utmost importance. 

# Keyboard:

Thinkpads are well renowned for their keyboards, and the keyboard on the Carbon is no exception. The keys feel just right to me when typing, not being too mushy or too clicky. They also don't give off much noise, which is very much appreciated when working in a quiet room.

# Speakers:

I'm quite happy with the quality of the Dolby Atmos speakers. Usually laptop speakers are a disappointment to me, but the speakers on the Carbon are more than capable of handling different genres of music. The speaker alignment being upward-facing instead of side-facing as seen in other thinkpads also makes it better for watching videos and listening to music with other people. 

It does seem a bit lacking in [bass-heavy music](https://www.youtube.com/watch?v=qgRr0CLFhaw), but the built-in
DAC is more than capable of driving a pair of [good-quality headphones](https://www.amazon.com/Audio-Technica-ATH-M50xBT-Wireless-Bluetooth-Headphones/dp/B07HKVCVSY/). I might have to make an update on this later because Dolby Atmos support on Linux appears to be a work in progress and may need a preset to have it more closely match the speaker output on [Windows](https://github.com/JackHack96/PulseEffects-Presets/tree/master/irs) in the meantime.

# Battery:

I can get a decent amount of battery life from the 51Wh battery, usually about 14 hours with light usage and medium screen brightness on stock Fedora. I think I could easily squeeze more battery life out of it if I installed Powertop or TLP, but hopefully battery optimizations land in upstream so no extra work needs to be done by the time Fedora 33 comes out.

# Noise & thermals:

This laptop is quiet! Even when playing 1080p@60fps video in a quiet room, the fan don't make any audible noise.

Multi-core workloads like code compiling also don't seem to be an issue on this laptop. Sensors report roughly 70C during such workloads, and the fan gives off a low amount of noise that's well within acceptable range.

# Performance & Stability:

The i7-10510U performs quite well. It appears to be about as fast as the R5 2600X in my desktop at compile tasks, which is especially impressive considering this is in an ultrathin laptop!

It also remains responsive for multitasking while compiling, still being able to play fullscreen video in Firefox while dropping a few frames when attempting to switch tabs (considering it's able to sustain full 60fps playback otherwise while most cores are saturated, this is still acceptable).

Suspend support on the Carbon is rock solid too. I've repeatedly closed the lid and opened it back up to have it immediately wake up from suspend, making it ideal for keeping around on standby for when I want to look something up.

# Vendor Support:

Almost everything about this laptop works out of the box on Fedora, with one exception being that firmware for the fingerprint sensor which at the time of release was available in the [LVFS testing repository](https://wiki.archlinux.org/index.php/Lenovo_ThinkPad_X1_Carbon_(Gen_7)#Fingerprint_sensor) for enabling fingerprint login & authentication in Gnome Shell. It appears that this is no longer necessary now that LVFS has [stable firmware builds](https://fwupd.org/lvfs/devices/com.synaptics.prometheus.firmware) available 

Since I bought the Carbon before Lenovo started offering a configuration with Linux preinstalled, I ended up paying for a Windows license. Lenovo support however was quite understanding of my situation in having no desire to run Windows on it, and provided a refund for the license. I think this is noteworthy since they previously didn't offer a refund when I previously bought my T480 a few years ago.

Enabling hardware [decoding support for improving CPU usage and battery life](https://mastransky.wordpress.com/2020/06/03/firefox-on-fedora-finally-gets-va-api-on-wayland/) is also trivial. Firefox appears to consume 15%-25% CPU during fullscreen 1080p@60fps video playback, and VLC is usually using 8%-15% for the same video. It's worth noting that Firefox's accelerated decoding support is still bleeding-edge and probably has room for optimizations, and I'd imagine VLC could be even more efficient once it has native Wayland support.

# Conclusion:

Overall, I'm very happy with this laptop, both on the software and hardware side. Despite being brand new, the out-of-the-box Linux support has been some of the best I've seen in a long time and the tweaks I've had to do for it were quite minimal. I think once Lenovo sorts out their official Linux support (I still don't see it offered as an OS option in the customization page), they'll have a truly stellar product that they can market to Linux users as a daily driver.

{% include image.html url="/assets/image/x1-carbon-2.jpg" %}

