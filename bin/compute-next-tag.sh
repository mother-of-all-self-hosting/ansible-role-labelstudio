#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<Label Studio version>-<release>`, which is what this
# repository has always published (v1.0.0-0 ... v1.23.0-2):
#
# - if defaults/main.yml points at a Label Studio version that has never been
#   released, the release counter restarts at 0 (`v1.24.0-0`)
# - otherwise the counter is incremented (`v1.23.0-3`), but only if something
#   that actually affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
# The commit-message approach this replaced looked for a Renovate commit whose
# subject contained "labelstudio", while Renovate names the image it bumps
# `heartexlabs/label-studio`. It therefore matched nothing and had never cut a
# single tag in the lifetime of this repository.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `labelstudio_version:` so that neither a commented-out example nor
# `labelstudio_container_image_tag`, which is derived from it, can be mistaken
# for it.
version="$(sed -nE 's|^labelstudio_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the Label Studio version from $defaults_path"
	exit 1
fi

# Label Studio's own version is carried without a leading `v` (both here and in
# the container image tags it publishes), while this repository's tags have one.
# A leading `v` is tolerated so that a future change of convention does not
# produce a doubled prefix.
tag_prefix="v${version#v}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
