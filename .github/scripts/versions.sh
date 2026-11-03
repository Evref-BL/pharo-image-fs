#!/usr/bin/env bash
# The release automation reads two versions out of Pharo source: the one
# release.yml tags, and the MCP pin update-mcp.yml rewrites. Each lives in a
# method of its own, and both are read here rather than in the workflows, so
# that CI runs the same extraction a release will and a selector rename fails
# on the pull request that makes it.
set -euo pipefail

cd "$(dirname "$0")/../.."

pifs_file=src/PharoImageFS/PIFSVersion.class.st
mcp_file=src/BaselineOfPharoImageFS/BaselineOfPharoImageFS.class.st

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
mcp)
	read_version "$mcp_file" mcpVersion
	;;
set-mcp)
	version="${2:?a version to pin}"
	[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
	read_version "$mcp_file" mcpVersion >/dev/null
	sed -i.bak -E "/>> mcpVersion \[\$/,/^\]\$/ { /^\t\^ '[0-9]+\.[0-9]+\.[0-9]+'\$/ s/'[0-9]+\.[0-9]+\.[0-9]+'/'$version'/; }" "$mcp_file"
	rm -f "$mcp_file.bak"
	pinned="$(read_version "$mcp_file" mcpVersion)"
	test "$pinned" = "$version"
	;;
check)
	pifs="$(read_version "$pifs_file" current)"
	mcp="$(read_version "$mcp_file" mcpVersion)"
	printf 'pharo-image-fs %s\nMCP pin        %s\n' "$pifs" "$mcp"
	;;
*)
	printf 'usage: versions.sh pifs|mcp|set-mcp <version>|check\n' >&2
	exit 64
	;;
esac
