#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Label Studio 1.23.0 which has already
# seen three releases of it (v1.23.0-0 through v1.23.0-2), plus the v1.0.0-*
# tags this repository really carries from the era when the role pinned 1.0.0.
#
# The defaults file deliberately carries the traps this role's real one has: the
# Renovate annotation that names a different version-like string, an image tag
# derived from the version, and a commented-out example. None of them may be
# picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# labelstudio_version: 9.9.9
		# renovate: datasource=docker depName=heartexlabs/label-studio versioning=semver
		labelstudio_version: 1.23.0

		labelstudio_container_image: "{{ labelstudio_container_image_registry_prefix }}heartexlabs/label-studio:{{ labelstudio_container_image_tag }}"
		labelstudio_container_image_tag: "{{ labelstudio_version }}"
	YAML
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v1.0.0-0 v1.0.0-5 v1.23.0-0 v1.23.0-1 v1.23.0-2; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^labelstudio_version: 1.23.0|labelstudio_version: 1.24.0|' defaults/main.yml"
revert_version="sed -i 's|^labelstudio_version: 1.24.0|labelstudio_version: 1.23.0|' defaults/main.yml"
patch_version="sed -i 's|^labelstudio_version: 1.23.0|labelstudio_version: 1.23.1|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v1.24.0-0 "$(merge "$bump_version")"
expect 'task edit'    v1.24.0-1 "$(merge "$edit_task")"
expect 'template'     v1.24.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v1.23.0-3 "$(merge "$edit_task")"
expect 'version bump' v1.24.0-0 "$(merge "$bump_version")"

# A patch bump is the class Renovate would raise most often if upstream
# published patches, and it must start its own release counter rather than
# continue the minor's.
scenario 'A patch-level version bump'
expect 'patch bump' v1.23.1-0 "$(merge "$patch_version")"
expect 'task edit'  v1.23.1-1 "$(merge "$edit_task")"

# The commented-out example says 9.9.9, the Renovate annotation names an image
# rather than a version, and the image tag is Jinja. Reading any of them instead
# of the leaf literal would produce a tag off a version nothing installs.
scenario 'The decoys in defaults/main.yml'
expect 'a task' v1.23.0-3 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'a task'   v1.23.0-3  "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 3 4 5 6 7 8 9 10; do
	git tag "v1.23.0-$release_number"
done
expect 'a task' v1.23.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v1.23.0-2 already published, so there is
# nothing new to release.
expect 'a revert' ''         "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v1.23.0-3 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
