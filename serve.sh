#!/usr/bin/bash

set -ueo pipefail

readonly PORT=4000

if ! firewall-cmd --list-ports | grep --quiet "${PORT}/tcp"; then
	firewall-cmd --add-port="${PORT}/tcp"
fi


jekyll serve --port="${PORT}" --host=0.0.0.0 --livereload
 
