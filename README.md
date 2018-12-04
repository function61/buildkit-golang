[![Build Status](https://img.shields.io/travis/function61/buildkit-golang.svg?style=for-the-badge)](https://travis-ci.org/function61/buildkit-golang)
[![Download](https://img.shields.io/docker/pulls/fn61/buildkit-golang.svg?style=for-the-badge)](https://hub.docker.com/r/fn61/buildkit-golang/)

Golang buildkit with shared low-level tools / build process required for Go projects of some quality.

See [Turbo Bob](https://github.com/function61/turbobob) for more details.


Contains
--------

- Go build tools
- Cross compiles to Linux-amd64, Linux-arm and Windows-amd64
- Runs any code generators you might have
- Runs static analysis (`$ go vet`), optional support for gometalinter
- Runs your unit tests (`$ go test`)
- [dep](https://github.com/golang/dep) for dependency management
	- dep is on the way out, but before vgo is declared for production usage we'll use dep,
	  an approach recommended [officially](https://github.com/golang/go/wiki/vgo#current-state)
- Automatically rejects Go code that is not `$ go fmt`'d
- Fully static builds (so works even on Alpine linux which doesn't have standard libc)
- Supports uploading your build artefacts to [Bintray](https://bintray.com/)
- Provides custom hooks between build steps if you have something special (though this might be a smell)
