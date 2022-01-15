#!/bin/bash -eu

# thanks https://stackoverflow.com/a/9002012
fn_exists() {
	[ `type -t $1`"" == 'function' ]
}

heading() {
	local text="$1"

	echo "# $text"
}

buildstep() {
	local fn="$1"

	heading "$fn"

	# "staticAnalysis" -> "SKIP_STATICANALYSIS"
	local skip_key="SKIP_${fn^^}"

	if [ "${!skip_key:-}" == "y" ]; then
		echo "Skipping because '$skip_key' set"
		return
	fi

	"$fn"

	local afterhook_fn="hook_${fn}_after"

	# if we have an "hook_<buildstep>_after" hook, run it
	if fn_exists "$afterhook_fn"; then
		buildstep "$afterhook_fn"
	fi
}

downloadDependencies() {
	go get -d ./...
}

tests() {
	go test -race ./...
}

codeGeneration() {
	go generate ./...
}

staticAnalysis() {
	# its config file is looked up from parent directories, so if we're at /workspace and we have
	# /.golangci.yml, that's going to get used (unless there's /workspace/.golangci.yml)

	# golangci-lint includes what "$ go vet ./..." would do but also more
	golangci-lint run
}

# "maybe" = if env var like BUILD_LINUX_AMD64 != true, skip build
gobuildmaybe() {
	local buildEnvVarName="$1"
	local os="$2"
	local architecture="$3"
	local binSuffix="$4"

	local buildEnvVarContent="${!buildEnvVarName:-}"

	heading "build $os-$architecture"

	if [ ! "$buildEnvVarContent" = "true" ]; then
		echo "Skipping because $buildEnvVarName != true"
		return
	fi

	local projectroot="$(pwd)"
	local dir_in_which_to_compile="${COMPILE_IN_DIRECTORY:-.}"

	if [ "${BINARY_NAME:-}" = "" ]; then
		echo "binary build not requested"
		return
	fi

	local workdir="$(pwd)"

	# NOTE: setting the "dynversion.Version" doesn't work when code under vendor/, but seems
	#       to work now fine with Go modules. https://github.com/golang/go/issues/19000

	# GOARM is suggested to be set on cross-compilation situations:
	#   https://github.com/golang/go/wiki/GoArm
	# - it doesn't hurt that it's set for when GOARCH is not ARM
	# - using v6 to be compatible with Raspberry Pi Zero W (& by extension, the original Pi)

	# compile statically so this works on Alpine Linux that doesn't have glibc
	(cd "$dir_in_which_to_compile" && GOARM=6 && GOOS="$os" GOARCH="$architecture" CGO_ENABLED=0 go build \
		-ldflags "-extldflags \"-static\" -X github.com/function61/gokit/app/dynversion.Version=$FRIENDLY_REV_ID" \
		-o "$projectroot/rel/${BINARY_NAME}${binSuffix}")
}

binaries() {
	gobuildmaybe "BUILD_LINUX_AMD64" "linux" "amd64" "_linux-amd64"
	gobuildmaybe "BUILD_LINUX_ARM" "linux" "arm" "_linux-arm"
	gobuildmaybe "BUILD_WINDOWS_AMD64" "windows" "amd64" ".exe"
	gobuildmaybe "BUILD_DARWIN_AMD64" "darwin" "amd64" "_darwin-amd64"
}

removePreviousBuildArtefacts() {
	rm -rf rel
	mkdir rel
}

standardBuildProcess() {
	# skips steps that aren't usually strictly necessary when doing minor modifications.
	# however, if you encounter a bug, remember to run full build for static analysis etc., tests etc.
	if [ -n "${FASTBUILD:-}" ]; then
		buildstep removePreviousBuildArtefacts

		buildstep binaries

		return
	fi

	buildstep removePreviousBuildArtefacts

	buildstep downloadDependencies

	# pretty much has to be just here because generated code often does not pass
	# formatting test, and static analysis doesn't pass without it
	buildstep codeGeneration

	buildstep binaries

	# static analysis to go after main compilation, because if there are serious compilation
	# errors the compiler usually gives more clear error messages
	buildstep staticAnalysis

	buildstep tests

	if [ ! -z ${GOFMT_TARGETS+x} ]; then
		echo "ERROR: GOFMT_TARGETS is deprecated"
		exit 1
	fi
}

function packageLambdaFunction {
	if [ ! -z ${FASTBUILD+x} ]; then return; fi

	# run in subshell because we need to change paths
	(
		cd rel/
		cp "${BINARY_NAME}_linux-amd64" "${BINARY_NAME}"
		rm -f lambdafunc.zip
		zip lambdafunc.zip "${BINARY_NAME}"
		rm "${BINARY_NAME}"

		# if we have deployerspec/ directory, package it into release directory
		if [ -d ../deployerspec ]; then
			cd ../deployerspec
			deployer package "$FRIENDLY_REV_ID" ../rel/deployerspec.zip
		fi
	)
}

# not being sourced?
#
# when we don't go into the if, we're in backwards compatiblity mode. this script used to be sourced,
# options were set via variables and then usually called standardBuildProcess.
# it was thought that this will modularize the build process, so unique cases could be covered.
# but in reality 95 % of cases used standardBuildProcess with very few differences.
#
# so the new style is to just invoke this script with args.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# we don't use short options but "-o" needs to be set, otherwise it mysteriously just doesn't work...
	options=$(getopt -l "directory:,binary-basename:" -o "" -a -- "$@")

	eval set -- "$options"

	while true
	do
	case $1 in
	--directory)
		shift
		export COMPILE_IN_DIRECTORY="$1"
		;;
	--binary-basename)
		shift
		export BINARY_NAME="$1"
		;;
	--)
		shift
		break;;
	*)
		echo "Unsupported arg: $1"
		exit 1
	esac
	shift
	done

	standardBuildProcess
fi
