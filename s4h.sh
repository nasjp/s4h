#!/bin/sh
#shellcheck disable=SC2004,SC2016

input=$1

echo "#!/bin/sh"
echo ""
echo "echo $input"
