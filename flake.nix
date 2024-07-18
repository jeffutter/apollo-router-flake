{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      # self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        librusty_v8 = (
          let
            v8_version = "0.74.3";
            arch = pkgs.rust.toRustTarget pkgs.stdenv.hostPlatform;
          in
          pkgs.fetchurl {
            name = "librusty_v8-${v8_version}";
            url = "https://github.com/denoland/rusty_v8/releases/download/v${v8_version}/librusty_v8_release_${arch}.a";
            sha256 =
              {
                x86_64-linux = "";
                aarch64-darwin = "sha256-Djnuc3l/jQKvBf1aej8LG5Ot2wPT0m5Zo1B24l1UHsM=";
              }
              ."${system}";
            meta.version = v8_version;
          }
        );

        router =
          with pkgs;
          rustPlatform.buildRustPackage rec {
            pname = "router";
            version = "1.51.0";

            src = fetchFromGitHub {
              owner = "apollographql";
              repo = pname;
              rev = "v${version}";
              sha256 = "sha256-U2CL+RwCtDcRdK2DMpcqXEDJvOfYiYWT7IEqTO5ykNk=";
            };

            cargoHash = "sha256-TwVA17/fKmhV3/xmQUopqel5pQ6aF2ew9q90a/aky/o=";

            nativeBuildInputs = [
              cmake
              pkg-config
              protobuf
            ];

            buildInputs =
              [ ]
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [ elfutils ])
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin (
                with pkgs;
                with pkgs.darwin.apple_sdk.frameworks;
                [
                  Security
                  SystemConfiguration
                  libiconv
                ]
              );

            # The v8 package will try to download a `librusty_v8.a` release at build time to our read-only filesystem
            # To avoid this we pre-download the file and export it via RUSTY_V8_ARCHIVE
            # RUSTY_V8_ARCHIVE = callPackage ./librusty_v8.nix { };
            RUSTY_V8_ARCHIVE = "${librusty_v8}";

            cargoTestFlags = [ "-- --skip=uplink::test::stream_from_uplink_error_no_retry" ];

            meta = with lib; {
              description = "A configurable, high-performance routing runtime for Apollo Federation";
              homepage = "https://www.apollographql.com/docs/router/";
            };
          };
      in
      with pkgs;
      {
        packages = {
          default = router;
        };

        devShells.default = mkShell { packages = [ router ]; };

        formatter = nixpkgs-fmt;
      }
    );
}
