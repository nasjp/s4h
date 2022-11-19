#!/usr/bin/env bash

set -eu

######### global

input=$*

error() {
  printf "===============error===============\n" >&2
  printf "%s " $1 >&2
  printf '\n' >&2
  printf "===============error===============\n" >&2
  exit 1
}

error_at() {
  printf '===============error===============\n' >&2
  printf "$input\n" >&2
  for ((i = 0; i < $1; i++)); do
    printf ' ' >&2
  done
  printf '^\n' >&2
  printf "%s " $2 >&2
  printf '\n' >&2
  printf "===============error===============\n" >&2
  exit 1
}

######### tokenizer

token_vals=()
token_kinds=()
token_loc=()

tokenize() {
  is_space() {
    if [[ "$1" = *[[:space:]]* ]]; then
      return 0
    fi
    return 1
  }

  is_number() {
    case $1 in *[!0-9]*) return 1 ;; esac
  }

  starts_with() {
    local i=0
    for ((i = 0; i < ${#2}; i++)); do
      if [ "${1:i:1}" == "${2:i:1}" ]; then
        continue
      fi
      return 1
    done
    return 0
  }

  read_num() {
    local i=0
    local cur=''
    for ((i = 0; i < ${#1}; i++)); do
      if is_number "${1:i:1}"; then
        cur="$cur${1:i:1}"
        continue
      fi
      break
    done
    printf "$cur"
  }

  append_token() {
    token_vals+=("$1")
    token_kinds+=("$2")
    token_loc+=("$3")
  }

  local LC_ALL=C.UTF-8

  local n=0
  local len=0

  local i=0
  for ((i = 0; i < ${#input}; i++)); do
    if is_space "${input:i:1}"; then
      continue
    fi

    if starts_with "${input:i}" '-'; then
      append_token "${input:i:1}" 'TOKEN::RESERVED' $i
      continue
    fi

    if starts_with "${input:i}" '+'; then
      append_token "${input:i:1}" 'TOKEN::RESERVED' $i
      continue
    fi

    if starts_with "${input:i}" '*'; then
      append_token "${input:i:1}" 'TOKEN::RESERVED' $i
      continue
    fi

    if starts_with "${input:i}" '/'; then
      append_token "${input:i:1}" 'TOKEN::RESERVED' $i
      continue
    fi

    if starts_with "${input:i}" '('; then
      append_token "${input:i:1}" 'TOKEN::RESERVED' $i
      continue
    fi

    if starts_with "${input:i}" ')'; then
      append_token "${input:i}" 'TOKEN::RESERVED' $i
      continue
    fi

    if is_number "${input:i:1}"; then
      n=$(read_num "${input:i}")
      append_token $n 'TOKEN::NUMBER--' $i
      len=${#n}
      i=$((i + len - 1))
      continue
    fi

    error_at "$i" '(tokenize) invalid charactor'
  done

  if [ $i -eq 0 ]; then
    error '(tokenize) empty input'
  fi

  return 0
}

######### parser

node_kinds=()
node_vals=()
node_lhs=()
node_rhs=()
node_i=-1
token_i=0

parse() {
  token_val() {
    printf "${token_vals[${token_i}]}"
  }

  equal_val() {
    if [ ${token_i} -lt ${#token_vals[@]} ] && [ "${token_vals[${token_i}]}" == "$1" ]; then
      return 0
    fi
    return 1
  }

  expect_val() {
    if equal_val $1; then
      return 0
    fi
    error_at ${token_loc[${token_i}]} "expected '$1'"
  }

  equal_kind() {
    if [ ${token_i} -lt ${#token_kinds[@]} ] && [ "${token_kinds[${token_i}]}" == "$1" ]; then
      return 0
    fi
    return 1
  }

  next_token() {
    token_i=$(($token_i + 1))
  }

  append_node() {
    node_i=$(($node_i + 1))

    node_kinds+=($1)
    node_vals+=("$2")
    node_lhs+=($3)
    node_rhs+=($4)
  }

  primary() {
    if equal_val '('; then
      next_token
      expr
      expect_val ')'
      next_token
      return
    fi

    if equal_kind 'TOKEN::NUMBER--'; then
      append_node 'NODE::NUMBER' $(token_val ${token_i}) '_' '_'
      next_token
      return
    fi

    error_at ${token_loc[${token_i}]} '(parse) invalid node structure'
  }

  mul() {
    primary
    local node_lhs_i=0

    for (( ; ; )); do
      if equal_val '*'; then
        next_token
        node_lhs_i=${node_i}
        primary
        append_node 'NODE::MUL' '_' ${node_lhs_i} ${node_i}
        continue
      fi

      if equal_val '/'; then
        next_token
        node_lhs_i=${node_i}
        primary
        append_node 'NODE::DIV' '_' ${node_lhs_i} ${node_i}
        continue
      fi

      return 0
    done
  }

  expr() {
    mul
    local node_lhs_i=0

    for (( ; ; )); do
      if equal_val '+'; then
        next_token
        node_lhs_i=${node_i}
        mul
        append_node 'NODE::ADD' '_' ${node_lhs_i} ${node_i}
        continue
      fi

      if equal_val '-'; then
        next_token
        node_lhs_i=${node_i}
        mul
        append_node 'NODE::SUB' '_' ${node_lhs_i} ${node_i}
        continue
      fi

      return 0
    done
  }

  expr
}

generate() {
  prologue() {
    printf '#!/usr/bin/env bash

set -eu

exit "'
  }

  epilogue() {
    printf '"'
  }

  gen() {
    local out=""
    local left=0
    local right=0
    if [ "${node_kinds[$1]}" == "NODE::NUMBER" ]; then
      out="${node_vals[$1]}"
      printf "$out"
      return 0
    fi

    if [ "${node_kinds[$1]}" == "NODE::ADD" ]; then
      left=$(gen "${node_lhs[$1]}")
      right=$(gen "${node_rhs[$1]}")

      out="\$(($left + $right))"
      printf "$out"
      return 0
    fi

    if [ "${node_kinds[$1]}" == "NODE::SUB" ]; then
      left=$(gen "${node_lhs[$1]}")
      right=$(gen "${node_rhs[$1]}")

      out="\$(($left - $right))"
      printf "$out"
      return 0
    fi

    if [ "${node_kinds[$1]}" == "NODE::DIV" ]; then
      left=$(gen "${node_lhs[$1]}")
      right=$(gen "${node_rhs[$1]}")

      out="\$(($left / $right))"
      printf "$out"
      return 0
    fi

    if [ "${node_kinds[$1]}" == "NODE::MUL" ]; then
      left=$(gen "${node_lhs[$1]}")
      right=$(gen "${node_rhs[$1]}")

      out="\$(($left * $right))"
      printf "$out"
      return 0
    fi

    error "(generate) unexpected node kind ${node_kinds[$1]}"
  }

  prologue
  gen ${node_i}
  epilogue
}

run() {
  tokenize

  parse

  generate
  printf "\n"
}

run
