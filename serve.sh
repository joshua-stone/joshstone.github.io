#!/usr/bin/bash

set -ueo pipefail

readonly PORT=4000
readonly URL="http://0.0.0.0:${PORT}/"
if ! firewall-cmd --list-ports | grep --quiet "${PORT}/tcp"; then
	firewall-cmd --add-port="${PORT}/tcp"
fi

jekyll serve --port="${PORT}" --host=0.0.0.0 --livereload &

PID=$!

while ! wget --quiet -O - "${URL}" > /dev/null; do	
    sleep 0.5
done

xdg-open "${URL}"

wait "${PID}"
