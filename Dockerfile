FROM golang:1.14.4

# zip for packaging Lambda functions

RUN apt update && apt install -y zip \
	&& go get golang.org/x/tools/cmd/goimports \
	&& curl --fail --location -o /go/bin/deployer https://dl.bintray.com/function61/dl/deployer/20200228_1738_94153e93/deployer_linux-amd64 \
	&& chmod +x /go/bin/deployer \
	&& curl --fail --location -o /go/bin/depth https://github.com/KyleBanks/depth/releases/download/v1.2.1/depth_1.2.1_linux_amd64 \
	&& chmod +x /go/bin/depth \
	&& curl --fail --location https://github.com/golangci/golangci-lint/releases/download/v1.24.0/golangci-lint-1.24.0-linux-amd64.tar.gz | tar --strip-components=1 -C /usr/local/bin -xzf - golangci-lint-1.24.0-linux-amd64/golangci-lint

ADD build-common.sh .golangci.yml /
