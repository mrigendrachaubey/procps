# Makefile for procps.  Chuck Blake.
# Portions of this are highly dependent upon features specific to GNU make

export PREFIX     =  #proc# prefix for program names

export DESTDIR    =  /
export MANDIR     =  /usr/man
export MAN1DIR    =  $(DESTDIR)$(MANDIR)/man1
export MAN5DIR    =  $(DESTDIR)$(MANDIR)/man5
export MAN8DIR    =  $(DESTDIR)$(MANDIR)/man8
export BINDIR     =  $(DESTDIR)/bin
export SBINDIR    =  $(DESTDIR)/sbin
export XBINDIR    =  $(DESTDIR)/usr/X11R6/bin
export USRBINDIR  =  $(DESTDIR)/usr/bin
export PROCDIR    =  $(DESTDIR)/usr/bin# /usr/proc/bin for Solaris devotees
export APPLNK     =  $(DESTDIR)/etc/X11/applnk/Utilities
export OWNERGROUP =  --owner 0 --group 0
export INSTALLBIN =  install --mode a=rx --strip
export INSTALLSCT =  install --mode a=rx
export INSTALLMAN =  install --mode a=r

BPROG      =  kill #					-> BINDIR
UPROG      =  oldps uptime tload free w top vmstat watch skill snice # -> USRBINDIR
PPROG      =  pgrep pkill# -> PROCDIR
SPROG      =  sysctl
MAN1       =  oldps.1 uptime.1 tload.1 free.1 w.1 top.1 watch.1 skill.1 kill.1 snice.1 pgrep.1 pkill.1
MAN5       =  sysctl.conf.5
MAN8       =  vmstat.8 sysctl.8
DESKTOP    =  top.desktop
XSCPT      =  XConsole # -> XBINDIR

SUBDIRS    =  ps # sub-packages to build/install

# easy to command-line override
export INCDIRS    =  -I/usr/include/ncurses -I/usr/X11R6/include

export CC         =  gcc #-ggdb # this gets compiling and linking :-)
export OPT        =  -O2
export CFLAGS     =  -D_GNU_SOURCE $(OPT) -I$(shell pwd) $(INCDIRS) -W -Wall -Wstrict-prototypes -Wshadow -Wcast-align -Wmissing-prototypes

export SHARED     =  1# build/install both a static and ELF shared library
export SHLIBDIR   =  $(DESTDIR)/lib# where to install the shared library

export LDFLAGS    =  -Wl,-warn-common #-s	recommended for ELF systems
#LDFLAGS    =  -qmagic -s#		recommended for a.out systems
#LDFLAGS    =  -Xlinker -qmagic -s#	older a.out systems may need this
#LDFLAGS    =  -N -s#			still older a.out systems use this

#BFD_CAPABLE = -DBFD_CAPABLE
#AOUT_CAPABLE = #-DAOUT_CAPABLE 
#ELF_CAPABLE = #-DELF_CAPABLE

#LIBBFD = -lbfd -liberty
LIBCURSES  =  -lncurses# watch is the only thing that needs this
#LIBCURSES  =  -lcurses -ltermcap# BSD Curses requires termcap
LIBTERMCAP =  -lncurses# provides perfectly good termcap support
#LIBTERMCAP =  -ltermcap
EXTRALIBS  =  # -lshadow

W_SHOWFROM =  -DW_SHOWFROM# show remote host users are logged in from.

#----------------------------------------------------#
# End of user-configurable portion of the Makefile.  #
# You should not need to modify anything below this. #
#----------------------------------------------------#
BUILD = $(BPROG) $(UPROG) $(PPROG) $(SPROG) $(SUBDIRS) $(DESKTOP)

# BUILD LIBRARIES + PROGRAMS
all: $(BUILD)

# INSTALL PROGRAMS + DOCS
install: $(patsubst %,install_%,$(BUILD) $(XSCPT) $(MAN1) $(MAN5) $(MAN8))
ifeq ($(SHARED),1)
	install $(OWNERGROUP) --mode a=rx $(LIB_TGT) $(SHLIBDIR)
endif

# INSTALL LIBRARIES + HEADERS (OPTIONAL)
libinstall:
	$(MAKE) -C proc install $(LIBPROCPASS)

clean:
	$(RM) -f $(OBJ) $(BPROG) $(UPROG) $(PPROG) $(SPROG)
	for i in proc $(SUBDIRS); do $(MAKE) -C $$i clean; done

distclean: clean
	for i in proc $(SUBDIRS); do $(MAKE) -C $$i clean; done
	$(RM) -f $(OBJ) $(BPROG) $(UPROG) $(SPROG) \
	      proc/.depend


#-----------------------------------------------------#
# End of user-callable make targets.                  #
# You should not need to read anything below this.    #
#-----------------------------------------------------#

.PHONY:	all install libinstall clean distclean
.PHONY: $(patsubst %,install_%, $(BPROG) $(UPROG) $(SPROG))
.PHONY: proc ps
.PHONY: $(patsubst %,build_%, proc ps)
.PHONY: $(patsubst %,install_%, proc ps)

VERSION      = $(shell awk '/^%define major_version/ { print $$3 }' < procps.spec)
SUBVERSION   = $(shell awk '/^%define minor_version/ { print $$3 }' < procps.spec)
MINORVERSION = $(shell awk '/^%define revision/ { print $$3 }' < procps.spec)

# Note: LIBVERSION may be less than $(VERSION).$(SUBVERSION).$(MINORVERSION)
# LIBVERSION is only set to current $(VERSION).$(SUBVERSION).$(MINORVERSION)
# when an incompatible change is made in libproc.
LIBVERSION   =  2.0.7
ifdef MINORVERSION
LIBPROCPASS  =  SHARED=$(SHARED) SHLIBDIR=$(SHLIBDIR) VERSION=$(VERSION) SUBVERSION=$(SUBVERSION) MINORVERSION=$(MINORVERSION) LIBVERSION=$(LIBVERSION)
else
LIBPROCPASS  =  SHARED=$(SHARED) SHLIBDIR=$(SHLIBDIR) VERSION=$(VERSION) SUBVERSION=$(SUBVERSION) LIBVERSION=$(LIBVERSION)
endif

# libproc setup

ifeq ($(SHARED),1)
    LIB_TGT = proc/libproc.so.$(LIBVERSION)
else
    LIB_TGT = proc/libproc.a
endif

$(LIB_TGT): $(wildcard proc/*.[ch])
	$(MAKE) -C proc `basename $(LIB_TGT)` $(LIBPROCPASS)

# component package setup -- the pattern should be obvious: A build rule and
# unified executable+documentation install rule. (An extra makefile rule is
# needed for those packages which use Imake.)

ps:              build_ps
build_ps:				; $(MAKE) -C ps
install_ps:      ps		; $(MAKE) -C ps install

# executable dependencies
oldps kill skill snice top w uptime tload free vmstat utmp : $(LIB_TGT)

# static pattern build/link rules:

%.o : %.c
	$(strip $(CC) $(CFLAGS) -c $^)

oldps w uptime tload free vmstat utmp pgrep: % : %.o
	$(strip $(CC) $(LDFLAGS) -o $@ $< $(LIB_TGT) $(EXTRALIBS))


# special instances of link rules (need extra libraries/objects)

top:   % : %.o
	$(strip $(CC)  $(LDFLAGS) -o $@ $^ $(LIB_TGT) $(LIBTERMCAP) $(EXTRALIBS))

watch:	% : %.o
	$(strip $(CC) $(SLDFLAGS) -o $@ $< $(LIBCURSES) $(EXTRALIBS))


# special instances of compile rules (need extra defines)
w.o:	w.c
	$(strip $(CC) $(CFLAGS) $(W_SHOWFROM) -c $<)

top.o:	top.c
	$(strip $(CC) $(CFLAGS) -fwritable-strings -c $<)

skill.o:	skill.c
	$(strip $(CC) $(CFLAGS) -DSYSV -c $<)

snice:	skill
	ln -f skill snice

kill:	skill
	ln -f skill kill

pkill:	pgrep
	ln -f pgrep pkill

# static pattern installation rules

$(patsubst %,install_%,$(BPROG)): install_%: %
	$(INSTALLBIN) $< $(BINDIR)/$(PREFIX)$<
$(patsubst %,install_%,$(SPROG)): install_%: %
	$(INSTALLBIN) $< $(SBINDIR)/$(PREFIX)$<
$(patsubst %,install_%,$(UPROG)): install_%: %
	$(INSTALLBIN) $< $(USRBINDIR)/$(PREFIX)$<
$(patsubst %,install_%,$(PPROG)): install_%: %
	$(INSTALLBIN) $< $(PROCDIR)/$(PREFIX)$<
$(patsubst %,install_%,$(XSCPT)): install_%: %
	$(INSTALLSCT) $< $(XBINDIR)/$(PREFIX)$<
$(patsubst %,install_%,$(MAN1)) : install_%: %
	$(INSTALLMAN) $< $(MAN1DIR)/$(PREFIX)$<
$(patsubst %,install_%,$(MAN5)) : install_%: %
	$(INSTALLMAN) $< $(MAN5DIR)/$(PREFIX)$<
$(patsubst %,install_%,$(MAN8)) : install_%: %
	$(INSTALLMAN) $< $(MAN8DIR)/$(PREFIX)$<
$(patsubst %,install_%,$(DESKTOP)) : install_%: %
	$(INSTALLSCT $< $(APPLNK)/$(PREFIX)$<

# special case install rules
install_snice: snice install_skill
	cd $(USRBINDIR) && ln -f skill snice
install_kill: snice install_skill
	cd $(USRBINDIR) && ln -f skill kill
install_pkill: pgrep install_pgrep
	cd $(USRBINDIR) && ln -f pgrep pkill

# Find all the source and object files in this directory

SRC      =  $(sort $(wildcard *.c))
OBJ      =  $(SRC:.c=.o)

CVSTAG = ps_$(VERSION)_$(SUBVERSION)_$(MINORVERSION)
FILEVERSION = $(VERSION).$(SUBVERSION).$(MINORVERSION)
dist: archive
archive:
	@cvs -Q tag -F $(CVSTAG)
	@rm -rf /tmp/procps
	@cd /tmp; cvs -Q -d $(CVSROOT) export -r$(CVSTAG) procps || echo GRRRrrrrr -- ignore [export aborted]
	@mv /tmp/procps /tmp/procps-$(FILEVERSION)
	@cd /tmp; tar czSpf procps-$(FILEVERSION).tar.gz procps-$(FILEVERSION)
	@cd /tmp; cp procps-$(FILEVERSION)/procps.lsm procps-$(FILEVERSION).lsm
	@rm -rf /tmp/procps-$(FILEVERSION)
	@echo "The final archive is /tmp/procps-$(FILEVERSION).tar.gz"
