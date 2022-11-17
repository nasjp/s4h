#!/bin/sh
#shellcheck disable=SC2004,SC2016

input=$1

echo "#!/bin/sh"
echo ""

is_numeric() {
  if [ $# -ne 1 ]; then
    return 1
  fi

  expr "$1" + 1 >/dev/null 2>&1

  if [ $? -ge 2 ]; then
    return 1
  fi

  return 0
}

run() {
  str=$1
  all=$1
  count=0
  result=0
  next_op=""
  while [ -n "$str" ]; do
    count=$(($count + 1))
    rest="${str#?}"
    char="${str%"$rest"}"

    if [ $(($count)) -eq 1 ]; then
      result=$(($result + $char))
      str="$rest"
      continue
    fi

    if [ "'$char'" = "' '" ]; then
      str="$rest"
      continue
    fi

    if [ $char = "+" ] || [ $char = "-" ]; then
      next_op="$char"
      str="$rest"
      continue
    fi

    if ! is_numeric $char; then
      echo "${rest}"
      exit 1
    fi

    if [ $next_op = "+" ]; then
      result=$(($result + $char))
      str="$rest"
      continue
    fi

    if [ $next_op = "-" ]; then
      result=$(($result - $char))
      str="$rest"
    fi

    str="$rest"
  done

  echo $result
}

result=$(run "$input")

echo "echo $result"
