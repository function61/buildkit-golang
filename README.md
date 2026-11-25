Nix container proof of concept
==============================

The `flake.nix` builds a Linux amd64 Go build image from a pinned Nixpkgs revision.
The GitHub workflow publishes the experiment as `fn61/buildkit-golang:nix-poc`
on pushes to `feature/build-from-nix`. With Nix flakes enabled:

```sh
nix build .#
docker load < result
docker run --rm buildkit-golang-nix-poc:latest go version
```

To run the shared build script against a Go project, for example:

```sh
docker run --rm -v "$PWD:/workspace" -e FRIENDLY_REV_ID=local -e SKIP_TESTS=y \
  buildkit-golang-nix-poc:latest /usr/bin/build-go-project.sh
```

The image has no C toolchain and sets `CGO_ENABLED=0`. The script's default test
step uses `go test -race`, which needs CGO and a C compiler, so it must be skipped
as above. Run non-race tests separately with `go test ./...` if appropriate.
Projects needing CGO cannot be built or tested with this POC as-is.

The image omits `godoc`, `gohack` and Function61's `deployer`, which are not directly
available in the pinned Nixpkgs. In particular, packaging a `deployerspec`
requires `deployer` and will not work. Tool versions and the underlying
environment differ from the original image; full compatibility is not guaranteed.
The image also excludes `doc2go`, `protoc` and `protoc-gen-go`; documentation
generation and protobuf code generation require those tools to be supplied separately.

Development shell
-----------------

On Linux amd64, a downstream project can use the same tools and build script
without Docker. With Nix flakes enabled, run this from the project's directory:

```sh
nix develop github:function61/buildkit-golang/feature/build-from-nix
SKIP_TESTS=y build-go-project.sh --binary-basename my-project
go test ./...
```

Alternatively, run just the build without entering an interactive shell:

```sh
nix develop github:function61/buildkit-golang/feature/build-from-nix \
  --command env SKIP_TESTS=y build-go-project.sh --binary-basename my-project
```

Replace `my-project` with the desired binary name. For stable tool versions,
replace the branch in the flake reference with a specific commit, or use this
flake as a locked input in the downstream project's own flake.

The shell sets `CGO_ENABLED=0` and `GOTOOLCHAIN=local`, and does not add a C
toolchain. The shared script's race-test step must therefore be skipped as in
the examples above. Other optional steps have the same missing-tool limitations
as the image. The shell uses the host's home directory and Go cache locations;
it does not install the image's root-level lint configuration, so lint uses a
configuration found in the project or its parent directories, or its defaults.
Commands run directly on the host, can access the network, and can modify the
project (including `go.mod` and `go.sum`); this is not a sandboxed Nix build.

Image size
----------

One `docker images` comparison reported the Nix POC at **1.12 GB**, versus
**1.68 GB** for `fn61/buildkit-golang:20260604_1344_ff654e98`: about 33% smaller.
These are local image sizes for those specific builds, not compressed download sizes.
