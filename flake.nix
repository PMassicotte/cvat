{
  description = "nuctl CLI for deploying serverless models (SAM/SAM2/etc) into the local CVAT instance.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        nuctl = pkgs.stdenv.mkDerivation rec {
          pname = "nuctl";
          version = "1.16.3";

          src = pkgs.fetchurl {
            url = "https://github.com/nuclio/nuclio/releases/download/${version}/nuctl-${version}-linux-amd64";
            sha256 = "17zd2d1rz4n37rmwjg9flqzvpkj2a9llbg8l704h1x76wsaz17ai";
          };

          dontUnpack = true;
          nativeBuildInputs = [ pkgs.autoPatchelfHook ];

          installPhase = ''
            install -Dm755 $src $out/bin/nuctl
          '';

          meta = with pkgs.lib; {
            description = "CLI for the Nuclio serverless platform used by CVAT";
            homepage = "https://github.com/nuclio/nuclio";
            license = licenses.asl20;
            platforms = [ "x86_64-linux" ];
          };
        };
      in
      {
        packages.default = nuctl;
        packages.nuctl = nuctl;

        devShells.default = pkgs.mkShell {
          buildInputs = [ nuctl ];
        };
      }
    );
}
