SRCS=$(wildcard *.sh)

test:
	./test.sh

clean:
	rm -f tmp.sh tmp.out

.PHONY: test
