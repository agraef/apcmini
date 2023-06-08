# AKAI APC mini driver for Pd

This external implements a simplified interface between Pd and the APC mini. It works with both the [original version](https://www.akaipro.com/apc-mini) and the [mk2 version](https://www.akaipro.com/apc-mini-mk2) of the device, and manages on its own all the special keys and corresponding modes, including the softkeys and fader assignment. Controller input is translated to symbolic messages to be interpreted by the host application. The host then only needs to provide application-specific data about the track modes (solo, mute, etc.) and the status of the launchpad.

The external is written in Lua, so [pd-lua](https://agraef.github.io/pd-lua/) is required (and Pd, of course; both [vanilla Pd](http://msp.ucsd.edu/software.html) and [Purr Data](https://agraef.github.io/purr-data/) will work, the latter already includes pd-lua). MIDI data is encoded in [SMMF](https://bitbucket.org/agraef/pd-smmf), the corresponding midi-input and midi-output abstractions are included.

More details about the message protocol can be found in the comment section at the beginning of the apcmini.pd_lua file in the lib subdirectory. Please also check the included help patch for an introductory example showing how to use the external.

A full-blown example can be found in ardour-clip-launcher.pd which interfaces the APC mini to Ardour's clip launcher; documentation for this patch is in the ardour-clip-launcher.md file.

Copyright © 2023 by Albert Gräf \<<aggraef@gmail.com>\>, distributed under the GPL (see COPYING)
