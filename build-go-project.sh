#!/bin/bash -eu

# thanks https://stackoverflow.com/a/9002012
fn_exists() {
	[ `type -t $1`"" == 'function' ]
}

# NOTE: remember to call "end" too
heading1Begin() {
	local text="$1"

	if [ "${GITHUB_ACTIONS:-}" == "true" ]; then
		# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#grouping-log-lines
		echo "::group::$text"
	else
		echo "# $text"
	fi
}

heading1End() {
	if [ "${GITHUB_ACTIONS:-}" == "true" ]; then
		echo "::endgroup::"
	else
		return 0
	fi
}

heading2() {
	local text="$1"

	echo "## $text"
}

buildstep() {
	local fn="$1"

	# "staticAnalysis" -> "SKIP_STATICANALYSIS"
	local skip_key="SKIP_${fn^^}"

	if [ "${!skip_key:-}" == "y" ]; then
		if [ -n "${DEBUG:-}" ]; then
			heading1Begin "$fn (skipped because '$skip_key' set)"
			heading1End
		fi
		return
	fi

	heading1Begin "$fn"

	"$fn"

	local afterhook_fn="hook_${fn}_after"

	# if we have an "hook_<buildstep>_after" hook, run it
	if fn_exists "$afterhook_fn"; then
		buildstep "$afterhook_fn"
	fi

	heading1End
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
	# if we're in GitHub actions, use such an output format that GitHub knows to display the
	# errors inline with the code
	local output_format_arg=""
	if [ "${GITHUB_ACTIONS:-}" == "true" ]; then
		output_format_arg="--out-format=github-actions"
	fi

	# its config file is looked up from parent directories, so if we're at /workspace and we have
	# /.golangci.yml, that's going to get used (unless there's /workspace/.golangci.yml)

	# golangci-lint includes what "$ go vet ./..." would do but also more
	# timeout added because default (1m) sometimes timeouts on bigger projects in underpowered GitHub actions.
	# more details: https://github.com/golangci/golangci-lint-action/issues/297
	golangci-lint run --timeout=3m $output_format_arg
}

builds_count=0

# "maybe" = if env var like BUILD_LINUX_AMD64 != true, skip build
gobuildmaybe() {
	local buildEnvVarName="$1"
	local os="$2"
	local architecture="$3"
	local binSuffix="$4"

	local buildEnvVarContent="${!buildEnvVarName:-}"


	if [ ! "$buildEnvVarContent" = "true" ]; then
		heading2 "build $os-$architecture (skipping because $buildEnvVarName != true)"
		return
	else
		heading2 "build $os-$architecture"
	fi

	builds_count=$((builds_count+1))

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
	(cd "$dir_in_which_to_compile" && GOARM=6 GOOS="$os" GOARCH="$architecture" CGO_ENABLED=0 go build \
		-ldflags "-extldflags \"-static\" -X github.com/function61/gokit/app/dynversion.Version=$FRIENDLY_REV_ID" \
		-o "$projectroot/rel/${BINARY_NAME}${binSuffix}")
}

binaries() {
	gobuildmaybe "BUILD_LINUX_AMD64" "linux" "amd64" "_linux-amd64"
	gobuildmaybe "BUILD_LINUX_ARM" "linux" "arm" "_linux-arm"
	gobuildmaybe "BUILD_LINUX_ARM64" "linux" "arm64" "_linux-arm64"
	gobuildmaybe "BUILD_LINUX_RISCV64" "linux" "riscv64" "_linux-riscv64"
	gobuildmaybe "BUILD_WINDOWS_AMD64" "windows" "amd64" ".exe"
	gobuildmaybe "BUILD_DARWIN_AMD64" "darwin" "amd64" "_darwin-amd64"

	# none requested => caller probably doesn't use Turbo Bob which would set up
	# these ENV variables. just ask for a build according to current OS/arch
	if [ $builds_count -eq 0 ]; then
		BUILD_DEFAULT="true" # a hack, really
		# when os/arch not given, Go autodetects the current OS/arch
		gobuildmaybe "BUILD_DEFAULT" "" "" ""
	fi
}

removePreviousBuildArtefacts() {
	rm -rf rel
	mkdir rel
}

standardBuildProcess() {
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

	buildstep packageLambdaFunction

	buildstep generateCodeDocs

	if [ ! -z ${GOFMT_TARGETS+x} ]; then
		echo "ERROR: GOFMT_TARGETS is deprecated"
		exit 1
	fi
}

function packageLambdaFunction {
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

# uses doc2go to (auto)generate documentation for Go code.
# https://abhinav.github.io/doc2go/
# use case: private projects for which https://pkg.go.dev/ docs aren't accessible.
function generateCodeDocs {
	local docsTempDir="/tmp/docsite"
	rm -rf "$docsTempDir"
	doc2go -out "$docsTempDir" ./...
	tar -C "$docsTempDir" . -czf rel/code-documentation.tar.gz
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
	SKIP_PACKAGELAMBDAFUNCTION=y
	SKIP_GENERATECODEDOCS=y

	# we don't use short options but "-o" needs to be set, otherwise it mysteriously just doesn't work...
	options=$(getopt -l "directory:,binary-basename:,aws-lambda-zip,generate-code-documentation" -o "" -a -- "$@")

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
	--aws-lambda-zip)
		unset SKIP_PACKAGELAMBDAFUNCTION
		;;
	--generate-code-documentation)
		unset SKIP_GENERATECODEDOCS
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

	# has to be set, so provide a default value if unset
	FRIENDLY_REV_ID=${FRIENDLY_REV_ID:-dev}

	# skips steps that aren't usually strictly necessary when doing minor modifications.
	# however, if you encounter a bug, remember to run full build for static analysis etc., tests etc.
	if [ -n "${FASTBUILD:-}" ]; then
		SKIP_DOWNLOADDEPENDENCIES=y
		SKIP_CODEGENERATION=y
		SKIP_STATICANALYSIS=y
		SKIP_TESTS=y
		SKIP_GENERATECODEDOCS=y
	fi

	standardBuildProcess
fi
