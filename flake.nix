{
  description = "qmk environment";
  inputs = {
    nixpkgs.url = "nixpkgs/master";
    poetry2nix.url = "github:nix-community/poetry2nix";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, flake-compat }:
    {
      # Nixpkgs overlay providing the application
      overlays.qmk = nixpkgs.lib.composeManyExtensions [
        poetry2nix.overlay
        (final: prev: {
          # The application
          pythonEnv = prev.poetry2nix.mkPoetryEnv {
            projectDir = ./util/nix;
            overrides = prev.poetry2nix.overrides.withDefaults (self: super: {
              qmk = super.qmk.overridePythonAttrs (old: {
                # Allow QMK CLI to run "qmk" as a subprocess (the wrapper changes
                # $PATH and breaks these invocations).
                dontWrapPythonPrograms = true;
              });
            });
          };
        })
      ];
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.qmk ];
        };

        arm = true;
        teensy = true;
        avr = true;

        avrlibc = pkgs.pkgsCross.avr.libcCross;

        avr_incflags = [
          "-isystem ${avrlibc}/avr/include"
          "-B${avrlibc}/avr/lib/avr5"
          "-L${avrlibc}/avr/lib/avr5"
          "-B${avrlibc}/avr/lib/avr35"
          "-L${avrlibc}/avr/lib/avr35"
          "-B${avrlibc}/avr/lib/avr51"
          "-L${avrlibc}/avr/lib/avr51"
        ];
      in
      {
        devShells = {
          default = pkgs.mkShell {
            name = "qmk-firmware";

            buildInputs = with pkgs; [ clang-tools dfu-programmer dfu-util diffutils git pythonEnv poetry nixpkgs-fmt ]
            ++ lib.optional avr [
              pkgsCross.avr.buildPackages.binutils
              pkgsCross.avr.buildPackages.gcc8
              avrlibc
              avrdude
            ]
            ++ lib.optional arm [ gcc-arm-embedded ]
            ++ lib.optional teensy [ teensy-loader-cli ];

            AVR_CFLAGS = pkgs.lib.optional avr avr_incflags;
            AVR_ASFLAGS = pkgs.lib.optional avr avr_incflags;
            shellHook = ''
              # Prevent the avr-gcc wrapper from picking up host GCC flags
              # like -iframework, which is problematic on Darwin
              unset NIX_CFLAGS_COMPILE_FOR_TARGET
            '';
          };

          gcc12 = pkgs.mkShell {
            name = "qmk-firmware-gcc12";

            buildInputs = with pkgs; [ clang-tools dfu-programmer dfu-util diffutils git pythonEnv poetry nixpkgs-fmt ]
            ++ lib.optional avr [
              pkgsCross.avr.buildPackages.binutils
              pkgsCross.avr.buildPackages.gcc12
              avrlibc
              avrdude
            ]
            ++ lib.optional arm [ gcc-arm-embedded ]
            ++ lib.optional teensy [ teensy-loader-cli ];

            AVR_CFLAGS = pkgs.lib.optional avr avr_incflags;
            AVR_ASFLAGS = pkgs.lib.optional avr avr_incflags;
            shellHook = ''
              # Prevent the avr-gcc wrapper from picking up host GCC flags
              # like -iframework, which is problematic on Darwin
              unset NIX_CFLAGS_COMPILE_FOR_TARGET
            '';
          };
        };

      });

}
# let
#   # We specify sources via Niv: use "niv update nixpkgs" to update nixpkgs, for example.
#   sources = import ./util/nix/sources.nix { };
# in
# # However, if you want to override Niv's inputs, this will let you do that.
# { pkgs ? import sources.nixpkgs { }
# , poetry2nix ? pkgs.callPackage (import sources.poetry2nix) { }
# , avr ? true
# , arm ? true
# , teensy ? true }:
# with pkgs;
# let
#   avrlibc = pkgsCross.avr.libcCross;

#   avr_incflags = [
#     "-isystem ${avrlibc}/avr/include"
#     "-B${avrlibc}/avr/lib/avr5"
#     "-L${avrlibc}/avr/lib/avr5"
#     "-B${avrlibc}/avr/lib/avr35"
#     "-L${avrlibc}/avr/lib/avr35"
#     "-B${avrlibc}/avr/lib/avr51"
#     "-L${avrlibc}/avr/lib/avr51"
#   ];

#   # Builds the python env based on nix/pyproject.toml and
#   # nix/poetry.lock Use the "poetry update --lock", "poetry add
#   # --lock" etc. in the nix folder to adjust the contents of those
#   # files if the requirements*.txt files change
#   pythonEnv = poetry2nix.mkPoetryEnv {
#     projectDir = ./util/nix;
#     overrides = poetry2nix.overrides.withDefaults (self: super: {
#       qmk = super.qmk.overridePythonAttrs(old: {
#         # Allow QMK CLI to run "qmk" as a subprocess (the wrapper changes
#         # $PATH and breaks these invocations).
#         dontWrapPythonPrograms = true;
#       });
#     });
#   };
# in
# mkShell {
#   name = "qmk-firmware";

#   buildInputs = [ clang-tools dfu-programmer dfu-util diffutils git pythonEnv poetry niv ]
#     ++ lib.optional avr [
#       pkgsCross.avr.buildPackages.binutils
#       pkgsCross.avr.buildPackages.gcc8
#       avrlibc
#       avrdude
#     ]
#     ++ lib.optional arm [ gcc-arm-embedded ]
#     ++ lib.optional teensy [ teensy-loader-cli ];

#   AVR_CFLAGS = lib.optional avr avr_incflags;
#   AVR_ASFLAGS = lib.optional avr avr_incflags;
#   shellHook = ''
#     # Prevent the avr-gcc wrapper from picking up host GCC flags
#     # like -iframework, which is problematic on Darwin
#     unset NIX_CFLAGS_COMPILE_FOR_TARGET
#   '';
# }
