SRCS=$(wildcard *.sh)

test:
	@bash test.sh

remotetest:
	@REMOTE=true bash test.sh

lint:
	@shellcheck ${SRCS}

clean:
	@rm -f tmp.out tmp.sh

.PHONY: test lint clean
