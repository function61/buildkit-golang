FROM golang:1.19

WORKDIR /workspace

# zip for packaging Lambda functions

# /root/gohack (default checkout path) symlinked because it isn't visible outside the container.
# target not /workspace/vendor because that has special semantic meaning with go modules and doesn't work.

# deleting /go/pkg because Turbo Bob caching wouldn't replace /go/pkg (see turbobob-baseimage.json)
# with symlink to host if the tree already has content

# go install something@latest is because if you don't specify version, it requires you have a Go module set up

RUN apt update && apt install -y zip \
	&& go install golang.org/x/tools/cmd/goimports@latest \
	&& go install golang.org/x/tools/cmd/godoc@latest \
	&& go install golang.org/x/tools/gopls@latest \
	&& go install github.com/function61/deployer/cmd/deployer@latest \
	&& go install github.com/rogpeppe/gohack@latest \
	&& go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
	&& wget https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protoc-3.17.3-linux-x86_64.zip \
	&& unzip protoc-3.17.3-linux-x86_64.zip && mv bin/protoc /usr/local/bin/ && cd / && rm -rf /tmp/protoc \
	&& ln -s /workspace/gohack /root/gohack \
	&& curl --fail --location -o /go/bin/depth https://github.com/KyleBanks/depth/releases/download/v1.2.1/depth_1.2.1_linux_amd64 \
	&& chmod +x /go/bin/depth \
	&& curl --fail --location https://function61.com/app-dl/api/github.com/golangci/golangci-lint/latest_releases_asset/golangci-lint-%2A-linux-amd64.tar.gz \
		| tar --strip-components=1 -C /usr/local/bin -xzf - --wildcards 'golangci-lint-*-linux-amd64/golangci-lint' \
	&& rm -rf /go/pkg \
	&& mkdir /tmp/protoc && cd /tmp/protoc \
	&& ln -s /usr/bin/build-go-project.sh /build-common.sh \
	&& true

COPY build-go-project.sh /usr/bin/build-go-project.sh
COPY turbobob-baseimage.json .golangci.yml /
