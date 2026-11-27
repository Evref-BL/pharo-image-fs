#!/usr/bin/env bash
# release.yml tags the version PIFSVersion class >> current answers. It is read
# here rather than in the workflow, so that CI runs the same extraction a
# release will and a selector rename fails on the pull request that makes it.
set -euo pipefail

cd "$(dirname "$0")/../.."

pifs_file=src/PharoImageFS/PIFSVersion.class.st

# Matched between a Tonel method's header and its closing bracket, so the
# answer comes from the named method rather than from whichever method in the
# file happens to return something version-shaped.
read_version() { # file selector
	local version
	version="$(sed -nE "/>> $2 \[\$/,/^\]\$/ s/^\t\^ '([0-9]+\.[0-9]+\.[0-9]+)'\$/\1/p" "$1")"
	if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		printf '%s must answer a release version from #%s, found: %s\n' \
			"$1" "$2" "${version:-nothing}" >&2
		return 1
	fi
	printf '%s\n' "$version"
}

case "${1:-}" in
pifs)
	read_version "$pifs_file" current
	;;
check)
	printf 'pharo-image-fs %s\n' "$(read_version "$pifs_file" current)"
	;;
*)
	printf 'usage: versions.sh pifs|check\n' >&2
	exit 64
	;;
esac
