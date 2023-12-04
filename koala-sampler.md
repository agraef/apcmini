
# koala-sampler

This Pd patch based on the apcmini Lua external implements a control surface for Marek Bereza's popular [Koala Sampler](https://www.koalasampler.com/) application. The AKAI APC mini is a capable controller for this purpose, but since Koala Sampler (henceforth just called "Koala") has no built-in support for it, and the device offers no built-in programmability, some external program logic is required to provide a suitable interface between the APC mini and Koala, which what this patch provides.

## Requirements

This program is implemented as a Pd patch, and includes an external written in Lua, so you'll need Pd (any recent version of vanilla [Pd](http://msp.ucsd.edu/software.html) or [Purr Data](https://agraef.github.io/purr-data/) will do) and Pd-Lua. Purr Data comes with a suitable version of Pd-Lua included. When using vanilla Pd, get the latest Pd-Lua version from Deken, or directly from https://agraef.github.io/pd-lua/. (Pd-Lua 0.11.5 and later have been tested.)

## Setup

The patch will work with both the original version of the APC mini and the mk2 version, and will try to detect which version you have during initialization with some sysex magic. If the auto-detection doesn't work, you can also explicitly set the model in the patch by adding a creation argument to the `apcmini` object in the patch (by default, the mk1 version is assumed, add `1` as an argument if you have the mk2).

### Connecting Pd and the APC mini

You also need to make sure that Pd's first MIDI input and output are hooked up to the APC mini's MIDI output and input, respectively. Note that the APC mini mk2 actually has *two* MIDI input and output ports; you need to connect to the *first* one in either case (labeled "APC mini mk2 Control").

### Connecting Pd and Koala

The patch assumes that a *second* MIDI output of Pd is connected to Koala's MIDI input. There are different ways to go about this, depending on whether you're using the Android/iOS app of Koala or whether you're running Koala on the same device as Pd, or on the same local network.

- To connect to the app on your *smartphone or tablet*, you need to set up some kind of MIDI connection between computer and smartphone, e.g., via USB or Bluetooth (via MIDI BLE). The former option requires that PC and smartphone can transmit and receive MIDI data over USB (most devices nowadays have that capability, although you might need some special OTG USB adapter on the smartphone side to make that work); the process will be the same as when hooking up a MIDI keyboard to your smartphone. The latter option is probably the easiest way if both your computer and smartphone have built-in MIDI BLE capability (if not, the [CME WIDI](https://www.cme-pro.com/widi-premium-bluetooth-midi/) products may prove helpful).
- If both Pd and Koala are on the *same local network*, then they can be connected via [RTP MIDI](https://en.wikipedia.org/wiki/RTP-MIDI). This is an Apple protocol and thus readily supported on iOS and macOS devices, but is also available on other platforms using 3rd party software (for Android, RTP MIDI support is provided by Abraham Wisman's excellent [MIDI HUB](https://abrahamwisman.com/midihub) application which also supports MIDI BLE).
- If both Pd and Koala are running on the *same computer*, then in theory they can be connected using a MIDI loopback (readily available on Linux and Mac, and also on Windows using 3rd party software). However, you will have to make sure that Koala *only* receives Pd's second MIDI output and nothing else, which is problematic with the present Koala version which tries to read MIDI data from *all* input devices. For the time being, until Koala gets some more elaborate MIDI device setup, we recommend running Pd and Koala on different devices and using either MIDI BLE or RTP MIDI instead.

### Koala MIDI Mapping

Finally, you need to set up Koala's MIDI mapping. The repository includes a midiMapping.json file which you can copy to the location on your device where Koala keeps its configuration data (on Android this is usually in /Android/data/com.elf.koalasampler/files/settings, on macOS you can find the configuration data in the Documents/Koala folder). This has all the pads, sliders and buttons already set up so that, once you enable MIDI mapping in Koala's settings, the controls will work as described under Usage below.

## Usage

TBD



Copyright © 2023 by Albert Gräf \<<aggraef@gmail.com>\>, distributed under the GPL (see COPYING). Please also check my GitHub page at https://agraef.github.io/.
