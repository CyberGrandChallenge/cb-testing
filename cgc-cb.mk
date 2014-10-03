ifndef POLLS_RELEASE_COUNT
POLLS_RELEASE_COUNT=1000
endif

ifndef POLLS_RELEASE_SEED
POLLS_RELEASE_SEED=$(shell od -An -i -N 4 /dev/urandom)
endif

ifndef POLLS_RELEASE_MAX_DEPTH
POLLS_RELEASE_MAX_DEPTH=1048575
endif

ifndef POLLS_TESTING_COUNT
POLLS_TESTING_COUNT=1000
endif

ifndef POLLS_TESTING_SEED
POLLS_TESTING_SEED=$(shell od -An -i -N 4 /dev/urandom)
endif

ifndef POLLS_TESTING_MAX_DEPTH
POLLS_TESTING_MAX_DEPTH=1048575
endif

ifndef TCP_PORT
TCP_PORT=0
endif

ifndef BIN_COUNT
BIN_COUNT=0
endif

LIBS       = -L/usr/lib -lcgc

ifdef NO_STRIP
LDFLAGS    = -nostdlib -static
else
LDFLAGS    = -nostdlib -static -s
endif

POLLS_RELEASE = $(wildcard poller/for-release/*.xml)
POLLS_TESTING = $(wildcard poller/for-testing/*.xml)
POVS = $(wildcard pov/*.xml)

CC			= /usr/i386-linux-cgc/bin/clang
LD			= /usr/i386-linux-cgc/bin/ld
CXX			= /usr/i386-linux-cgc/bin/clang++
LD_ELF                  = /usr/bin/ld

SHELL		:= $(SHELL) -e
BIN_DIR		= bin
BUILD_DIR	= build
ifeq ("/usr/i386-linux-cgc/bin/clang", "$(CC)")
CGC_CFLAGS	= -nostdlib -fno-builtin -nostdinc -Iinclude -Ilib -I/usr/include $(CFLAGS) -DCGC_BIN_COUNT=$(BIN_COUNT)
else
CGC_CFLAGS	= -nostdlib -fno-builtin -nostdinc -nostartfiles -nodefaultlibs -Iinclude -Ilib -I/usr/include $(CFLAGS) -DCGC_BIN_COUNT=$(BIN_COUNT)
endif

EXE			= $(AUTHOR_ID)_$(SERVICE_ID)
PATH		:= /usr/i386-linux-cgc/bin:$(PATH)
BINS		= $(wildcard cb_*)
SRCS		= $(wildcard src/*.c src/*.cc lib/*.c lib/*.cc)
CXX_SRCS 	= $(filter %.cc, $(SRCS))

OBJS_		= $(SRCS:.c=.o)
OBJS		= $(OBJS_:.cc=.o)
ELF_OBJS	= $(OBJS:.o=.elf)

POLL_RELEASE_LOGS  = $(POLLS_RELEASE:.xml=.log)
POLL_TESTING_LOGS  = $(POLLS_TESTING:.xml=.log)
POV_LOGS	= $(POVS:.xml=.log)

BUILD_POLL_TESTING_LOG  = $(addprefix $(BUILD_DIR)/, $(POLL_RELEASE_LOGS))
BUILD_POLL_RELEASE_LOG  = $(addprefix $(BUILD_DIR)/, $(POLL_TESTING_LOGS))
BUILD_POV_LOG   = $(addprefix $(BUILD_DIR)/, $(POV_LOGS))

PATCHED_CFLAGS  = -DPATCHED $(CGC_CFLAGS) 
PATCHED_DIR     = patched
PATCHED_EXE     = $(EXE)_patched
PATCHED_PATH    = $(BIN_DIR)/$(PATCHED_EXE)
PATCHED_OBJS    = $(addprefix $(BUILD_DIR)/$(PATCHED_DIR)/, $(OBJS))
PATCHED_ELF_OBJS = $(addprefix $(BUILD_DIR)/$(PATCHED_DIR)/, $(ELF_OBJS))
PATCHED_ELF_STUB = $(BUILD_DIR)/$(PATCHED_DIR)/syscall-stub.elf
PATCHED_SO	= $(BUILD_DIR)/$(PATCHED_DIR)/so/$(EXE).so

RELEASE_CFLAGS  = -DNPATCHED $(CGC_CFLAGS)
RELEASE_DIR     = release
RELEASE_EXE	= $(EXE)
RELEASE_PATH    = $(BIN_DIR)/$(RELEASE_EXE)
RELEASE_OBJS    = $(addprefix $(BUILD_DIR)/$(RELEASE_DIR)/, $(OBJS))

PCAP_DIR        = pcap

all: build test

prep:
	@mkdir -p $(BUILD_DIR)/$(PATCHED_DIR)/lib $(BUILD_DIR)/$(RELEASE_DIR)/lib $(BUILD_DIR)/$(RELEASE_DIR)/src $(BUILD_DIR)/$(PATCHED_DIR)/src $(BUILD_DIR)/pov $(BUILD_DIR)/poller/for-testing $(BUILD_DIR)/poller/for-release bin $(PCAP_DIR)
	@mkdir -p $(BUILD_DIR)/$(PATCHED_DIR)/so

$(BINS): cb_%:
	(cd $@; make -f ../Makefile build SERVICE_ID=$(SERVICE_ID)_$* BIN_COUNT=$(words $(BINS)) )
	cp $@/bin/* bin

build-binaries: $(BINS)

clean-binaries: ; $(foreach dir, $(BINS), (cd $(dir) && make -f ../Makefile clean) &&) : 

%.elf: %.o
	cp $< $@
	cgc2elf $@

$(PATCHED_ELF_STUB):
	$(CC) -c -nostdlib -fno-builtin -nostdinc -o $(BUILD_DIR)/$(PATCHED_DIR)/syscall-stub.elf /usr/share/cb-testing/syscall-stub.c
	cgc2elf $(BUILD_DIR)/$(PATCHED_DIR)/syscall-stub.elf

# Release rules
release: prep $(RELEASE_PATH)
$(RELEASE_PATH): $(RELEASE_OBJS)
	$(LD) $(LDFLAGS) -o $(RELEASE_PATH) -I$(BUILD_DIR)/$(RELEASE_DIR)/lib $^ $(LIBS)
$(BUILD_DIR)/$(RELEASE_DIR)/%.o: %.c
	$(CC) -c $(RELEASE_CFLAGS) -o $@ $<
$(BUILD_DIR)/$(RELEASE_DIR)/%.o: %.cc
	$(CXX) -c $(RELEASE_CFLAGS) $(CXXFLAGS) -o $@ $<

# Patched rules
patched: prep $(PATCHED_PATH) $(PATCHED_SO)
$(PATCHED_PATH): $(PATCHED_OBJS)
	$(LD) $(LDFLAGS) -o $(PATCHED_PATH) $^ $(LIBS)
$(BUILD_DIR)/$(PATCHED_DIR)/%.o: %.c
	$(CC) -c $(PATCHED_CFLAGS) -o $@ $<
$(BUILD_DIR)/$(PATCHED_DIR)/%.o: %.cc
	$(CXX) -c $(PATCHED_CFLAGS) $(CXXFLAGS) -o $@ $<

ifneq ("$(CXX_SRCS)", "")
$(PATCHED_SO):
	echo "GOT" !$(CXX_SRCS)!
	@echo "SO build artifact not currently supported for C++ services"
else
$(PATCHED_SO): $(PATCHED_ELF_OBJS) $(PATCHED_ELF_STUB)
	$(LD_ELF) -shared -o $@ $^ 
endif

generate-polls:
	if [ -f poller/for-release/machine.py ] && [ -f poller/for-release/state-graph.yaml ]; then generate-polls --count $(POLLS_RELEASE_COUNT) --seed $(POLLS_RELEASE_SEED) --depth $(POLLS_RELEASE_MAX_DEPTH) poller/for-release/machine.py poller/for-release/state-graph.yaml poller/for-release; fi
	if [ -f poller/for-testing/machine.py ] && [ -f poller/for-testing/state-graph.yaml ]; then generate-polls --count $(POLLS_TESTING_COUNT) --seed $(POLLS_TESTING_SEED) --depth $(POLLS_TESTING_MAX_DEPTH) poller/for-testing/machine.py poller/for-testing/state-graph.yaml poller/for-testing; fi

check: generate-polls
# Verify the CBs are in the DECREE format
	$(foreach cb, $(wildcard bin/$(EXE)*), echo $(cb) && cgcef_verify $(cb) && ) :
# Polls that the CB author intends to release the resulting network traffic during CQE
	if [ -d poller/for-release ]; then cb-test --port $(TCP_PORT) --cb $(filter-out %_patched, $(notdir $(wildcard bin/$(EXE)*))) --xml_dir poller/for-release/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(RELEASE_EXE).for-release.txt --pcap pcap/$(RELEASE_EXE)_poll.pcap ; fi
	if [ -d poller/for-release ]; then cb-test --port $(TCP_PORT) --cb $(filter %_patched, $(notdir $(wildcard bin/$(EXE)*)))     --xml_dir poller/for-release/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(PATCHED_EXE).for-release.txt ; fi

# Polls that the CB author intends to NOT release the resulting network traffic during CQE
	if [ -d poller/for-testing ]; then cb-test --port $(TCP_PORT) --cb $(filter-out %_patched, $(notdir $(wildcard bin/$(EXE)*))) --xml_dir poller/for-testing/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(RELEASE_EXE).for-testing.txt ; fi
	if [ -d poller/for-testing ]; then cb-test --port $(TCP_PORT) --cb $(filter %_patched, $(notdir $(wildcard bin/$(EXE)*)))     --xml_dir poller/for-testing/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(PATCHED_EXE).for-testing.txt ; fi

# POVs that should generate an identified crash for CQE when sent to the release CB but not the patched CB
	cb-test --port $(TCP_PORT) --cb $(filter-out %_patched, $(notdir $(wildcard bin/$(EXE)*))) --xml_dir pov/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(RELEASE_EXE).pov.txt --should_core
	cb-test --port $(TCP_PORT) --cb $(filter %_patched, $(notdir $(wildcard bin/$(EXE)*)))     --xml_dir pov/ --directory $(BIN_DIR) --log $(BUILD_DIR)/$(PATCHED_EXE).pov.txt --failure_ok

clean_test:
	@-rm -f $(BUILD_POV_LOG) $(BUILD_POLL_LOG)

clean: clean_test clean-binaries
	-rm -rf $(BUILD_DIR) $(BIN_DIR) $(PCAP_DIR)
	-rm -f test.log 
	-rm -f poller/for-release/edges.png poller/for-release/nodes.png
	-rm -f poller/for-release/gen_*.xml 
	-rm -f poller/for-release/graph.dot
	-rm -f poller/for-testing/edges.png poller/for-testing/nodes.png
	-rm -f poller/for-testing/gen_*.xml 
	-rm -f poller/for-testing/graph.dot

ifeq ($(strip $(BINS)),)
build: prep release patched
else
build: prep build-binaries
endif

test: build check

.PHONY: all clean clean_test patched prep release remake test $(BINS)
