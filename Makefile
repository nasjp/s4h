SRCS=$(wildcard *.sh)

test:
	./test.sh

lint:
	shellcheck ${SRCS}

clean:
	rm -f tmp.out tmp.sh

.PHONY: test lint clean
