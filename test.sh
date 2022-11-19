#!/usr/bin/env bash

assert() {
  local input="$1"
  local expected="$2"

  ./shto.sh "$input" >tmp.sh
  chmod +x tmp.sh
  ./tmp.sh
  local actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

assert '0' '0'
assert '4' '4'
assert '1+1' '2'
assert '1-1' '0'
assert '1 + 1 + 1' '3'
assert '1 + 1 + 1' '3'
assert '1 + 5 - 2' '4'
assert '18 * 5 / 2 - 1' '44'
assert '18 * 5 / (2 - 1)' '90'
assert '(18 * 5 / (2 - 1))' '90'
echo "OK"
