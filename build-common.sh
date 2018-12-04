#!/bin/bash -eu

# thanks https://stackoverflow.com/a/9002012
fn_exists() {
	[ `type -t $1`"" == 'function' ]
}

buildstep() {
	local fn="$1"

	echo "# $fn"

	"$fn"

	local afterhook_fn="hook_${fn}_after"

	# if we have an "hook_<buildstep>_after" hook, run it
	if fn_exists "$afterhook_fn"; then
		buildstep "$afterhook_fn"
	fi
}

downloadDependencies() {
	dep ensure
}

checkFormatting() {
	# root dir by default (recurses into subdirs)
	# unfortunately sometimes we need to override this because "." would include vendor/
	# and vendors are sometimes unformatted
	local gofmtTargets="${GOFMT_TARGETS:-.}"

	# variable not intentionally quoted so we can give gofmt multiple args
	local offenders=$(gofmt -l $gofmtTargets)

	if [ ! -z "$offenders" ]; then
		>&2 echo "formatting errors: $offenders"
		exit 1
	fi
}

unitTests() {
	go test ./...
}

codeGeneration() {
	go generate ./...
}

staticAnalysis() {
	go vet ./...
}

gobuild() {
	local os="$1"
	local architecture="$2"
	local binSuffix="$3"

	local projectroot="$(pwd)"
	local dir_in_which_to_compile="${COMPILE_IN_DIRECTORY:-.}"

	if [ "${BINARY_NAME:-}" = "" ]; then
		echo "binary build not requested"
		return
	fi

	# compile statically so this works on Alpine Linux that doesn't have glibc
	# DEPRECATED: main.version: supporting it for a transition period to gokit/dynversion
	(cd "$dir_in_which_to_compile" && GOOS="$os" GOARCH="$architecture" CGO_ENABLED=0 go build \
		-ldflags "-extldflags \"-static\" -X github.com/function61/gokit/dynversion.Version=$FRIENDLY_REV_ID -X main.version=$FRIENDLY_REV_ID" \
		-o "$projectroot/rel/${BINARY_NAME}${binSuffix}")
}

buildLinuxArm() {
	gobuild "linux" "arm" "_linux-arm"
}

buildLinuxAmd64() {
	gobuild "linux" "amd64" "_linux-amd64"
}

buildWindowsAmd64() {
	if [ ! "${INCLUDE_WINDOWS:-}" = "true" ]; then
		echo "windows build not requested"
		return
	fi

	gobuild "windows" "amd64" ".exe"
}

uploadBuildArtefactsToBintray() {
	if [ ! "${PUBLISH_ARTEFACTS:-}" = "true" ]; then
		echo "publish not requested"
		return
	fi

	if [ "${BINTRAY_PROJECT:-}" = "" ]; then
		echo "BINTRAY_PROJECT not set; skipping uploadBuildArtefactsToBintray"
		return
	fi

	# Bintray creds in format "username:apikey"
	if [[ "${BINTRAY_CREDS:-}" =~ ^([^:]+):(.+) ]]; then
		local bintrayUser="${BASH_REMATCH[1]}"
		local bintrayApikey="${BASH_REMATCH[2]}"
	else
		echo "error: BINTRAY_CREDS not defined"
		exit 1
	fi

	# the CLI breaks automation unless opt-out..
	export JFROG_CLI_OFFER_CONFIG=false

	jfrog-cli bt upload \
		"--user=$bintrayUser" \
		"--key=$bintrayApikey" \
		--publish=true \
		'rel/*' \
		"$BINTRAY_PROJECT/main/$FRIENDLY_REV_ID" \
		"$FRIENDLY_REV_ID/"
}

removePreviousBuildArtefacts() {
	rm -rf rel
	mkdir rel
}

standardBuildProcess() {
	buildstep removePreviousBuildArtefacts

	buildstep downloadDependencies

	buildstep checkFormatting

	# pretty much has to be just here because generated code often does not pass
	# formatting test, and static analysis doesn't pass without it
	buildstep codeGeneration

	buildstep staticAnalysis

	buildstep unitTests

	buildstep buildLinuxAmd64

	buildstep buildLinuxArm

	buildstep buildWindowsAmd64

	buildstep uploadBuildArtefactsToBintray
}
