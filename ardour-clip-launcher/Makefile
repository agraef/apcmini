
# mdns Avahi/Bonjour module for Lua
# Copyright (c) 2022 by Albert Gräf <aggraef@gmail.com>

# Requisites: To compile this module, you need to have Lua installed
# (https://www.lua.org/, 5.3 or later should do, 5.4 has been tested). You'll
# also need Avahi on Linux (should be readily available in your distro's
# repositories), or Bonjour on Mac (should be readily available if you have
# Apple's Xcode development kit installed) and Windows (Apple's Bonjour SDK
# for Windows is available at https://developer.apple.com/bonjour/).

# set this to 'yes' to enable a static build (useful if the target system
# doesn't have the dynamic Lua lib installed)
#static = yes

os = $(shell uname)

# static Lua lib name
lualibdir = $(shell pkg-config --variable INSTALL_LIB lua)
lualibname = $(shell pkg-config --libs-only-l lua|sed 's/-l\([^ ]*\).*/\1/')
lualib = $(lualibdir)/lib$(lualibname).a

ifeq ($(static),yes)
LUA_FLAGS = $(shell pkg-config --cflags lua) $(lualib)
else
LUA_FLAGS = $(shell pkg-config --cflags --libs lua)
endif

all: mdns.so

ifeq ($(os),Linux)
# Avahi (Linux)
mdns.so: avahi.c
	$(CC) -shared -fPIC -o $@ $< $(shell pkg-config --cflags --libs avahi-client) $(LUA_FLAGS)
else
# Bonjour (Mac, Windows)
mdns.so: bonjour.c
	$(CC) -shared -fPIC -o $@ $<  $(LUA_FLAGS)
endif

clean:
	rm -f mdns.so

# The following install target will really do the right thing only on Linux
# and other Unix systems like *BSD. On most systems, just run `make` and add
# the mdnsbrowser directory to the Pd search path (see [1] for details).
# [1] https://puredata.info/docs/faq/how-do-i-install-externals-and-help-files

prefix = /usr/local
installdir = $(prefix)/lib/pd-externals/mdnsbrowser
installfiles = COPYING README.md Makefile mdnsbrowser.pd_lua mdnsbrowser-help.pd oscbrowser.pd osclisten.pd avahi.c bonjour.c mdns.so

install:
	mkdir -p $(DESTDIR)$(installdir)
	cp $(installfiles) $(DESTDIR)$(installdir)

uninstall:
	rm -rf $(DESTDIR)$(installdir)
