FROM golang:1.13.1

# zip for packaging Lambda functions

RUN apt update && apt install -y zip \
	&& curl --fail --location -o /go/bin/dep https://github.com/golang/dep/releases/download/v0.5.4/dep-linux-amd64 \
	&& chmod +x /go/bin/dep \
	&& curl --fail --location -o /go/bin/deployer https://dl.bintray.com/function61/dl/deployer/20190517_1304_a4eaf786/deployer_linux-amd64 \
	&& chmod +x /go/bin/deployer \
	&& curl --fail --location -o /go/bin/depth https://github.com/KyleBanks/depth/releases/download/v1.2.1/depth_1.2.1_linux_amd64 \
	&& chmod +x /go/bin/depth \
	&& curl --fail --location https://github.com/alecthomas/gometalinter/releases/download/v2.0.11/gometalinter-2.0.11-linux-amd64.tar.gz | tar --strip-components=1 -C /usr/local/bin -xzf -

ADD build-common.sh /build-common.sh
