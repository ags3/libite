# libite -- Light-weight utility functions and C-library extensions
# 
# Copyright (c) 2008-2015  Joachim Nilsson <troglobit@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
.PHONY: all install clean

# Figure out root of library, unless used as submodule
ROOTDIR    ?= $(shell pwd)

#VERSION    = $(shell git tag -l | tail -1)
VERSION    ?= 1.0.0
NAME        = libite
PKG         = $(NAME)-$(VERSION)
ARCHIVE     = $(PKG).tar.xz

CC         ?= $(CROSS)gcc
AR         ?= $(CROSS)ar
STRIP      ?= $(CROSS)strip
INSTALL    := install --backup=off
STRIPINST  := $(INSTALL) -s --strip-program=$(CROSS)strip -m 0755

ifneq ($(STATIC), 1)
CFLAGS     += -fPIC
endif
CFLAGS     += -Os
CPPFLAGS   += -W -Wall -Werror
ARFLAGS     = crus
MAKEFLAGS   = --no-print-directory --silent

DISTFILES   = README LICENSE
HEADERS     = lite.h
OBJS       := copyfile.o dir.o fexist.o fisdir.o fmode.o rsync.o
OBJS       += strlcpy.o strlcat.o strtonum.o
DEPS       := $(OBJS:.o=.d)
JUNK        = *~ *.bak *.map .*.d *.d DEADJOE semantic.cache *.gdb *.elf core core.*

VER         = 1
LIBNAME     = $(NAME)
SOLIB       = $(LIBNAME).so.$(VER)
SYMLIB      = $(LIBNAME).so
STATICLIB   = $(LIBNAME).a
ifdef STATIC
TARGET      = $(STATICLIB)
else
TARGET      = $(SOLIB)
endif

# Default install paths
prefix     ?= /usr/local
libdir     ?= $(prefix)/lib
datadir    ?= $(prefix)/share/doc/$(LIBNAME)
incdir     ?= $(prefix)/include

# This magic trick looks like a comment, but works on BSD PMake
#include <rules.mk>
include rules.mk

# Build rules
all: $(TARGET)

$(OBJS): Makefile

$(SOLIB): Makefile $(OBJS)
	@printf "  LINK    %s\n" $@
	@$(CC) $(LDFLAGS) -shared -Wl,-soname,$@ -o $@ $(OBJS) -lrt -lcrypt

$(STATICLIB): Makefile $(OBJS)
	@printf "  ARCHIVE $@\n"
	@$(AR) $(ARFLAGS) $@ $(OBJS)

install-exec: all
ifndef STATIC
	@printf "  INSTALL $(DESTDIR)$(libdir)/$(SOLIB)\n"
	@install -d $(DESTDIR)$(libdir)
	@$(STRIPINST) $(SOLIB) $(DESTDIR)$(libdir)/$(SOLIB)
	@ln -sf $(SOLIB) $(DESTDIR)$(libdir)/$(SYMLIB)
endif

install-dev:
	@install -d $(DESTDIR)$(incdir)
	@for file in $(HEADERS); do	                                \
		printf "  INSTALL $(DESTDIR)$(incdir)/$$file\n";	\
		$(INSTALL) -m 0644 $$file $(DESTDIR)$(incdir)/$$file;	\
	done
ifdef STATIC
	@printf "  INSTALL $(DESTDIR)$(libdir)/$(STATICLIB)\n"
	@install -d $(DESTDIR)$(libdir)
	@$(INSTALL) $(STATICLIB) $(DESTDIR)$(libdir)/$(STATICLIB)
endif

install: install-exec install-dev

uninstall:
	-@$(RM) $(DESTDIR)$(libdir)/$(SOLIB)
	-@$(RM) $(DESTDIR)$(libdir)/$(SYMLIB)
	-@$(RM) $(DESTDIR)$(libdir)/$(STATICLIB)
	-@for file in $(HEADERS); do			\
		$(RM) $(DESTDIR)$(incdir)/$$file;	\
	done

strip: $(TARGET)
	@printf "  STRIP   %s\n" $(TARGET)
	@$(STRIP) --strip-unneeded $(TARGET)
	@size $(TARGET)

# Runs Clang scan-build on the whole tree
check: clean
	@scan-build $(MAKE) all

clean:
	-@$(RM) $(OBJS) $(DEPS) $(TARGET) $(SOLIB) $(STATICLIB)

distclean:
	-@$(RM) $(JUNK) unittest *.o *.a *.so* *.unittest

dist:
	@echo "Building .xz tarball of $(PKG) in parent dir..."
	git archive --format=tar --prefix=$(PKG)/ v$(VERSION) | xz >../$(ARCHIVE)
	@(cd ..; md5sum $(ARCHIVE) | tee $(ARCHIVE).md5)

# Include automatically generated rules
-include $(DEPS)
