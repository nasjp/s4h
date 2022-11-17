#!/bin/sh
#shellcheck disable=SC2004,SC2016

assert() {
  expected="$1"
  input="$2"

  ./s4h.sh "$input" >tmp.sh
  chmod +x tmp.sh
  ./tmp.sh >tmp.out
  actual=$(cat tmp.out)

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

assert 0 '0'
assert 42 '42'
echo "OK"
