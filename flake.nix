{
  description = "Android package reverse engineering environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      treefmt-nix,
      ...
    }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (
        pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );
    in
    {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [
            self.formatter.${pkgs.stdenv.hostPlatform.system}

            # --- APK disassembly & manipulation ---
            pkgs.apktool # Decode/rebuild APKs (resources, smali)
            pkgs.apkeditor # APK resource editor
            pkgs.apksigner # Sign and verify APKs
            pkgs.apksigcopier # Copy/extract/patch APK signatures
            pkgs.apkid # Android application identifier (compiler/packer/obfuscator detection)
            pkgs.aapt # Android Asset Packaging Tool
            pkgs.bundletool # Manipulate Android App Bundles (.aab)

            # --- Java/DEX decompilation ---
            pkgs.jadx # Dex-to-Java decompiler (CLI + GUI)
            pkgs.dex2jar # Convert DEX to JAR for Java decompilers
            pkgs.bytecode-viewer # Multi-decompiler bytecode viewer (GUI)

            # --- Native binary reverse engineering ---
            pkgs.ghidra # NSA's SRE suite (disassembler + decompiler)
            pkgs.radare2 # UNIX-like RE framework and CLI toolset
            pkgs.rizin # Modern fork of radare2
            pkgs.binwalk # Firmware/binary analysis and extraction

            # --- Dynamic instrumentation ---
            pkgs.frida-tools # Frida CLI tools (frida, frida-ps, frida-trace, etc.)
            pkgs.jnitrace # Frida-based JNI API tracer for Android apps

            # --- Static analysis & security scanning ---
            pkgs.trueseeing # Non-decompiling Android vulnerability scanner
            pkgs.quark-engine # Android malware analysis and scoring
            pkgs.yara # Pattern matching for malware research
            pkgs.koodousfinder # Search and analyze Android apps

            # --- Network interception ---
            pkgs.mitmproxy # HTTPS man-in-the-middle proxy
            pkgs.wireshark-cli # Network protocol analyzer (tshark)

            # --- ADB & device interaction ---
            pkgs.android-tools # ADB + fastboot
            pkgs.scrcpy # Display/control Android devices over USB/TCP

            # --- Android image & OTA tools ---
            pkgs.simg2img # Sparse image to raw image converter
            pkgs.sdat2img # .dat sparse data to ext4 image converter
            pkgs.payload-dumper-go # Extract partitions from Android OTA payloads
            pkgs.imgpatchtools # Manipulate Android OTA archives

            # --- General-purpose utilities ---
            pkgs.unzip # ZIP extraction
            pkgs.p7zip # 7-Zip archive tool
            pkgs.file # File type identification
            pkgs.jq # JSON processor
            pkgs.sqlite # SQLite CLI (inspect app databases)
            pkgs.openssl # Certificate and crypto utilities

            # --- Python environment for scripting ---
            (pkgs.python3.withPackages (ps: [
              ps.frida-python # Frida Python bindings
              ps.yara-python # YARA Python bindings
              ps.pyaxmlparser # Parse Android XML (AndroidManifest) without full androguard
              ps.ipython # Interactive Python shell
            ]))
          ];

          env = {
            # Ensure Ghidra can find a JDK
            GHIDRA_JAVA_HOME = "${pkgs.jdk}/lib/openjdk";
          };

          shellHook = ''
            echo "Android RE environment loaded. See CLAUDE.md for tool documentation."
          '';
        };
      });

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });
    };
}
