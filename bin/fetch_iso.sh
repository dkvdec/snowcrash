URL="https://mega.nz/file/UYtDHAAS#VegE66ne_5B74QQrVZy4BYP7jr_-613aTden9chRQKc"
CURL="curl -Y 1 -y 10"

missing=false
for cmd in openssl; do
	if [[ ! $(command -v "$cmd" 2>&1) ]]; then
		missing=true
		echo "${0##*/}: $cmd: command not found" >&2
	fi
done
if $missing; then
	exit 1
fi

if [[ $URL =~ .*/file/[^#]*#[^#]* ]]; then
	id="${URL#*file/}"; id="${id%%#*}"
	key="${URL##*file/}"; key="${key##*#}"
else
	id="${URL#*!}"; id="${id%%!*}"
	key="${URL##*!}"
fi

raw_hex=$(echo "${key}=" | tr '\-_' '+/' | tr -d ',' | base64 -d -i 2>/dev/null | od -v -An -t x1 | tr -d '\n ')
hex=$(printf "%016x" \
	$(( 0x${raw_hex:0:16} ^ 0x${raw_hex:32:16} )) \
	$(( 0x${raw_hex:16:16} ^ 0x${raw_hex:48:16} ))
)

json=$($CURL -s -H 'Content-Type: application/json' -d '[{"a":"g", "g":"1", "p":"'"$id"'"}]' 'https://g.api.mega.co.nz/cs?id=&ak=') || exit 1; json="${json#"[{"}"; json="${json%"}]"}"
file_url="${json##*'"g":'}"; file_url="${file_url%%,*}"; file_url="${file_url//'"'/}"

json=$($CURL -s -H 'Content-Type: application/json' -d '[{"a":"g", "p":"'"$id"'"}]' 'https://g.api.mega.co.nz/cs?id=&ak=') || exit 1
at="${json##*'"at":'}"; at="${at%%,*}"; at="${at//'"'/}"

json=$(echo "${at}==" | tr '\-_' '+/' | tr -d ',' | openssl enc -a -A -d -aes-128-cbc -K "$hex" -iv "00000000000000000000000000000000" -nopad | tr -d '\0'); json="${json#"MEGA{"}"; json="${json%"}"}"
file_name="${json##*'"n":'}"
if [[ $file_name == *,* ]]; then
	file_name="${file_name%%,*}"
fi
file_name="${file_name//'"'/}"

wget -O "$file_name" "$file_url"
cat "$file_name" | openssl enc -d -aes-128-ctr -K "$hex" -iv "${raw_hex:32:16}0000000000000000" > "${file_name}.new"
mv -f "${file_name}.new" "$file_name"
