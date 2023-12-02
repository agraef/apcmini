local apcmini = pd.Class:new():register("apcmini")

local pdx = require 'pdx'
-- for debugging purposes
--local inspect = require 'inspect'

-- apcmini driver: Please check the included help patch for examples. This
-- external expects SMMF MIDI input on the single inlet and produces feedback
-- as SMMF MIDI output on the single outlet. To these ends, they are to be
-- hooked up to the 1st (control) MIDI port of the apcmini via the SMMF
-- midi-input and midi-output abstractions. The external then performs the
-- following functions:

-- Mapping of the scene and track buttons. These are different between the
-- apcmini mk1 and mk2. The model can be set explicitly or inferred from an
-- MMC identity enquiry reply, using the `model` message (see below).

-- Color mapping. The external understands both mk1 and mk2 color
-- specifications (encoded using the `pad` message, see below) and will map
-- them to what seems appropriate depending on the device model. If the device
-- matches the type of color specification, it will be passed through
-- unchanged. For mk1 -> mk2 conversion, the six color values of the mk1 are
-- mapped to the corresponding color specifications of the mk2. Conversely,
-- mk2 RGB color values are mapped to a mk1 color spec that comes reasonably
-- close (which obviuosly is a rather rough approximation, given that the mk2
-- uses a much more extensive RGB scheme involving both velocities and MIDI
-- channels).

-- Management of the shifted softkeys (CLIP STOP, SOLO, MUTE, REC ARM, SELECT,
-- STOP ALL CLIPS). These determine the function of the track buttons in the
-- bottom row. The external manages all required internal state of the buttons
-- including feedback to the device, and outputs special (non-SMMF) messages
-- depending on the current mode of the track buttons (see below).

-- Management of the note and drum modes (mk2 only): These are special
-- built-in modes of the apcmini mk2 which change the grid to an isomorphic
-- keyboard layout and a drumkit pad area, respectively. The external reports
-- switches of the internal mode back on its outlet via a `mode` message, and
-- also allows to change the internal mode programmatically with a `mode`
-- message to its inlet (see below).

-- Special (non-SMMF) input messages:

-- `bang`: Reports all internal state as four messages (`model`, `mode`,
-- `key`, and `assign`, see below). Also updates the track buttons and the
-- status of the softkeys, in case they got messed up.

-- `model`: When invoked without argument, the external sends an MMC device
-- enquiry message and automatically sets the model from the identity reply
-- (if any). If the device enquiry succeeds, it also outputs a `model` message
-- with the detected model number as argument. The model can also be set
-- explicitly by sending `model 0` (mk1) or `model 1` (mk2), or by specifying
-- the model as a creation argument.

-- `mode` (mk2 only): Sets the internal device mode to the given argument (0 =
-- launchpad, 1 = note, 2 = drum).

-- `key`: Changes the operation mode of the track buttons to one of the modes
-- supported by the shifted softkeys (0 = default = none selected, 1 = clip
-- stop, 2 = solo, 3 = mute, 4 = rec arm, 5 = select).

-- `assign`: Changes the fader assignment (0 = off, 1 = volume, 2 = pan, 3 =
-- send, 4 = device).

-- `stop`, `solo`, `mute`, `rec`, `sel`: Manages the status of the track
-- buttons in the corresponding operation mode as set with the softkeys. The
-- external can't possibly know about these, so the application needs to
-- provide this data (if it doesn't, the buttons will stay unlit). The first
-- argument is the track/column number in the range 0..7, and the second
-- argument the new status (0 = off, 1 = on).

-- `banks`: Manages the status of the bank up/down/left/right buttons. Again,
-- the external can't possibly know about these, so the application needs to
-- provide this data (if it doesn't, the buttons will stay unlit). The message
-- should pass 4 status values (0 = off, 1 = on), one for each of the buttons.

-- `pad`: Changes the color of the given pad on the grid. This message can
-- take 2 or 3 arguments, depending on whether the mk1 or mk2 color
-- specification system is used. The first argument is always the pad number
-- in the range 0..63 (64..127 when in drum mode), numbering the pads
-- consecutively (8 per row, starting at the bottom of the grid). The second
-- argument may indicate the mk1 color spec indicating the MIDI velocity (0 =
-- off, 1 = green, 2 = green-blink, 3 = red, 4 = red-blink, 5 = orange, 6 =
-- orange-blink).

-- If three arguments are given, this indicates a mk2 color spec in the format
-- discussed in AKAI's "APC mini mk2 - Communication Protocol" document, with
-- the second argument denoting the color a.k.a. MIDI velocity in the range
-- 0..127, and the third argument the brightness/blinking value a.k.a. MIDI
-- channel in the range 1-16. NOTE: If the unit is in drum mode, the MIDI
-- channel should always be set to 10, so the external enforces this no matter
-- what channel you specified. In note mode, the colors of the pads cannot be
-- changed.

-- Special (non-SMMF) output messages:

-- `model`: Reports the detected model number (0 = mk1, 1 = mk2) in response
-- to a successful device identity query initiated with the `model` input
-- message (see above).

-- `mode` (mk2 only): Reports the internal device mode in the single argument
-- (0 = launchpad, 1 = note, 2 = drum).

-- `key`: Reports the operation mode of the track buttons (0 = default =
-- none selected, 1 = clip stop, 2 = solo, 3 = mute, 4 = rec arm, 5 = select),
-- if the mode gets changed by pressing one of the shifted softkey buttons on
-- the device.

-- `pad`: Reports the number in the range 0-63 of a pad pressed by the user.

-- `scene`. Reports the scene (a.k.a. row) number in the range 0..7 if one of
-- the (unshifted) scene buttons is pressed.

-- `bank-up`, `bank-down`, `bank-left`, `bank-right`: These parameter-less
-- messages are output when the bank change buttons in the bottom row are
-- pressed in the default operation mode (key = 0).

-- `assign`: Reports the current fader assignment (1..4, see above) if one of
-- the corresponding buttons in the bottom row is pressed in default operation
-- mode.

-- `stop`, `solo`, `mute`, `rec`, `sel`: If one of the track buttons is
-- pressed in non-default mode, these messages are output with the grid column
-- in the range 0-7 as argument, depending on which operation mode (key > 0)
-- is currently active.

-- `stop-all`: This parameter-less message is output when the (shifted) STOP
-- ALL CLIPS softkey is pressed.

-- `vol`, `pan`, `send`, `dev`: These messages report fader values (0..127),
-- depending on the current fader assignment (assign > 0). The first argument
-- is the track/column number in the range 0..8 (with the value 8 denoting the
-- master fader), the second argument the fader value.

function apcmini:initialize(sel, atoms)
   self.inlets = 1
   self.outlets = 1
   -- enable the reload callback
   pdx.reload(self)
   -- internal state
   self.shift = 0 -- SHIFT key pressed (0 or 1)
   self.model = 1 -- 0 = mk1, 1 = mk2
   self.mode = 0 -- 0 = launch, 1 = note, 2 = drum, mk2 only
   self.key = 0 -- softkey mode, 0 = default, or 1..5
   self.assign = 0 -- fader assign, 0 = off, 1..4
   self.banks = { 0, 0, 0, 0 }
   self.stop = { 0, 0, 0, 0, 0, 0, 0, 0 }
   self.solo = { 0, 0, 0, 0, 0, 0, 0, 0 }
   self.rec = { 0, 0, 0, 0, 0, 0, 0, 0 }
   self.mute = { 0, 0, 0, 0, 0, 0, 0, 0 }
   self.sel = { 0, 0, 0, 0, 0, 0, 0, 0 }
   self.key_states = { self.stop, self.solo, self.rec, self.mute, self.sel }
   -- creation arguments
   if type(atoms[1]) == "number" then
      self.model = atoms[1] ~= 0 and 1 or 0
   end
   -- button map mk2 => mk1
   self.button_map = {
      [122] = 98 -- SHIFT
   }
   -- track buttons
   for i = 0, 7 do
      self.button_map[100+i] = 64+i
   end
   -- scene buttons
   for i = 0, 7 do
      self.button_map[112+i] = 82+i
   end
   -- reverse button map mk1 => mk2
   self.button_rmap = {}
   for m,n in pairs(self.button_map) do
      self.button_rmap[n] = m
   end
   -- set up a one-shot timer to do necessary initializations once we're fully
   -- instantiated.
   self.clock = pd.Clock:new():register(self, "init")
   self.clock:delay(1000)
   return true
end

function apcmini:finalize()
  self.clock:destruct()
end

function apcmini:from_button(n)
   -- this maps all special buttons from the device to the mk1 numbers
   if self.model == 0 then
      return n
   else
      return self.button_map[n]
   end
end

function apcmini:to_button(n)
   -- this maps all special buttons from the mk1 numbers to the device
   if self.model == 0 then
      return n
   else
      return self.button_rmap[n]
   end
end

function apcmini:update_track_buttons()
   for i = 0, 7 do
      self:outlet(1, "note", {self:to_button(i+64), 0, 1})
   end
   local k = self.key
   if k == 0 then
      local n = self.model==0 and 68 or 64
      if self.assign > 0 then
	 self:outlet(1, "note", {self:to_button(self.assign-1+n), 1, 1})
      end
      n = self.model==0 and 64 or 68
      for i = 0, 3 do
	 self:outlet(1, "note", {self:to_button(i+n),
				 self.banks[i+1], 1})
      end
   else
      -- rec and mute states are swapped on the mk2
      if self.model == 1 and k>=3 and k<=4 then
	 k = 4-k+3
      end
      for i = 0, 7 do
	 self:outlet(1, "note", {self:to_button(i+64),
				 self.key_states[k][i+1], 1})
      end
   end
end

function apcmini:update_softkeys()
   local k = self.key
   for i = 0, 4 do
      local s = k==i+1 and 1 or 0
      self:outlet(1, "note", {self:to_button(i+82), s, 1})
   end
end

function apcmini:update_mode_buttons()
   local k = self.mode
   for i = 0, 1 do
      local s = k==2-i and 1 or 0
      self:outlet(1, "note", {self:to_button(i+87), s, 1})
   end
end

function apcmini:init()
   -- stop the one-shot timer in case we're still waiting for it
   self.clock:unset()
   -- Try to send a mode switch message. This only works on the mk2 and we
   -- can't be sure what model is yet, but we send the message anyway so
   -- that the mode is what we expect it to be. The mk1 should hopefully
   -- ignore this message.
   self:outlet(1, "sysex", {71, 127, 79, 98, 0, 1, self.mode})
   self:update_softkeys()
   self:update_track_buttons()
   self:update_mode_buttons()
end

function apcmini:in_1_bang()
   self:init()
   self:outlet(1, "model", {self.model})
   self:outlet(1, "mode", {self.mode})
   self:outlet(1, "key", {self.key})
   self:outlet(1, "assign", {self.assign})
end

local function midibyte(x, a, b)
   -- default range
   a = (a==nil) and 0 or a
   b = (b==nil) and 127 or b
   -- make int
   x = (x==nil) and a or math.floor(x)
   -- clamp to given range
   return math.max(a, math.min(b, x))
end

function apcmini:in_1_model(args)
   if #args == 0 then
      -- send an MMC device identity enquiry
      self:outlet(1, "sysex", {126, 127, 6, 1})
   elseif type(args[1]) == "number" then
      self.model = args[1] ~= 0 and 1 or 0
   end
end

function apcmini:in_1_mode(args)
   if #args == 0 then
      self:outlet(1, "mode", {self.mode})
   elseif type(args[1]) == "number" and self.model == 1 then
      -- set the device mode (mk2 only)
      self.mode = midibyte(args[1], 0, 2)
      self:update_mode_buttons()
      self:outlet(1, "sysex", {71, 127, 79, 98, 0, 1, self.mode})
   end
end

function apcmini:in_1_key(args)
   if #args == 0 then
      self:outlet(1, "key", {self.key})
   elseif type(args[1]) == "number" and args[1] ~= self.key then
      -- set the operation (softkey) mode (0 means off)
      self.key = midibyte(args[1], 0, 5)
      self:update_softkeys()
      self:update_track_buttons()
   end
end

function apcmini:in_1_assign(args)
   if #args == 0 then
      self:outlet(1, "assign", {self.assign})
   elseif type(args[1]) == "number" and args[1] ~= self.assign then
      -- set the fader assignment (0 means off)
      self.assign = midibyte(args[1], 0, 4)
      self:update_track_buttons()
   end
end

-- from AKAI's "APC mini mk2 - Communication Protocol" document
local vel_rgb_chart = {
   [0] =	0x000000, [21] =	0x00FF00, [42] =	0x001D59,
   [1] =	0x1E1E1E, [22] =	0x005900, [43] =	0x000819,
   [2] =	0x7F7F7F, [23] =	0x001900, [44] =	0x4C4CFF,
   [3] =	0xFFFFFF, [24] =	0x4CFF5E, [45] =	0x0000FF,
   [4] =	0xFF4C4C, [25] =	0x00FF19, [46] =	0x000059,
   [5] =	0xFF0000, [26] =	0x00590D, [47] =	0x000019,
   [6] =	0x590000, [27] =	0x001902, [48] =	0x874CFF,
   [7] =	0x190000, [28] =	0x4CFF88, [49] =	0x5400FF,
   [8] =	0xFFBD6C, [29] =	0x00FF55, [50] =	0x190064,
   [9] =	0xFF5400, [30] =	0x00591D, [51] =	0x0F0030,
   [10] =	0x591D00, [31] =	0x001F12, [52] =	0xFF4CFF,
   [11] =	0x271B00, [32] =	0x4CFFB7, [53] =	0xFF00FF,
   [12] =	0xFFFF4C, [33] =	0x00FF99, [54] =	0x590059,
   [13] =	0xFFFF00, [34] =	0x005935, [55] =	0x190019,
   [14] =	0x595900, [35] =	0x001912, [56] =	0xFF4C87,
   [15] =	0x191900, [36] =	0x4CC3FF, [57] =	0xFF0054,
   [16] =	0x88FF4C, [37] =	0x00A9FF, [58] =	0x59001D,
   [17] =	0x54FF00, [38] =	0x004152, [59] =	0x220013,
   [18] =	0x1D5900, [39] =	0x001019, [60] =	0xFF1500,
   [19] =	0x142B00, [40] =	0x4C88FF, [61] =	0x993500,
   [20] =	0x4CFF4C, [41] =	0x0055FF, [62] =	0x795100,

   [42] =	0x001D59, [72] =	0xFF0000, [102] =	0x0D5038,
   [43] =	0x000819, [73] =	0xBDFF2D, [103] =	0x15152A,
   [44] =	0x4C4CFF, [74] =	0xAFED06, [104] =	0x16205A,
   [45] =	0x0000FF, [75] =	0x64FF09, [105] =	0x693C1C,
   [46] =	0x000059, [76] =	0x108B00, [106] =	0xA8000A,
   [47] =	0x000019, [77] =	0x00FF87, [107] =	0xDE513D,
   [48] =	0x874CFF, [78] =	0x00A9FF, [108] =	0xD86A1C,
   [49] =	0x5400FF, [79] =	0x002AFF, [109] =	0xFFE126,
   [50] =	0x190064, [80] =	0x3F00FF, [110] =	0x9EE12F,
   [51] =	0x0F0030, [81] =	0x7A00FF, [111] =	0x67B50F,
   [52] =	0xFF4CFF, [82] =	0xB21A7D, [112] =	0x1E1E30,
   [53] =	0xFF00FF, [83] =	0x402100, [113] =	0xDCFF6B,
   [54] =	0x590059, [84] =	0xFF4A00, [114] =	0x80FFBD,
   [55] =	0x190019, [85] =	0x88E106, [115] =	0x9A99FF,
   [56] =	0xFF4C87, [86] =	0x72FF15, [116] =	0x8E66FF,
   [57] =	0xFF0054, [87] =	0x00FF00, [117] =	0x404040,
   [58] =	0x59001D, [88] =	0x3BFF26, [118] =	0x757575,
   [59] =	0x220013, [89] =	0x59FF71, [119] =	0xE0FFFF,
   [60] =	0xFF1500, [90] =	0x38FFCC, [120] =	0xA00000,
   [61] =	0x993500, [91] =	0x5B8AFF, [121] =	0x350000,
   [62] =	0x795100, [92] =	0x3151C6, [122] =	0x1AD000,
   [63] =	0x436400, [93] =	0x877FE9, [123] =	0x074200,
   [64] =	0x033900, [94] =	0xD31DFF, [124] =	0xB9B000,
   [65] =	0x005735, [95] =	0xFF005D, [125] =	0x3F3100,
   [66] =	0x00547F, [96] =	0xFF7F00, [126] =	0xB35F00,
   [67] =	0x0000FF, [97] =	0xB9B000, [127] =	0x4B1502,
   [68] =	0x00454F, [98] =	0x90FF00,
   [69] =	0x2500CC, [99] =	0x835D07,
   [70] =	0x7F7F7F, [100] =	0x392b00,
   [71] =	0x202020, [101] =	0x144C10
}

function apcmini:in_1_pad(args)
   local n, v, c = table.unpack(args)
   n, v = midibyte(n), midibyte(v)
   if type(c) == "number" then
      -- mk2 spec
      c = midibyte(c, 1, 16)
      if self.mode == 1 then
	 return -- changing pad colors not supported in keyboard mode
      elseif self.mode == 2 then
	 c = 10 -- enforce drum channel
      end
      if self.model == 1 then
	 -- mk2, simply output the color spec as is
	 self:outlet(1, "note", {n, v, c})
      else
	 -- mk1, must map the color spec
	 local rgb = vel_rgb_chart[v]
	 local r, g, b = (rgb & 0xff0000) >> 16, (rgb & 0x00ff00) >> 8,
	    rgb & 0x0000ff
	 -- normalize
	 r,g,b = r/255, g/255, b/255
	 -- the mk1 has no blue leds, so we pretend it's green instead
	 g = g+b
	 -- if one component is much larger than the other, pick that one;
	 -- otherwise combine rg to give yellow (or rather orange)
	 local t = 0.5 -- threshold value
	 if r > g + t then
	    r,g = 1,0
	 elseif g > r + t then
	    r,g = 0,1
	 else
	    r,g = r>0 and 1 or 0, g>0 and 1 or 0
	 end
	 if r == g then
	    v = r==0 and 0 or 5
	 else
	    v = r>0 and 3 or 1
	 end
	 if mode ~= 2 and c >= 8 then
	    -- blink
	    v = v+1
	 end
	 self:outlet(1, "note", {n, v, 1})
      end
   else
      -- mk1 spec
      if self.model == 0 then
	 -- mk1, simply output the color spec as is
	 self:outlet(1, "note", {n, v, 1})
      else
	 -- mk2, must map the color spec
	 if v == 1 then
	    v, c = 21, 7 -- green
	 elseif v == 2 then
	    v, c = 21, 16 -- green-blink
	 elseif v == 3 then
	    v, c = 5, 7 -- red
	 elseif v == 4 then
	    v, c = 5, 16 -- red-blink
	 elseif v == 5 then
	    v, c = 9, 7 -- orange
	 elseif v == 6 then
	    v, c = 9, 16 -- orange-blink
	 else
	    v, c = 0, 7 -- black (off)
	 end
	 if self.mode == 2 then
	    c = 10 -- enforce drum channel
	 end
	 self:outlet(1, "note", {n, v, c})
      end
   end
end

function apcmini:in_1_stop(args)
   local n, v, c = table.unpack(args)
   n, v = midibyte(n, 0, 7), midibyte(v, 0, 1)
   self.stop[n+1] = v
   if self.key == 1 then
      self:outlet(1, "note", {self:to_button(64+n), v, 1})
   end
end

function apcmini:in_1_solo(args)
   local n, v, c = table.unpack(args)
   n, v = midibyte(n, 0, 7), midibyte(v, 0, 1)
   self.solo[n+1] = v
   if self.key == 2 then
      self:outlet(1, "note", {self:to_button(64+n), v, 1})
   end
end

function apcmini:in_1_mute(args)
   local n, v, c = table.unpack(args)
   n, v = midibyte(n, 0, 7), midibyte(v, 0, 1)
   self.mute[n+1] = v
   if self.key == 3 then
      self:outlet(1, "note", {self:to_button(64+n), v, 1})
   end
end

function apcmini:in_1_rec(args)
   local n, v, c = table.unpack(args)
   n, v = midibyte(n, 0, 7), midibyte(v, 0, 1)
   self.rec[n+1] = v
   if self.key == 4 then
      self:outlet(1, "note", {self:to_button(64+n), v, 1})
   end
end

function apcmini:in_1_sel(args)
   local n, v, c = table.unpack(args)
   n, v = midibyte(n, 0, 7), midibyte(v, 0, 1)
   self.sel[n+1] = v
   if self.key == 5 then
      self:outlet(1, "note", {self:to_button(64+n), v, 1})
   end
end

function apcmini:in_1_banks(args)
   for i = 1, 4 do
      self.banks[i] = args[i]
   end
   if self.key == 0 then
      self:update_track_buttons()
   end
end

function apcmini:in_1_sysex(args)
   if args[1] == 71 then -- manufacturer id: AKAI
      if args[3] == 79 and -- model id: APC mini mk2
	 args[4] == 98 and -- mode change
	 args[5] == 0 and args[6] == 1 then -- 1 byte follows
	 self.mode = midibyte(args[7], 0, 2)
	 self:update_mode_buttons()
	 self:outlet(1, "mode", {self.mode})
      end
   elseif args[1] == 126 and -- non-realtime
      args[3] == 6 and args[4] == 2 then -- identity reply
      if args[5] == 71 then -- manufacturer id: AKAI
	 if args[6] == 79 then -- model id: APC mini mk2
	    self.model = 1
	    self:outlet(1, "model", {self.model})
	 elseif args[6] == 40 then
	    self.model = 0
	    self:outlet(1, "model", {self.model})
	 end
      end
      -- otherwise it's not an APC mini, do nothing
   end
end

function apcmini:in_1_note(args)
   local n, v, c = table.unpack(args)
   n, v, c = midibyte(n), midibyte(v), midibyte(c, 1)
   if self.mode==1 and c>16 then
      -- note on port #2 in keyboard mode is passed through (mk2 only)
      self:outlet(1, "note", {n, v, c})
   elseif self.mode==2 and c==10 then
      -- note on channel 10 in drum mode is passed through (mk2 only)
      self:outlet(1, "note", {n, v, c})
   elseif c==1 then
      if n < 64 then
	 -- pad pressed
	 self:outlet(1, "pad", {n, v})
      else
	 local n = self:from_button(n)
	 if n == 98 then
	    -- SHIFT button
	    self.shift = v>0 and 1 or 0
	 elseif v > 0 then
	    if n >= 82 then
	       if self.shift == 0 then
		  -- scene button
		  self:outlet(1, "scene", {n-82})
	       elseif n == 89 then
		  self:outlet(1, "stop-all", {})
	       elseif n <= 86 then
		  -- softkeys
		  local function switch_key(k)
		     -- feedback for the softkeys
		     local l = self.key
		     if k ~= l then
			-- turn off the old button
			if l>0 then
			   self:outlet(1, "note", {self:to_button(l+81), 0, 1})
			end
			-- turn on the new one
			if k>0 then
			   self:outlet(1, "note", {self:to_button(k+81), 1, 1})
			end
		     elseif k>0 then
			-- switch back to default mode
			self:outlet(1, "note", {self:to_button(k+81), 0, 1})
			k = 0
		     end
		     return k
		  end
		  self.key = switch_key(n-81)
		  -- update the track buttons
		  self:update_track_buttons()
		  self:outlet(1, "key", {self.key})
	       end
	    elseif n >= 64 then
	       if self.key == 0 then
		  -- default operation mode
		  local function switch_assign(k, n)
		     -- feedback for the fader assign buttons
		     local l = self.assign
		     k = k-n+1
		     if k ~= l then
			-- turn off the old button
			if l > 0 then
			   self:outlet(1, "note", {self:to_button(n+l-1), 0, 1})
			end
			-- turn on the new one
			if k > 0 then
			   self:outlet(1, "note", {self:to_button(n+k-1), 1, 1})
			end
		     else
			-- turn assignment off
			if l > 0 then
			   self:outlet(1, "note", {self:to_button(n+l-1), 0, 1})
			end
			k = 0
		     end
		     return k
		  end
		  if self.model == 1 then
		     -- mk2 swaps the bank and fader assignment controls
		     if n >= 68 then
			local sym = {"bank-up", "bank-down",
				     "bank-left", "bank-right"}
			self:outlet(1, sym[n-68+1], {})
		     else
			self.assign = switch_assign(n, 64)
			self:outlet(1, "assign", {self.assign})
		     end
		  else
		     if n >= 68 then
			self.assign = switch_assign(n, 68)
			self:outlet(1, "assign", {self.assign})
		     else
			local sym = {"bank-up", "bank-down",
				     "bank-left", "bank-right"}
			self:outlet(1, sym[n-64+1], {})
		     end
		  end
	       else
		  -- track controls, depending on the operation mode
		  -- NOTE: the mk1 has rec and mute in reverse order
		  local sym = self.model==1 and
		     {"stop", "solo", "mute", "rec", "sel"} or
		     {"stop", "solo", "rec", "mute", "sel"}
		  self:outlet(1, sym[self.key], {n-64})
	       end
	    end
	 end
      end
   end
end

function apcmini:in_1_ctl(args)
   local v, n, c = table.unpack(args)
   n, v, c = midibyte(n), midibyte(v), midibyte(c, 1, 16)
   if self.assign > 0 and c == 1 and n >= 48 and n <= 56 then
      local sym = {"vol", "pan", "send", "dev"}
      self:outlet(1, sym[self.assign], {n-48, v})
   end
end

function apcmini:in_1(sel, args)
   -- ignore all other messages that we might receive
   pd.post("apcmini: warning: unrecognized " .. sel .. " message")
end
