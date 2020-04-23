![Build status](https://github.com/function61/buildkit-golang/workflows/Build/badge.svg)
[![Download](https://img.shields.io/docker/pulls/fn61/buildkit-golang.svg?style=for-the-badge)](https://hub.docker.com/r/fn61/buildkit-golang/)

Golang buildkit with shared low-level tools / build process required for Go projects of some quality.

See [Turbo Bob](https://github.com/function61/turbobob) for more details.


Contains
--------

- Go build environment
- Passes build version to your code
	* Using [gokit/dynversion](https://pkg.go.dev/github.com/function61/gokit/dynversion?tab=doc)
- Runs static analysis
	* Uses [golangci-lint](https://github.com/golangci/golangci-lint)
	  (does what `$ go vet` does + much more)
- Runs your unit tests (`$ go test`)
	* With race detector enabled
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
