![Build status](https://github.com/function61/buildkit-golang/workflows/Build/badge.svg)
[![Download](https://img.shields.io/docker/pulls/fn61/buildkit-golang.svg?style=for-the-badge)](https://hub.docker.com/r/fn61/buildkit-golang/)

Golang buildkit with shared low-level tools / build process required for Go projects of some quality.

See [Turbo Bob](https://github.com/function61/turbobob) for more details.


How to use
----------

[build-common.sh](build-common.sh) is available inside the Docker image at `/build-common.sh`.

Our typical projects using it declare
[bin/build.sh](https://github.com/function61/function53/blob/master/bin/build.sh) having contents:

```bash
!/bin/bash -eu

source /build-common.sh

BINARY_NAME="function53"
COMPILE_IN_DIRECTORY="cmd/function53"

standardBuildProcess
```

Therefore building is as simple as running `bin/build.sh`. Cross compilation is done depending on
ENV variables. E.g. to build for `Linux/ARM` you should have `BUILD_LINUX_ARM=true` set. These are
handled automatically if you use Turbo Bob.


Features
--------

- Go build environment
- Passes build version to your code
	* Using [gokit/app/dynversion](https://pkg.go.dev/github.com/function61/gokit/app/dynversion)
- Runs static analysis
	* Uses [golangci-lint](https://github.com/golangci/golangci-lint)
	  (does what `$ go vet` does + much more)
- Runs your unit tests (`$ go test`)
	* With race detector enabled
- Contains [goimports](https://pkg.go.dev/golang.org/x/tools/cmd/goimports) which is like `gofmt`
  for your imports - it can sometimes even automatically add missing imports!
- Contains [gopls](https://github.com/golang/tools/blob/master/gopls/README.md), a Go
  [language server](https://langserver.org/). Works in a container without changes to one's host system!
	* Working is somewhat tied to use with Turbo Bob (LSP working inside container needs a few tricks)
- Fetches your dependencies using Go modules
- Automatically rejects Go code that is not `$ go fmt`'d
- Runs any code generators you might have
	* Runs `$ go generate ./...`
- Fully static builds (so works even on Alpine linux which doesn't have standard libc)
- Helper for packaging your binary as Lambda function
- [Deployer](https://github.com/function61/deployer) integration
	* For packaging `deployerspec.zip` files
- Provides custom hooks between build steps if you have something special (though this might be a smell)
- Cross compilation support:
	* Linux-amd64
	* Linux-arm
	* Windows-amd64
	* macOS-amd64
