FROM golang:1.10.0

RUN curl --fail --location -o /go/bin/dep https://github.com/golang/dep/releases/download/v0.4.1/dep-linux-amd64 \
	&& chmod +x /go/bin/dep \
	&& curl --fail --location -o /go/bin/depth https://github.com/KyleBanks/depth/releases/download/v1.2.1/depth_1.2.1_linux_amd64 \
	&& chmod +x /go/bin/depth \
	&& curl --location --fail -o /usr/local/bin/jfrog-cli "https://bintray.com/jfrog/jfrog-cli-go/download_file?file_path=1.12.1%2Fjfrog-cli-linux-amd64%2Fjfrog" \
	&& chmod +x /usr/local/bin/jfrog-cli \
	&& curl --location --fail -o /usr/local/bin/mc https://dl.minio.io/client/mc/release/linux-amd64/mc \
	&& chmod +x /usr/local/bin/mc
