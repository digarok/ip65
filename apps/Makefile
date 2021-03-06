# Build for Cirrus Logic CS8900A based devices:
# make eth=cl

# Build for Standard Microsystems LAN91C96 based devices:
# make eth=sm

# Build for WIZnet W5100 based devices:
# make eth=wn

ifeq ($(eth),cl)
  C64DRIVERLIB = ../drivers/c64rrnet.lib
  A2DRIVERLIB  = ../drivers/a2uther.lib
  ATRDRIVERLIB = ../drivers/atrdragon.lib
else ifeq ($(eth),sm)
  C64DRIVERLIB = ../drivers/c64eth64.lib
  A2DRIVERLIB  = ../drivers/a2lancegs.lib
else ifeq ($(eth),wn)
  A2DRIVERLIB  = ../drivers/a2uther2.lib
  ATRDRIVERLIB = ../drivers/atrdracarys.lib
else
  C64DRIVERLIB = ../drivers/c64combo.lib
  A2DRIVERLIB  = ../drivers/a2combo.lib
  ATRDRIVERLIB = ../drivers/atrcombo.lib
endif

C64_DRIVERLIB = ../drivers/ip65_c64.lib
A2_DRIVERLIB  = ../drivers/ip65_apple2.lib
ATR_DRIVERLIB = ../drivers/ip65_atari.lib

# See http://vice-emu.sourceforge.net/
C1541 ?= c1541

# See https://applecommander.github.io/
AC ?= ac.jar

# See https://www.horus.com/~hias/atari/
DIR2ATR ?= dir2atr

UDP =\
	date65

TCP =\
	hfs65 \
	telnet65 \
	tweet65 \
	pop65-slow

bin: wget65.bin pop65.bin smtp65.bin email.bin rebuild.bin edit.bin attacher.bin nntp65.bin nntp65.up.bin

wget65.bin: w5100.c w5100_http.c linenoise.c
wget65.bin: IP65LIB = ../ip65/ip65.lib
wget65.bin: A2_DRIVERLIB = ../drivers/ip65_apple2_uther2.lib

pop65.bin: w5100.c
pop65.bin: IP65LIB = ../ip65/ip65.lib
pop65.bin: A2_DRIVERLIB = ../drivers/ip65_apple2_uther2.lib

smtp65.bin: w5100.c
smtp65.bin: IP65LIB = ../ip65/ip65.lib
smtp65.bin: A2_DRIVERLIB = ../drivers/ip65_apple2_uther2.lib

nntp65.bin: w5100.c
nntp65.bin: IP65LIB = ../ip65/ip65.lib
nntp65.bin: A2_DRIVERLIB = ../drivers/ip65_apple2_uther2.lib

nntp65.up.bin: w5100.c
nntp65.up.bin: IP65LIB = ../ip65/ip65.lib
nntp65.up.bin: A2_DRIVERLIB = ../drivers/ip65_apple2_uther2.lib

date65.bin hfs65.bin tweet65.bin: CL65FLAGS = --start-addr 0x0C00 apple2enh-iobuf-0800.o

telnet65.com: ATARI_CFG = atrtelnet.cfg

tweet65.prg tweet65.bin tweet65.com: ifttt.c

all:    $(UDP) $(TCP)
.PHONY: $(UDP) $(TCP)

$(addsuffix .prg,$(UDP)): IP65LIB = ../ip65/ip65.lib
$(addsuffix .prg,$(TCP)): IP65LIB = ../ip65/ip65_tcp.lib

$(addsuffix .bin,$(UDP)): IP65LIB = ../ip65/ip65.lib
$(addsuffix .bin,$(TCP)): IP65LIB = ../ip65/ip65_tcp.lib

$(addsuffix .com,$(UDP)): IP65LIB = ../ip65/ip65.lib
$(addsuffix .com,$(TCP)): IP65LIB = ../ip65/ip65_tcp.lib

$(foreach pgm,$(UDP) $(TCP),$(eval $(pgm): $(pgm).prg $(pgm).bin $(pgm).com))

prg: $(addsuffix .prg,$(UDP) $(TCP))

bin: $(addsuffix .bin,$(UDP) $(TCP))

com: $(addsuffix .com,$(UDP) $(TCP))

d64: ip65.d64

dsk: ip65.dsk

atr: ip65.atr

ip65:
	make -C ../ip65

drivers:
	make -C ../drivers

BUILDS = ip65 drivers

CC65 := $(shell cl65 --print-target-path)

ATARI_CFG = atari.cfg

%.s.o: %.s
	ca65 -o $@ $<

%.o: %.c

%.prg: %.s.o $(BUILDS)
	ld65 -o $*.prg -C c64.cfg -m $*.c64.map -vm $< $(IP65LIB) $(C64DRIVERLIB) c64.lib

%.bin: %.s.o $(BUILDS)
	ld65 -o $*.bin -C apple2.cfg -m $*.a2.map -vm $< $(IP65LIB) $(A2DRIVERLIB) apple2.lib

%.com: %.s.o $(BUILDS)
	ld65 -o $*.com -C $(ATARI_CFG) -m $*.atr.map -vm $< $(IP65LIB) $(ATRDRIVERLIB) atari.lib

%.prg: %.c $(BUILDS)
	cl65 -o $*.prg -Or -t c64 $(CL65FLAGS) -m $*.c64.map -vm $(filter-out $(BUILDS),$^) $(IP65LIB) $(C64_DRIVERLIB)

%.bin: %.c $(BUILDS)
	cl65 -o $*.bin -Or -t apple2enh $(CL65FLAGS) -m $*.a2.map -vm $(filter-out $(BUILDS),$^) $(IP65LIB) $(A2_DRIVERLIB)

%.com: %.c $(BUILDS)
	cl65 -o $*.com -Or -t atari $(CL65FLAGS) -m $*.atr.map -vm $(filter-out $(BUILDS),$^) $(IP65LIB) $(ATR_DRIVERLIB)

ip65.d64: prg
	$(C1541) -format ip65,00 d64 $@
	$(C1541) -attach $@ -write date65.prg   date65,p
	$(C1541) -attach $@ -write hfs65.prg    hfs65,p
	$(C1541) -attach $@ -write telnet65.prg telnet65,p
	$(C1541) -attach $@ -write tweet65.prg  tweet65,p

ip65.dsk: bin
	cp ../build/800k.po $@
	java -jar $(AC) -as $@ attacher            < attacher.bin
	java -jar $(AC) -p  $@ attacher.system sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ date65              < date65.bin
	java -jar $(AC) -p  $@ date65.system   sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ edit                < edit.bin
	java -jar $(AC) -p  $@ edithelp1.txt   txt < edithelp1.txt
	java -jar $(AC) -p  $@ edithelp2.txt   txt < edithelp2.txt
	java -jar $(AC) -p  $@ edit.system     sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ email               < email.bin
	java -jar $(AC) -p  $@ emailhelp1.txt  txt < emailhelp1.txt
	java -jar $(AC) -p  $@ email.cfg       txt < email.cfg
	java -jar $(AC) -p  $@ email.system    sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ hfs65               < hfs65.bin
	java -jar $(AC) -p  $@ hfs65.system    sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -p  $@ news.cfg        txt < news.cfg
	java -jar $(AC) -as $@ nntp65              < nntp65.bin
	java -jar $(AC) -p  $@ nntp65.system   sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ nntp65up            < nntp65.up.bin
	java -jar $(AC) -p  $@ nntp65up.system sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ pop65               < pop65.bin
	java -jar $(AC) -p  $@ pop65.system    sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ rebuild             < rebuild.bin
	java -jar $(AC) -p  $@ rebuild.system  sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ smtp65              < smtp65.bin
	java -jar $(AC) -p  $@ smtp65.system   sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -as $@ telnet65            < telnet65.bin
	java -jar $(AC) -as $@ tweet65             < tweet65.bin
	java -jar $(AC) -p  $@ tweet65.system  sys < $(CC65)/apple2enh/util/loader.system
	java -jar $(AC) -p  $@ tzone.txt       txt < tzone.txt
	java -jar $(AC) -as $@ wget65              < wget65.bin
	java -jar $(AC) -p  $@ wget65.system   sys < $(CC65)/apple2enh/util/loader.system

ip65.atr: com
	mkdir atr
	cp ../build/dos.sys atr/dos.sys
	cp ../build/dup.sys atr/dup.sys
	cp date65.com       atr/date65.com
	cp telnet65.com     atr/telnet65.com
	cp tweet65.com      atr/tweet65.com
	$(DIR2ATR) -b Dos25 1040 $@ atr
	rm -r atr

clean:
	make -C ../ip65 clean
	make -C ../drivers clean
	-rm -f *.o *.prg *.bin *.com *.map
	-rm -f ip65.d64 ip65.dsk ip65.atr
