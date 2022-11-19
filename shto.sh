#!/usr/bin/env bash

set -eu

######### global

input=$*

error() {
  printf "===============error===============\n" >&2
  printf "%s " "$1" >&2
  printf '\n' >&2
  printf "===============error===============\n" >&2
  exit 1
}

error_at() {
  printf '===============error===============\n' >&2
  printf "%s\n" "$input" >&2
  for ((i = 0; i < $1; i++)); do
    printf ' ' >&2
  done
  printf '^\n' >&2
  printf "%s " "$2" >&2
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
    if [[ "$1" =~ ^[[:space:]]$ ]]; then
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
    printf "%s" "$cur"
  }

  append_token() {
    token_vals+=("$1")
    token_kinds+=("$2")
    token_loc+=("$3")
  }

  scan() {
    local LC_ALL=C.UTF-8
    local i=0
    for ((i = 0; i < ${#input}; i++)); do
      local char="${input:i:1}"
      local rest="${input:i}"

      if is_space "$char"; then
        continue
      fi

      local symbols=('-' '+' '*' '/' '(' ')')
      local match=1
      for symbol in "${symbols[@]}"; do
        if starts_with "$char" "$symbol"; then
          append_token "$char" 'TOKEN::RESERVED' "$i"
          match=0
          break
        fi
      done
      if [ $match -eq 0 ]; then
        continue
      fi

      if is_number "$char"; then
        local n
        n=$(read_num "$rest")
        append_token "$n" 'TOKEN::NUMBER--' "$i"
        local len=${#n}
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

  scan
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
    printf "%s" "${token_vals[$token_i]}"
  }

  equal_val() {
    if [ $token_i -lt ${#token_vals[@]} ] && [ "${token_vals[$token_i]}" == "$1" ]; then
      return 0
    fi
    return 1
  }

  expect_val() {
    if equal_val "$1"; then
      return 0
    fi
    error_at "${token_loc[$token_i]}" "(parse) expected '$1'"
  }

  equal_kind() {
    if [ $token_i -lt ${#token_kinds[@]} ] && [ "${token_kinds[$token_i]}" == "$1" ]; then
      return 0
    fi
    return 1
  }

  next_token() {
    token_i=$((token_i + 1))
  }

  append_node() {
    node_i=$((node_i + 1))

    node_kinds+=("$1")
    node_vals+=("$2")
    node_lhs+=("$3")
    node_rhs+=("$4")
  }

  primary() {
    if equal_val '('; then
      next_token
      _expr
      expect_val ')'
      next_token
      return
    fi

    if equal_kind 'TOKEN::NUMBER--'; then
      append_node 'NODE::NUMBER' "$(token_val "$token_i")" '_' '_'
      next_token
      return
    fi

    error_at "${token_loc[$token_i]}" '(parse) invalid node structure'
  }

  mul() {
    primary
    local node_lhs_i=0

    for (( ; ; )); do
      if equal_val '*'; then
        next_token
        node_lhs_i=$node_i
        primary
        append_node 'NODE::MUL' '_' $node_lhs_i $node_i
        continue
      fi

      if equal_val '/'; then
        next_token
        node_lhs_i=$node_i
        primary
        append_node 'NODE::DIV' '_' $node_lhs_i $node_i
        continue
      fi

      return 0
    done
  }

  _expr() {
    mul
    local node_lhs_i=0

    for (( ; ; )); do
      if equal_val '+'; then
        next_token
        node_lhs_i=$node_i
        mul
        append_node 'NODE::ADD' '_' $node_lhs_i $node_i
        continue
      fi

      if equal_val '-'; then
        next_token
        node_lhs_i=$node_i
        mul
        append_node 'NODE::SUB' '_' $node_lhs_i $node_i
        continue
      fi

      return 0
    done
  }

  _expr
}

generate() {
  prologue() {
    printf '#!/usr/bin/env bash

set -eu

exit "'
  }

  epilogue() {
    printf '"\n'
  }

  gen() {
    if [ "${node_kinds[$1]}" == "NODE::NUMBER" ]; then
      printf "%s" "${node_vals[$1]}"
      return 0
    fi

    local op_kinds=('NODE::ADD' 'NODE::SUB' 'NODE::MUL' 'NODE::DIV')
    local ops=('+' '-' '*' '/')
    local i=0
    for ((i = 0; i < ${#op_kinds[@]}; i++)); do
      if [ "${node_kinds[$1]}" == "${op_kinds[$i]}" ]; then
        local left
        left=$(gen "${node_lhs[$1]}")
        local right
        right=$(gen "${node_rhs[$1]}")
        printf "%s" "\$(($left ${ops[$i]} $right))"
        return 0
      fi
    done

    error "(generate) unexpected node kind ${node_kinds[$1]}"
  }

  prologue
  gen $node_i
  epilogue
}

run() {
  tokenize
  parse
  generate
}

run
