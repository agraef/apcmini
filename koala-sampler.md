
# koala-sampler controller patch

Copyright © 2023 by Albert Gräf \<<aggraef@gmail.com>\>, distributed under the GPL (see COPYING). Please also check my GitHub page at https://agraef.github.io/.

This Pd patch implements a control surface for Marek Bereza's popular [Koala Sampler](https://www.koalasampler.com/) application. The AKAI APC mini is a capable controller for this purpose, but since Koala Sampler (henceforth just called "Koala") has no built-in support for it, and the device offers no built-in programmability, some external program logic is required to provide a suitable interface between the APC mini and Koala. Which is what this patch provides.

## Requirements

This program is implemented as a Pd patch, and includes the apcmini external which is written in Lua, so you'll need Pd (any recent version of vanilla [Pd](http://msp.ucsd.edu/software.html) or [Purr Data](https://agraef.github.io/purr-data/) will do) and Pd-Lua. (Pd-Lua 0.11.5 and later have been tested.) Purr Data comes with a suitable version of Pd-Lua included. When using vanilla Pd, get the latest Pd-Lua version from Deken, or directly from https://agraef.github.io/pd-lua/; you'll also want to add `pdlua` to the startup libraries. Moreover, you need iemguts from Deken for the closebang object.

For the patch to work, you need to set up a few MIDI connections between the APC mini and Pd on one side, and Pd and Koala on the other side. You'll also have to configure the MIDI mapping in Koala. This is described in the *Setup* section below.

We recommend using the mk2 version of the APC mini, since its pads have RGB lighting and are much better suited for finger drumming. However, the patch will also work with the original version of the APC mini, and will try to detect which version you have during initialization with some sysex magic. If the auto-detection doesn't work, you can also explicitly set the model by adding a creation argument to the `apcmini` object in the patch (by default, the mk2 version is assumed, add `0` as an argument if you have the mk1).

## Setup

### Connecting Pd and the APC mini

You first need to make sure that Pd's first MIDI input and output are hooked up to the APC mini's MIDI output and input, respectively. Note that the APC mini mk2 actually has *two* MIDI input and output ports; you need to connect to the *first* one in either case (labeled "APC mini mk2 Control").

In addition, to use the note mode on the APC mini mk2, you also need to connect the *second* output port of the APC mini (labeled "APC mini mk2 Notes") to Pd's *second* MIDI input. The patch will take care of forwarding the note data to Koala on Pd's second output port (see below).

### Connecting Pd and Koala

The patch outputs all MIDI data destined for Koala on Pd's *second* MIDI output, so you'll have to connect that port to Koala's MIDI input. There are different ways to go about this, depending on whether you're using the Android/iOS or the Linux/Mac/Windows version of Koala, and whether you're running Koala on the same device as Pd or on the same local network.

- To connect to the app on your *smartphone or tablet*, you need to set up some kind of MIDI connection between the computer on which you run Pd and the smartphone, e.g., via USB or Bluetooth (using [MIDI BLE](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy)). The latter option is probably the quickest way if both your computer and smartphone support MIDI over Bluetooth (if not, the [CME WIDI](https://www.cme-pro.com/widi-premium-bluetooth-midi/) dongles can help with that). The former option requires that both PC and smartphone can transmit and receive MIDI data over USB. Most devices nowadays have that capability, although some smartphones might require a special USB adapter to make that work. The process will be the same as when hooking up a MIDI keyboard to your smartphone using a USB cable.
- If both Pd and Koala are on the *same local network*, then they can be connected via [RTP MIDI](https://en.wikipedia.org/wiki/RTP-MIDI). This is an Apple protocol and thus readily supported on iOS and macOS devices, but is also available on other platforms using 3rd party software. E.g., for Android, RTP MIDI support is provided by Abraham Wisman's excellent [MIDI Hub](https://abrahamwisman.com/midihub) application which also supports MIDI BLE. For Linux, you can use [rtpmidid](https://github.com/davidmoreno/rtpmidid). For Windows, get Tobias Erichsen's [rtpMIDI](https://www.tobias-erichsen.de/software/rtpmidi.html).
- If both Pd and Koala are running on the *same computer*, then in theory they can be connected using a MIDI loopback (readily available on Linux and Mac, and also on Windows using [3rd party software](https://www.tobias-erichsen.de/software/loopmidi.html)). However, you will have to make sure that Koala *only* receives Pd's second MIDI output and nothing else. This is basically impossible with the present Koala version (1.4081 at the time of this writing) which tries to read MIDI data from *all* input devices. (But see *Bugs and Quirks* below for some workarounds.)

### Koala MIDI Mapping

Finally, you need to set up Koala's MIDI mapping. The distribution includes a midiMapping.json file which you can copy to the location on your device where Koala keeps its configuration data (on Android this is usually in /Android/data/com.elf.koalasampler/files/settings, on Linux and macOS you can find the configuration data in the Documents/Koala folder). This has all the pads, faders, and buttons already set up so that, once you enable MIDI mapping in Koala's settings, the controls will work as described under Usage below.

## Usage

Once the device connections have been set up, the APC mini should light up as soon as you open the koala-sampler.pd patch in Pd. As a quick check of the connection to the sampler, you should be able to play the pads in the Koala app with the 4x4 grid in the lower left corner of the APC mini. Most of the other functionality assumes that you have loaded and enabled the provided MIDI mapping in Koala.

### Pads and Sequence Launchers

Initially, the pads are laid out on the device as follows:

> 1&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;2
>
> 3&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;4
>
> A&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;B

In the upper half, you find all 4 banks of sequence launchers in different colors, each being a 2x4 grid with which you can launch the sequences in the corresponding bank. The lower half provides you with bank A and B of the 4x4 sample grids side by side and in different colors. These can be switched using the bank left/right arrow keys beneath the launchpad, cycling through the available bank combinations: A/B, B/C, and C/D. The lighting of the left/right buttons indicates which of the bank combinations is in effect, by denoting the directions in which you can move.

### Note and Drum Modes

The note and drum modes of the APC mini mk2 are also supported. Note mode (SHIFT+NOTE) works as usual (see the APC mini manual for details) and comes in handy when playing a sample in Koala's keyboard mode. Pressing SHIFT+NOTE again exits note mode.

In drum mode (SHIFT+DRUM) the pads change to a layout which shows all 4x4 sample grids from left to right and bottom to top, as follows:

> C&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;D
>
> A&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;B

This enables you to play all four pad banks simultaneously in Koala. Pressing SHIFT+DRUM again exits drum mode and gives back access to the sequence launchers.

### Fader Assignments

To make the faders work, you need to press SHIFT and one of the FADER CTRL buttons beneath the launch pad. The four available assign modes are mapped as follows:

- VOLUME: The first 4 faders control the corresponding volume sliders of bus 1-4 in the Koala mixer on the PERFORM page. The fifth fader controls the volume slider of the main bus.
- PAN: The first three faders control Koala's VOL, PITCH, and PAN knobs on the SAMPLE page. The 7th and 8th faders control sample start and length in the sample editor.
- SEND, DEVICE: The 8 faders control the VANILLA and STRAWBERRY performance effects on the PERFORM page, respectively.

In any case, pressing SHIFT and the same FADER CTRL button again disables the fader assignment, so that you can play on the pads without changing a parameter by accidentally hitting one of the faders.

### Solo, Mute and Transport Buttons

Additional mixer functionality is available using SHIFT and the SOLO and MUTE softkeys on the right-hand side of the APC mini. In these modes, the first 5 buttons below the cliplauncher let you control the solo/mute state of buses 1-4 and the main bus in the Koala mixer.

Finally, the 8 scene buttons on the right (without pressing SHIFT) can be assigned freely to various other actions which toggle state in Koala. In the distributed MIDI mapping I have set up four of these buttons as follows (but of course you can change all of these mappings as you see fit):

- Scene 2 and 3 (labeled SOLO/MUTE on the mk2): Holding these and pressing a pad on the SAMPLE or SEQUENCE page lets you solo and mute individual pads. This works like the SOLO/MUTE buttons on these pages in Koala itself (these appear if you enable the "Show Mute/Solo" option on the EXTRAS page in the settings).
- Scene 8 (STOP ALL CLIPS) is mapped to Koala's play/stop control, while the scene 7 button right above it toggles Koala's record control.

## MIDI Implementation

The following table lists all the MIDI messages that the apcmini patch spits out on the second MIDI output, along with their default mapping in the distributed midiMapping.json file:

| Message             | Channel | Default Assignment                        |
| ------------------- | ------- | ----------------------------------------- |
| NOTE 36-51 (C1-D#2) | 10      | Pad bank A                                |
| NOTE 36-51 (C1-D#2) | 11      | Pad bank B                                |
| NOTE 36-51 (C1-D#2) | 12      | Pad bank C                                |
| NOTE 36-51 (C1-D#2) | 13      | Pad bank D                                |
| NOTE 52-59 (E2-B2)  | 10      | Sequence bank 1                           |
| NOTE 52-59 (E2-B2)  | 11      | Sequence bank 2                           |
| NOTE 52-59 (E2-B2)  | 12      | Sequence bank 3                           |
| NOTE 52-59 (E2-B2)  | 13      | Sequence bank 4                           |
| NOTE 36-99 (C1-D#6) | 1       | Keyboard notes (NOTE mode, mk2)           |
| CC 57-64            | 16      | Mixer solo (SHIFT+SOLO)                   |
| CC 65-72            | 16      | Mixer mute (SHIFT+MUTE)                   |
| NOTE 73-74 (C#4-D4) | 16      | Pad solo/mute (scene buttons 2 and 3)     |
| NOTE 78-79 (F#4-G4) | 16      | Record, Play/Stop (scene buttons 7 and 8) |
| CC 21-29 (0-127)    | 16      | Mixer volume (SHIFT+VOLUME)               |
| CC 30-38 (0-127)    | 16      | Sample controls (SHIFT+PAN)               |
| CC 39-47 (0-127)    | 16      | Performance faders page 1 (SHIFT+SEND)    |
| CC 48-56 (0-127)    | 16      | Performance faders page 2 (SHIFT+DEVICE)  |

Note that the default MIDI mapping leaves quite a few of the controls unassigned at present (such as the faders 6-9 in VOLUME mode, and the scene buttons 1 and 4-6), so you can map these to whatever Koala function you need which isn't covered in the default bindings.

## Bugs and Quirks

As mentioned above, right now it is difficult to run the koala-sampler patch and Koala on the same (Linux, Mac, or Windows) computer, because Koala insists on connecting to *all* available MIDI inputs. It goes without saying that this kind of setup can easily wreak havoc, because Koala sees a whole lot of additional MIDI data that may interfere with the MIDI data from the patch that it is intended to see.

On Linux, it is possible to work around this obstacle, because ALSA has utilities to control exactly which MIDI devices a running application is connected to. Thus, on Linux you want to disable all of Koala's ALSA MIDI input connections except the connection to Pd's second output port. The most convenient way to achieve this is to use the [aj-snapshot](https://aj-snapshot.sourceforge.io/) program with the koala-alsa.xml snapshot file included in the distribution. Basically, after launching Koala just run `aj-snapshot -rax koala-alsa.xml` in the terminal and you should be set. Note that you'll have to re-run this command every time you launch Koala. Please check the snapshot file for details; you may also want to edit this file to adjust it to your setup.

Unfortunately, I don't know of any such procedure for Mac and Windows. That said, the MIDI implementation described above has been designed so that at least *some* of the functionality provided by the patch will work even in this situation. Specifically, the provided MIDI mapping will make sure that Koala only interprets the MIDI data that it's supposed to see, as long as you don't switch Koala to keyboard mode.

However, if you do use Koala's keyboard mode (accessible using the keyboard button above the pads on the SEQUENCE page), then Koala will interpret all MIDI note data from all its inputs. In this case you want to turn off any special processing done by the koala-sampler patch while this mode is active. This can be done quickly by unchecking the big green "MIDI I/O" toggle in the patch. (Even then, pressing any of the buttons on the APC mini will send MIDI note data to Koala, so it's better to just not touch the controller at all while Koala is in keyboard mode.)
