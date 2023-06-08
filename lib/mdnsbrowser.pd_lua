
-- mdns service publishing and discovery (a.k.a. Avahi/Bonjour/Zeroconf)

-- Author: Albert Gräf <aggraef@gmail.com>, Dept. of Music-Informatics,
-- Johannes Gutenberg University (JGU) of Mainz, Germany, please check
-- https://agraef.github.io/ for a list of my software.

-- Copyright (c) 2022 by Albert Gräf <aggraef@gmail.com>

-- Distributed under the GPLv3+, please check the accompanying COPYING file
-- for details.

local mdnsbrowser = pd.Class:new():register("mdnsbrowser")

-- Usage: mdnsbrowser [name [type] [port]]

-- name, type, port denotes a service name, service type and port number to be
-- published. These are all optional and default to "OSC", "_osc._udp" and
-- 8000, respectively. The defaults are choses so that they will work with the
-- default settings of the TouchOSC app on Android and iOS.

-- The left inlet/outlet pair is used to browse for services: 1 on the left
-- inlet activates the browser, 0 deactivates it, and a bang updates the
-- service list manually if new data is available. The current list of known
-- service names is output on the left outlet (or a bang if the list is
-- empty). The left inlet also takes a service name (a symbol) as input and
-- outputs a connect message with the IP and port number of the service if the
-- service name can be resolved.

-- The right inlet/outlet pair is used to publish a service in the local
-- domain. 1 on the left inlet activates publishing a service with the given
-- name, type, and port, 0 deactivates the service. The right outlet will
-- output 1 as soon as the service has been published successfully, or 0 in
-- case of error. The service will be visible to other applications on the
-- same (local) network as long as publishing is activated. The published name
-- will have the hostname of the local machine tacked on to it for
-- identification purposes, if that information is available (this requires
-- the `hostname` command to be on `PATH`, which should generally work at
-- least on Linux and MacOS systems).

-- Note that all of this requires that an Avahi or Bonjour server is running
-- somewhere on the local network. On Mac computers this server seems to be
-- running by default, but on Linux systems you will have to activate the
-- Avahi server via systemd.

-- This requires the accompanying mdns Lua module which needs to be compiled
-- first, please check the Makefile for details.

mdns = require("mdns")

function mdnsbrowser:initialize(sel, atoms)
   self.inlets = 2
   self.outlets = 2
   self.name = "OSC"
   self.port = 8000
   self.type = "_osc._udp"
   -- delay times for the clocks (currently these are hardwired); maybe we
   -- should add some creation arguments to set them in the future, but the
   -- defaults should be reasonable, and you can change them below if needed
   self.oneshot_delay = 500
   self.period_delay = 500
   -- 
   if type(atoms[1]) == "string" then
      self.name = atoms[1]
   elseif type(atoms[1]) == "number" then
      self.port = atoms[1]
   end
   if type(atoms[2]) == "number" then
      self.port = atoms[2]
   elseif type(atoms[2]) == "string" then
      self.type = atoms[2]
   end
   if type(atoms[3]) == "number" then
      self.port = atoms[3]
   end
   -- try to get the hostname so that we can add it to the published service
   -- name; fixme: we rely on the shell here and that io.popen is available,
   -- is there a more portable way to do this?
   local fp = io.popen("hostname")
   local s = fp:read("*l")
   -- remove any domain name which TouchOSC seems to choke an (for
   -- some reason, hostname on Mac may want to add these)
   self.hostname = type(s) == "string" and string.gsub(s, "[.].*", "") or nil
   -- published service (not initialized until needed)
   self.service = nil
   -- initialize the mdns browser (this is done asynchronously, so we need to
   -- do this here so that the data is available when we need it)
   self.browser = mdns.browse(self.type)
   -- published service info as returned by Zeroconf
   self.info = nil
   -- service data as returned by zeroconf, as a table mapping service names
   -- to addr, port pairs
   self.data = nil
   -- one-shot clock to handle asynchronous results of service publisher
   self.oneshot = pd.Clock:new():register(self, "publish")
   -- periodic clock to update the browser results (can also be done manually
   -- at any time by sending a bang to the first inlet)
   self.period = pd.Clock:new():register(self, "browse")
   return true
end

function mdnsbrowser:finalize()
   -- get rid of any remaining service and browser on termination
   if self.browser then
      mdns.close(self.browser)
   end
   if self.service then
      mdns.unpublish(self.service)
   end
   -- get rid of the timers
   if self.oneshot then
      self.oneshot:destruct()
   end
   if self.period then
      self.period:destruct()
   end
end

-- publish ourselves as a service (1 on second inlet activates, 0 decactives);
-- 2nd outlet gets a 1 if service was published successfully, 0 if error
function mdnsbrowser:in_2_float(f)
   -- turn off any existing service
   if self.service then
      mdns.unpublish(self.service)
      self.service = nil
      self.oneshot:unset()
   end
   if f ~= 0 then
      local name = self.hostname and string.format("%s (%s)", self.name, self.hostname) or self.name
      self.service = mdns.publish(name, self.type, self.port)
      -- this gets run asynchronously, so we set up a timer to check the
      -- result later, in order not to block the control loop
      self.oneshot:delay(self.oneshot_delay)
   else
      self:outlet(2, "float", {0})
   end
end

function mdnsbrowser:publish()
   local f = 1
   self.info = mdns.check(self.service)
   -- an integer return code indicates an error publishing the service
   if type(self.info) == "number" then
      self.info = nil
      f = 0
   end
   self:outlet(2, "float", {f})
end

-- service discovery (mdns browser), triggered by a bang on the first inlet;
-- outputs a list of currently known service names excluding ourselves (or
-- 'bang' if the list is empty) whenever there are any changes
function mdnsbrowser:in_1_bang()
   if mdns.avail(self.browser) then
      self.data = mdns.get(self.browser)
      -- an integer return code indicates an error getting the service list
      if type(self.data) == "number" then
	 self.data = nil
      else
	 -- collect the list of services (except ourselves) to output and
	 -- construct a table mapping service names to IP addresses for later
	 -- inspection
	 local out = {}
	 local map = {}
	 local me = self.info and self.info.name or nil
	 for k,v in ipairs(self.data) do
	    -- ignore any double entries and entries for ourselves
	    if (not me or v.name ~= me) and not map[v.name] then
	       table.insert(out, v.name)
	       map[v.name] = {v.addr, v.port}
	       --pd.post(string.format("%s => %s %d", v.name, v.addr, v.port))
	    end
	 end
	 self.data = map
	 self:outlet(1, "list", out)
      end
   end
end

-- activate/deactivate automatic mdns browser updates
function mdnsbrowser:in_1_float(f)
   self.period:unset()
   if f ~= 0 then
      self.period:delay(self.period_delay)
   end
end

-- timer callback for the mdns browser; this essentially works like a built-in
-- metronome triggering a bang message on the first inlet
function mdnsbrowser:browse()
   self.period:delay(self.period_delay)
   self:in_1_bang()
end

-- resolves address and port of the service name given on the first inlet; if
-- the service is known, a corresponding 'connect' message is output on the
-- first outlet
function mdnsbrowser:in_1(sel, atoms)
   local s = sel
   if s == "symbol" or s == "list" then
      s = table.concat(atoms, " ")
   elseif #atoms > 0 then
      -- anything else presumably is a meta message
      s = s .. " " .. table.concat(atoms, " ")
   end
   if self.data and self.data[s] then
      self:outlet(1, "connect", self.data[s])
   end
end
