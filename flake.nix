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
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustVersion = "1.85.0";
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

        router =
          with pkgs;

          rustPlatform.buildRustPackage rec {
            pname = "router";
            version = "1.61.4";

            src = fetchFromGitHub {
              owner = "apollographql";
              repo = pname;
              rev = "v${version}";
              sha256 = "sha256-6jJR2JUcuJniOFyrOqLHhJa0bzk2eanDsmduYwRshrQ=";
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

            cargoTestFlags = [ "-- --skip=uplink::test::stream_from_uplink_error_no_retry" ];
            # Disable tests, it seems that tests were causing the build to hang with 100% cpu
            # This might be due to tests running in release mode by default in nix
            doCheck = false;

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
