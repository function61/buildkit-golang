{
  description = "Proof-of-concept Go build container";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      tools = pkgs.buildEnv {
        name = "buildkit-golang-tools";
        paths = with pkgs; [
          bashInteractive
          coreutils
          findutils
          gnugrep
          gnused
          gnutar
          gzip
          curl
          git
          openssh # Git access to repositories over SSH, including private Go modules.
          cacert
          zip
          unzip
          getopt # Parses build-go-project.sh command-line options.
          procps # Provides process inspection tools, including ps.
          go
          delve
          gotools # goimports and other Go development tools, including stringer and deadcode.
          gopls
          govulncheck
          golangci-lint
        ];
        pathsToLink = [ "/bin" "/etc" "/share" ];
      };
      root = pkgs.runCommand "buildkit-golang-root" { } ''
        mkdir -p $out/bin $out/usr/bin $out/root $out/workspace $out/tmp
        chmod 1777 $out/tmp
        ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/bash
        ln -s ${pkgs.coreutils}/bin/env $out/usr/bin/env
        install -m 755 ${./build-go-project.sh} $out/usr/bin/build-go-project.sh
        ln -s /usr/bin/build-go-project.sh $out/build-common.sh
        ln -s /workspace/gohack $out/root/gohack
        cp ${./turbobob-baseimage.json} $out/turbobob-baseimage.json
        cp ${./.golangci.yml} $out/.golangci.yml
        printf '[safe]\n\tdirectory = /workspace\n' > $out/root/.gitconfig
      '';
    in {
      packages.${system}.default = pkgs.dockerTools.buildLayeredImage {
        name = "buildkit-golang-nix-poc";
        tag = "latest";
        contents = [ tools root ];
        config = {
          WorkingDir = "/workspace";
          Env = [
            "PATH=/bin:/usr/bin"
            "HOME=/root"
            "GOPATH=/go"
            "CGO_ENABLED=0"
            "GOTOOLCHAIN=local"
            "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
          ];
          Cmd = [ "/bin/bash" ];
        };
      };
    };
}
