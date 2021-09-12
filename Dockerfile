FROM golang:1.17.1

WORKDIR /workspace

# zip for packaging Lambda functions

# /root/gohack (default checkout path) symlinked because it isn't visible outside the container.
# target not /workspace/vendor because that has special semantic meaning with go modules and doesn't work.

# deleting /go/pkg because Turbo Bob caching wouldn't replace /go/pkg (see turbobob-baseimage.json)
# with symlink to host if the tree already has content

RUN apt update && apt install -y zip \
	&& go get golang.org/x/tools/cmd/goimports \
	&& go get golang.org/x/tools/gopls@latest \
	&& go get github.com/cheekybits/genny \
	&& go get github.com/function61/deployer/cmd/deployer@latest \
	&& go get github.com/rogpeppe/gohack \
	&& ln -s /workspace/gohack /root/gohack \
	&& curl --fail --location -o /go/bin/depth https://github.com/KyleBanks/depth/releases/download/v1.2.1/depth_1.2.1_linux_amd64 \
	&& chmod +x /go/bin/depth \
	&& curl --fail --location https://github.com/golangci/golangci-lint/releases/download/v1.42.1/golangci-lint-1.42.1-linux-amd64.tar.gz \
		| tar --strip-components=1 -C /usr/local/bin -xzf - --wildcards 'golangci-lint-*-linux-amd64/golangci-lint' \
	&& rm -rf /go/pkg \
	&& mkdir /tmp/protoc && cd /tmp/protoc \
	&& wget https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protoc-3.17.3-linux-x86_64.zip \
	&& unzip protoc-3.17.3-linux-x86_64.zip && mv bin/protoc /usr/local/bin/ && cd / && rm -rf /tmp/protoc \
	&& go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
	&& true

ADD build-common.sh .golangci.yml /

ADD turbobob-baseimage.json /
