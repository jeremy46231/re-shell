# Android Reverse Engineering Environment

Nix flake-based development shell providing a comprehensive toolkit for Android APK and native binary reverse engineering. Enter the environment with `nix develop` or via direnv.

## Output Directory Convention

All reverse engineering work products must go in one of two locations:

- **`tmp/`** -- Intermediate and throwaway side products: decompiled source, disassembly output, extracted APK contents, unpacked resources, Ghidra projects, scratch scripts, etc. This directory is in `.gitignore` and will not be committed. Create subdirectories freely (e.g., `tmp/jadx_com.example.app/`, `tmp/extracted/`).
- **`artifacts/<package.namespace>/`** -- Final, requested deliverables: analysis reports, annotated code snippets, Frida hook scripts, YARA rules, patch files, or anything the user explicitly asks to keep. Use the app's package namespace (e.g., `com.example.app`) as the subdirectory name. This directory is tracked by git.

When running tools, always direct output into `tmp/` rather than the repo root. Examples:

```sh
jadx -d tmp/jadx_com.example.app/ com.example.app.apk
apktool d com.example.app.apk -o tmp/apktool_com.example.app/
unzip com.example.app.apk -d tmp/extracted_com.example.app/
```

Never leave tool output in the repo root or in ad-hoc directories outside these two locations.

## Environment Structure

The dev shell is defined in `flake.nix` and organized into tool categories. A bundled Python 3 environment provides scripting libraries (Frida, YARA, pyaxmlparser, IPython). Ghidra's JDK is configured via `GHIDRA_JAVA_HOME`.

## Installed Tools

### APK Disassembly & Manipulation

| Tool | Command | Description |
|------|---------|-------------|
| apktool | `apktool d app.apk` | Decode APKs to smali + resources; rebuild with `apktool b` |
| apkeditor | `apkeditor` | Edit APK resources directly |
| apksigner | `apksigner sign --ks key.jks app.apk` | Sign and verify APK signatures (Android SDK) |
| apksigcopier | `apksigcopier` | Copy, extract, or patch APK signature blocks between files |
| APKiD | `apkid app.apk` | Identify compilers, packers, and obfuscators used to build an APK |
| aapt | `aapt dump badging app.apk` | Inspect APK metadata, resources, and manifest |
| bundletool | `bundletool build-apks --bundle=app.aab --output=out.apks` | Convert Android App Bundles (.aab) to APK sets |

### Java/DEX Decompilation

| Tool | Command | Description |
|------|---------|-------------|
| jadx | `jadx -d output/ app.apk` | Decompile DEX/APK directly to Java source (also has GUI: `jadx-gui`) |
| dex2jar | `d2j-dex2jar app.apk` | Convert DEX bytecode to a standard JAR for use with Java decompilers |
| bytecode-viewer | `bytecode-viewer` | GUI combining multiple decompilers (Procyon, CFR, FernFlower, etc.) |

### Native Binary Reverse Engineering

| Tool | Command | Description |
|------|---------|-------------|
| Ghidra | `ghidra` | NSA's software reverse engineering suite with decompiler; supports ARM/ARM64 ELF (`.so` libraries) |
| radare2 | `r2 libexample.so` | CLI-first RE framework for disassembly, analysis, patching, and debugging |
| rizin | `rizin libexample.so` | Modern radare2 fork with improved APIs and Ghidra decompiler integration via rz-ghidra |
| binwalk | `binwalk firmware.bin` | Scan and extract embedded files, compressed streams, and filesystems from binaries |

### Dynamic Instrumentation

| Tool | Command | Description |
|------|---------|-------------|
| frida-tools | `frida -U -f com.app.pkg -l script.js` | Inject JavaScript into running Android processes for runtime hooking |
| frida-tools | `frida-ps -U` | List processes on a USB-connected device |
| frida-tools | `frida-trace -U -f com.app.pkg -i "open*"` | Auto-generate handler stubs for traced functions |
| jnitrace | `jnitrace -l libnative.so com.app.pkg` | Trace all JNI API calls made by a native library at runtime |

### Static Analysis & Security Scanning

| Tool | Command | Description |
|------|---------|-------------|
| trueseeing | `trueseeing app.apk` | Scan APKs for vulnerabilities without decompilation |
| quark-engine | `quark -a app.apk -s` | Score and analyze APKs for malware behaviors |
| YARA | `yara rules.yar target/` | Match file patterns using YARA rules for malware identification |
| koodousfinder | `koodousfinder` | Search for and analyze Android applications |

### Network Interception

| Tool | Command | Description |
|------|---------|-------------|
| mitmproxy | `mitmproxy` / `mitmweb` / `mitmdump` | Intercept, inspect, and modify HTTPS traffic from Android apps |
| tshark | `tshark -i any -f "host 10.0.0.1"` | Capture and analyze network packets (Wireshark CLI) |

### ADB & Device Interaction

| Tool | Command | Description |
|------|---------|-------------|
| adb | `adb devices` / `adb shell` / `adb pull` | Android Debug Bridge for device communication |
| fastboot | `fastboot flash` | Flash device partitions |
| scrcpy | `scrcpy` | Mirror and control an Android device screen over USB or TCP/IP |

### Android Image & OTA Tools

| Tool | Command | Description |
|------|---------|-------------|
| simg2img | `simg2img system.img system.raw.img` | Convert Android sparse images to raw ext4 images |
| sdat2img | `sdat2img system.transfer.list system.new.dat system.img` | Convert `.dat` sparse data files to ext4 images |
| payload-dumper-go | `payload-dumper-go payload.bin` | Extract partition images from `payload.bin` in Android OTA updates |
| imgpatchtools | `imgpatchtools` | Apply and manipulate Android OTA incremental patches |

### Python Scripting Environment

A Python 3 interpreter is included with these libraries pre-installed:

| Library | Import | Description |
|---------|--------|-------------|
| frida | `import frida` | Python API for Frida dynamic instrumentation |
| yara-python | `import yara` | Compile and apply YARA rules from Python |
| pyaxmlparser | `import pyaxmlparser` | Parse AndroidManifest.xml and extract app metadata |
| IPython | `ipython` | Enhanced interactive Python shell for exploratory analysis |

### General Utilities

`unzip`, `7z` (p7zip), `file`, `jq`, `sqlite3`, `openssl` -- standard tools for archive extraction, file identification, JSON processing, database inspection, and certificate handling.

| Tool | Command | Description |
|------|---------|-------------|
| uv | `uv pip install <pkg> --python $(which python3)` | Fast Python package installer for ad-hoc dependencies outside the Nix environment |

## Common Workflows

### Full APK static analysis

```sh
# Identify build toolchain and protections
apkid app.apk

# Decode to smali + resources
apktool d app.apk -o app_decoded/

# Decompile to Java source
jadx -d app_src/ app.apk

# Scan for vulnerabilities
trueseeing app.apk

# Check for malware behaviors
quark -a app.apk -s
```

### Native library analysis

```sh
# Extract the APK
unzip app.apk -d app_contents/

# Analyze ARM .so with Ghidra
ghidra  # import app_contents/lib/arm64-v8a/libnative.so

# Or use radare2/rizin for quick CLI analysis
r2 -A app_contents/lib/arm64-v8a/libnative.so
```

### Runtime hooking with Frida

```sh
# List running processes
frida-ps -U

# Attach and trace
frida -U -f com.target.app -l hook.js --no-pause

# Trace JNI calls
jnitrace -l libnative.so com.target.app
```

### Network traffic interception

```sh
# Start mitmproxy, configure device to use proxy
mitmproxy --listen-port 8080

# Or capture raw packets
tshark -i any -w capture.pcap
```

### Extract OTA / system images

```sh
# From a payload.bin OTA
payload-dumper-go payload.bin

# Convert sparse to raw
simg2img system.img system.raw.img

# Mount and inspect
mkdir mnt && sudo mount -o loop system.raw.img mnt/
```

### Ad-hoc Python packages with uv

Use `uv` to quickly install Python packages that aren't part of the Nix-managed Python environment. This is useful for one-off scripts or exploratory analysis where you need a library not bundled in the dev shell.

```sh
# Install a package into the Nix Python environment
uv pip install protobuf --python $(which python3)

# Run a one-off script with a dependency not in the environment
uv run --python $(which python3) --with cryptography script.py

# Start a REPL with extra packages available
uv run --python $(which python3) --with pycryptodome ipython
```

The `--python $(which python3)` flag ensures uv uses the Nix-provided Python interpreter so installed packages are compatible with the rest of the environment. Packages installed this way are ephemeral and will not persist across shell restarts. For packages you need regularly, add them permanently to `flake.nix` instead (see below).

## Augmenting the Environment

When a task calls for a tool or library not currently in the dev shell, you have two options:

### Temporary: ad-hoc install with uv (Python packages only)

See the [uv workflow above](#ad-hoc-python-packages-with-uv). Good for one-off exploration.

### Permanent: add to flake.nix

For tools or libraries you'll need repeatedly, add them directly to `flake.nix`:

1. **Search nixpkgs** for the package using the `/nix-package-search` skill (e.g., `/nix-package-search protobuf`).
2. **Edit `flake.nix`** to add the package to the appropriate section:
   - Nix packages go in the `packages` list (e.g., `pkgs.protobuf`).
   - Python libraries go inside the `python3.withPackages` call (e.g., `ps.protobuf`).
3. **Reload the environment** by running `direnv reload` (or exiting and re-entering `nix develop`).
4. **Update `CLAUDE.md`** to document the new tool in the matching table section so the documentation stays in sync with the flake.

You are encouraged to self-modify `flake.nix` and this file whenever the analysis requires a tool that should be part of the standard environment. Keep the existing organizational structure (category comments, table format) when adding entries.

## Notes

- `androguard` is excluded from the environment because its `dataset` dependency is currently marked broken in nixpkgs. `pyaxmlparser` is included as a lightweight alternative for Android XML parsing. Re-add androguard when the upstream issue is resolved.
- Ghidra requires a display server for its GUI. On headless/WSL systems, use an X server (e.g., VcXsrv) or Ghidra's headless analyzer: `analyzeHeadless`.
- Frida requires a `frida-server` binary running on the target Android device (matching the frida-tools version).
- mitmproxy certificate must be installed on the target device for HTTPS interception. Push it via: `adb push ~/.mitmproxy/mitmproxy-ca-cert.cer /sdcard/`.
