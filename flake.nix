{
  description = "Reverse engineering environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      treefmt-nix,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      eachSystem =
        f:
        lib.genAttrs (import systems) (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "volatility3" # License listed as 'unknown' in nixpkgs
                ];
            }
          )
        );

      treefmtEval = eachSystem (
        pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );

      # Load the uv workspace from pyproject.toml + uv.lock
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      # Build a package overlay from the workspace lockfile
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
    in
    {
      devShells = eachSystem (
        pkgs:
        let
          python = pkgs.python3;

          # Build Node.js dependencies from package-lock.json
          nodeModules = pkgs.importNpmLock.buildNodeModules {
            npmRoot = self;
            inherit (pkgs) nodejs;
          };

          # Construct the Python package set from workspace + overlays
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                  # Add dependency fixups here as needed, e.g.:
                  # (_final: prev: {
                  #   some-package = prev.some-package.overrideAttrs (old: {
                  #     buildInputs = (old.buildInputs or []) ++ [ pkgs.some-lib ];
                  #   });
                  # })
                ]
              );

          # Build the virtualenv from workspace dependencies
          venv = pythonSet.mkVirtualEnv "re-env" workspace.deps.default;
        in
        {
          default = pkgs.mkShell {
            packages = [
              self.formatter.${pkgs.stdenv.hostPlatform.system}
              venv
              pkgs.uv
              pkgs.nodejs
              pkgs.importNpmLock.hooks.linkNodeModulesHook

              # --- General: native binary reverse engineering ---
              pkgs.ghidra # NSA's SRE suite (disassembler + decompiler)
              pkgs.radare2 # UNIX-like RE framework and CLI toolset
              pkgs.rizin # Modern fork of radare2
              pkgs.binwalk # Firmware/binary analysis and extraction

              # --- General: dynamic instrumentation ---
              pkgs.frida-tools # Frida CLI tools (frida, frida-ps, frida-trace, etc.)

              # --- General: static analysis ---
              pkgs.yara # Pattern matching for malware research

              # --- General: network interception ---
              pkgs.mitmproxy # HTTPS man-in-the-middle proxy
              pkgs.wireshark-cli # Network protocol analyzer (tshark)

              # --- General: utilities ---
              pkgs.unzip # ZIP extraction
              pkgs.p7zip # 7-Zip archive tool
              pkgs.file # File type identification
              pkgs.jq # JSON processor
              pkgs.sqlite # SQLite CLI (inspect app databases)
              pkgs.openssl # Certificate and crypto utilities
              pkgs.upx # Universal executable packer/unpacker

              # --- Android: APK disassembly & manipulation ---
              pkgs.apktool # Decode/rebuild APKs (resources, smali)
              pkgs.apkeditor # APK resource editor
              pkgs.apksigner # Sign and verify APKs
              pkgs.apksigcopier # Copy/extract/patch APK signatures
              pkgs.apkid # Android application identifier (compiler/packer/obfuscator detection)
              pkgs.aapt # Android Asset Packaging Tool
              pkgs.bundletool # Manipulate Android App Bundles (.aab)

              # --- Android: Java/DEX decompilation ---
              pkgs.jadx # Dex-to-Java decompiler (CLI + GUI)
              pkgs.dex2jar # Convert DEX to JAR for Java decompilers
              pkgs.bytecode-viewer # Multi-decompiler bytecode viewer (GUI)

              # --- Android: dynamic instrumentation ---
              pkgs.jnitrace # Frida-based JNI API tracer for Android apps

              # --- Android: static analysis & security scanning ---
              pkgs.trueseeing # Non-decompiling Android vulnerability scanner
              pkgs.quark-engine # Android malware analysis and scoring
              pkgs.koodousfinder # Search and analyze Android apps

              # --- Android: ADB & device interaction ---
              pkgs.android-tools # ADB + fastboot
              pkgs.scrcpy # Display/control Android devices over USB/TCP

              # --- Android: image & OTA tools ---
              pkgs.simg2img # Sparse image to raw image converter
              pkgs.sdat2img # .dat sparse data to ext4 image converter
              pkgs.payload-dumper-go # Extract partitions from Android OTA payloads
              pkgs.imgpatchtools # Manipulate Android OTA archives

              # --- Windows: PE analysis & inspection ---
              pkgs.pe-bear # GUI PE viewer for headers, sections, imports, exports
              pkgs.detect-it-easy # Identify compilers, packers, protectors (diec)
              pkgs.imhex # Hex editor with pattern language and PE templates

              # --- Windows: .NET decompilation ---
              pkgs.ilspycmd # Decompile .NET assemblies to C# (CLI)
              pkgs.avalonia-ilspy # Cross-platform GUI .NET decompiler

              # --- Windows: string & capability analysis ---
              pkgs.flare-floss # Extract obfuscated/stack/decoded strings from malware

              # --- Windows: memory forensics ---
              pkgs.volatility3 # Analyze Windows memory dumps

              # --- Windows: archive & installer extraction ---
              pkgs.cabextract # Extract Microsoft Cabinet (.cab) archives
              pkgs.innoextract # Extract files from Inno Setup installers

              # --- Windows: signing & verification ---
              pkgs.osslsigncode # Verify/manipulate Authenticode signatures on PE files
            ];

            npmDeps = nodeModules;

            env = {
              # Ensure Ghidra can find a JDK
              GHIDRA_JAVA_HOME = "${pkgs.jdk}/lib/openjdk";

              # Don't let uv create/sync its own venv -- Nix manages it
              UV_NO_SYNC = "1";

              # Force uv to use the Nix-built Python
              UV_PYTHON = "${venv}/bin/python";

              # Prevent uv from downloading its own Python
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              unset PYTHONPATH
              if [ -d "$npmDeps/node_modules" ]; then
                linkNodeModulesHook
              fi
              echo "Android RE environment loaded. See CLAUDE.md for tool documentation."
            '';
          };
        }
      );

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });
    };
}
