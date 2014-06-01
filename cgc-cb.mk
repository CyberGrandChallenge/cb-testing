ifndef SRCS
SRCS = $(wildcard src/*.c lib/*.c)
endif

ifndef POLLS_RELEASE
POLLS_RELEASE = $(wildcard poller/for-release/*.xml)
endif

ifndef POLLS_TESTING
POLLS_TESTING = $(wildcard poller/for-testing/*.xml)
endif

ifndef POVS
POVS = $(wildcard pov/*.xml)
endif

ifndef CC
CC = gcc
endif

ifndef LD
LD = ld
endif

ifdef NO_STRIP
LDFLAGS    = -nostdlib -lcgc -L/usr/lib -static
else
LDFLAGS    = -nostdlib -lcgc -L/usr/lib -static -s
endif

SHELL      := $(SHELL) -e
BIN_DIR    = bin
BUILD_DIR  = build
CGC_CFLAGS = -nostdlib -fno-builtin -nostdinc -nostartfiles -nodefaultlibs -Iinclude -Ilib -I/usr/include $(CFLAGS)
EXE        = $(AUTHOR_ID)_$(SERVICE_ID)
PATH       := /usr/i386-linux-cgc/bin:$(PATH)

OBJS       = $(SRCS:.c=.o)
POLL_RELEASE_LOGS  = $(POLLS_RELEASE:.xml=.log)
POLL_TESTING_LOGS  = $(POLLS_TESTING:.xml=.log)
POV_LOGS   = $(POVS:.xml=.log)

BUILD_POLL_TESTING_LOG  = $(addprefix $(BUILD_DIR)/, $(POLL_RELEASE_LOGS))
BUILD_POLL_RELEASE_LOG  = $(addprefix $(BUILD_DIR)/, $(POLL_TESTING_LOGS))
BUILD_POV_LOG   = $(addprefix $(BUILD_DIR)/, $(POV_LOGS))

PATCHED_CFLAGS  = -DPATCHED $(CGC_CFLAGS) 
PATCHED_DIR     = patched
PATCHED_EXE     = $(EXE)_patched
PATCHED_PATH    = $(BIN_DIR)/$(PATCHED_EXE)
PATCHED_OBJS    = $(addprefix $(BUILD_DIR)/$(PATCHED_DIR)/, $(OBJS))

RELEASE_CFLAGS  = -DNPATCHED $(CGC_CFLAGS)
RELEASE_DIR     = release
RELEASE_EXE	= $(EXE)
RELEASE_PATH    = $(BIN_DIR)/$(RELEASE_EXE)
RELEASE_OBJS    = $(addprefix $(BUILD_DIR)/$(RELEASE_DIR)/, $(OBJS))

PCAP_DIR        = pcap

PACKAGE_DIR     = $(EXE)
PACKAGE_FILE    = $(EXE).tgz
PACKAGE_ENC	= $(PACKAGE_FILE).aes

all: build test package

prep:
	@mkdir -p $(BUILD_DIR)/$(PATCHED_DIR)/lib $(BUILD_DIR)/$(RELEASE_DIR)/lib $(BUILD_DIR)/$(RELEASE_DIR)/src $(BUILD_DIR)/$(PATCHED_DIR)/src $(BUILD_DIR)/pov $(BUILD_DIR)/poller/for-testing $(BUILD_DIR)/poller/for-release bin $(PCAP_DIR)

# Release rules
release: prep $(RELEASE_PATH)
$(RELEASE_PATH): $(RELEASE_OBJS)
	$(LD) $(LDFLAGS) -o $(RELEASE_PATH) -I$(BUILD_DIR)/$(RELEASE_DIR)/lib $^
$(BUILD_DIR)/$(RELEASE_DIR)/%.o: %.c
	$(CC) -c $(RELEASE_CFLAGS) -o $@ $<

# Patched rules
patched: prep $(PATCHED_PATH)
$(PATCHED_PATH): $(PATCHED_OBJS)
	$(LD) $(LDFLAGS) -o $(PATCHED_PATH) $^
$(BUILD_DIR)/$(PATCHED_DIR)/%.o: %.c
	$(CC) -c $(PATCHED_CFLAGS) -o $@ $<

check:
# Polls that the CB author intends to release the resulting network traffic during CQE
	@if [ -d poller/for-release ]; then cb-test --port $(TCP_PORT) --cb $(RELEASE_EXE) --xml_dir poller/for-release/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(RELEASE_EXE).for-release.txt --pcap pcap/$(RELEASE_EXE)_poll.pcap ; fi
	@if [ -d poller/for-release ]; then cb-test --port $(TCP_PORT) --cb $(PATCHED_EXE) --xml_dir poller/for-release/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(PATCHED_EXE).for-release.txt ; fi

# Polls that the CB author intends to NOT release the resulting network traffic during CQE
	@if [ -d poller/for-testing ]; then cb-test --port $(TCP_PORT) --cb $(RELEASE_EXE) --xml_dir poller/for-testing/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(RELEASE_EXE).for-testing.txt ; fi
	@if [ -d poller/for-testing ]; then cb-test --port $(TCP_PORT) --cb $(PATCHED_EXE) --xml_dir poller/for-testing/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(PATCHED_EXE).for-testing.txt ; fi

# POVs that should generate an identified crash for CQE when sent to the release CB but not the patched CB
	cb-test --port $(TCP_PORT) --cb $(RELEASE_EXE) --xml_dir pov/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(RELEASE_EXE).pov.txt --should_core
	cb-test --port $(TCP_PORT) --cb $(PATCHED_EXE) --xml_dir pov/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(PATCHED_EXE).pov.txt
	
clean_test:
	@-rm -f $(BUILD_POV_LOG) $(BUILD_POLL_LOG)

clean: clean_test
	-rm -rf $(BUILD_DIR) $(BIN_DIR) $(PACKAGE_DIR) $(PCAP_DIR)
	-rm -f test.log $(PACKAGE_FILE) $(PACKAGE_ENC) 

build: prep release patched

test: build check

build_package: build test
# required files
	@install -d $(PACKAGE_DIR)/bin 
	@install -d $(PACKAGE_DIR)/pcap 
	@install -d $(PACKAGE_DIR)/poller/for-release
	@install -d $(PACKAGE_DIR)/poller/for-testing
	@install -d $(PACKAGE_DIR)/pov 
	@install -d $(PACKAGE_DIR)/src
	@install bin/*_* $(PACKAGE_DIR)/bin
	@install pov/*.xml $(PACKAGE_DIR)/pov
	@install src/*.* $(PACKAGE_DIR)/src
	@install Makefile README.md $(PACKAGE_DIR)/
# optional files
	@if [ -d pcap ]; then install pcap/*.pcap $(PACKAGE_DIR)/pcap ; fi
	@if [ -d poller/for-release ]; then install poller/for-release/*.xml $(PACKAGE_DIR)/poller/for-release/ ; fi
	@if [ -d poller/for-testing ]; then install poller/for-testing/*.xml $(PACKAGE_DIR)/poller/for-testing/ ; fi
	@if [ -d include ]; then install -d $(PACKAGE_DIR)/include ; install include/*.* $(PACKAGE_DIR)/include ; fi
	@if [ -d lib ]; then install -d $(PACKAGE_DIR)/lib ; install lib/*.* $(PACKAGE_DIR)/lib ; fi
	
	tar -cf $(PACKAGE_FILE) $(PACKAGE_DIR)/lib/* $(PACKAGE_DIR)/poller/* $(PACKAGE_DIR)/src/* $(PACKAGE_DIR)/pov/* $(PACKAGE_DIR)/pcap/* $(PACKAGE_DIR)/bin/* $(PACKAGE_DIR)/Makefile $(PACKAGE_DIR)/README.md 

package: build_package

.PHONY: all clean clean_test patched prep release remake test
