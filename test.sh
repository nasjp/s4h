#!/usr/bin/env bash

[ "$REMOTE" == "true" ] && source="$(curl -fsSL https://raw.githubusercontent.com/nasjp/shto.sh/main/shto.sh)" || source="$(cat shto.sh)"

case_number=0
fail=1

assert() {
  local input="$1"
  local expected="$2"
  case_number=$((case_number + 1))

  bash <(bash <(printf "%s" "$source") "$input")
  local actual="$?"

  if [ "$actual" = "$expected" ]; then
    printf "%03d - OK   ) '%s' => '%s'\n" "$case_number" "$input" "$actual"
  else
    printf "%03d - FAIL ) '%s' => '%s' expected, but got '%s'\n" "$case_number" "$input" "$expected" "$actual"
    fail=0
  fi
}

printf "======================  test  ======================\n"
printf "REMOTE: %s\n\n" "${REMOTE:-false}"

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
printf "\n"

if [ $fail -eq 0 ]; then
  printf "======================  FAIL  ======================\n"
  exit 1
else
  printf "======================   OK   ======================\n"
fi
