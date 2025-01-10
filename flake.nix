{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      # self,
      nixpkgs,
      flake-utils,
      rust-overlay,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # pkgs = import nixpkgs { inherit system; };
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        # Pin Rust 1.76 - https://github.com/apollographql/router/issues/5587
        rustVersion = "1.76.0";
        rust = pkgs.rust-bin.stable.${rustVersion}.default.override {
          extensions = [
            "rust-src" # for rust-analyzer
            "rust-analyzer"
          ];
        };
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rust;
          rustc = rust;
        };

        librusty_v8 = (
          let
            v8_version = "0.74.3";
            arch = pkgs.hostPlatform.rust.rustcTarget;
          in
          pkgs.fetchurl {
            name = "librusty_v8-${v8_version}";
            url = "https://github.com/denoland/rusty_v8/releases/download/v${v8_version}/librusty_v8_release_${arch}.a";
            sha256 =
              {
                x86_64-linux = "sha256-8pa8nqA6rbOSBVnp2Q8/IQqh/rfYQU57hMgwU9+iz4A=";
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
            version = "1.59.1";

            src = fetchFromGitHub {
              owner = "apollographql";
              repo = pname;
              rev = "v${version}";
              sha256 = "sha256-D+5ltc7JBy6q7rCfOPhrfw5/TWiq+r07MooedXzbazI=";
            };

            cargoLock = {
              lockFile = "${src}/Cargo.lock";
              outputHashes = {
                "hyper-0.14.31" = "sha256-Hj2EOvieeuZLzXET467C44dqnFeH22YYo//aTzDAepM=";
              };
            };

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
