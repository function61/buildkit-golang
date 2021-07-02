FROM golang:1.16.5

# zip for packaging Lambda functions

RUN apt update && apt install -y zip \
	&& go get golang.org/x/tools/cmd/goimports \
	&& go get golang.org/x/tools/gopls@latest \
	&& go get github.com/cheekybits/genny \
	&& curl --fail --location -o /go/bin/deployer https://dl.bintray.com/function61/dl/deployer/20200228_1738_94153e93/deployer_linux-amd64 \
	&& chmod +x /go/bin/deployer \
	&& curl --fail --location -o /go/bin/depth https://github.com/KyleBanks/depth/releases/download/v1.2.1/depth_1.2.1_linux_amd64 \
	&& chmod +x /go/bin/depth \
	&& curl --fail --location https://github.com/golangci/golangci-lint/releases/download/v1.41.1/golangci-lint-1.41.1-linux-amd64.tar.gz \
		| tar --strip-components=1 -C /usr/local/bin -xzf - --wildcards 'golangci-lint-*-linux-amd64/golangci-lint' \
	&& true

ADD build-common.sh .golangci.yml /

ADD turbobob-baseimage.json /
