MAN_DIR      = $(DESTDIR)/usr/share/man/man1
BIN_DIR      = $(DESTDIR)/usr/bin
CB_SHARE_DIR = $(DESTDIR)/usr/share/cb-testing
MAN          = cb-test.1.gz poll-validate.1.gz cb-replay.1.gz

all: man

man: $(MAN)

%.1.gz: %.md
	pandoc -s -t man $< -o $<.tmp
	gzip -9 < $<.tmp > $@

install:
	install -d $(BIN_DIR)
	install -d $(MAN_DIR)
	install -d $(CB_SHARE_DIR)
	install cb-test $(BIN_DIR)
	install poll-validate $(BIN_DIR)
	install cb-replay $(BIN_DIR)
	install -m 444 cgc-cb.mk $(CB_SHARE_DIR)
	install $(MAN) $(MAN_DIR)

clean:
	rm -f *.1.gz *.tmp
