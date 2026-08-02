# Reverse Engineering Environment

Multi-discipline Nix flake-based development shell for reverse engineering. Enter the environment with `nix develop` or via direnv.

## Skill System

This environment is organized into a **general-purpose core** (this file) and **discipline-specific skills** that auto-activate based on context. Skills provide specialized tool documentation, workflows, and notes for their domain.

### Available Disciplines

| Skill | Path | Activates On |
|-------|------|-------------|
| Android RE | `.claude/skills/android/SKILL.md` | APK, DEX, smali, ADB, Android app analysis |
| Windows RE | `.claude/skills/windows/SKILL.md` | PE, .exe, .dll, .sys, .NET, Windows binary analysis |
| Web RE | `.claude/skills/web/SKILL.md` | Protobuf, gRPC, HAR, HTTP API, WebSocket, TLS fingerprint, web scraping |

### Adding a New Discipline

1. Create `.claude/skills/<discipline>/SKILL.md` with front matter (`name`, `user-invocable: false`, `description` with trigger keywords).
2. Add discipline-specific tools to `flake.nix` under a `# --- <Discipline>:` comment section.
3. Add discipline-specific Python/Node dependencies to `pyproject.toml`/`package.json`.
4. Document the skill in the table above.
5. Tools shared across disciplines stay in the general sections of `flake.nix` and this file.

## Output Directory Convention

All reverse engineering work products must go in one of two locations:

- **`tmp/`** -- Intermediate and throwaway side products: decompiled source, disassembly output, extracted contents, unpacked resources, Ghidra projects, scratch scripts, etc. This directory is in `.gitignore` and will not be committed. Create subdirectories freely (e.g., `tmp/ghidra_project/`, `tmp/extracted_sample/`).
- **`artifacts/<identifier>/`** -- Final, requested deliverables: analysis reports, annotated code snippets, hook scripts, YARA rules, patch files, or anything the user explicitly asks to keep. Use a meaningful identifier as the subdirectory name (e.g., package namespace `com.example.app`, sample hash, malware family name). This directory is tracked by git.

When running tools, always direct output into `tmp/` rather than the repo root. Examples:

```sh
ghidra  # save project to tmp/ghidra_<sample>/
r2 -A sample.bin  # any output files go to tmp/
binwalk -e firmware.bin -C tmp/binwalk_firmware/
```

Never leave tool output in the repo root or in ad-hoc directories outside these two locations.

## Environment Structure

The dev shell is defined in `flake.nix` and organized into tool categories. Python dependencies are declared in `pyproject.toml`, locked by `uv.lock`, and built into a Nix virtualenv via [uv2nix](https://github.com/pyproject-nix/uv2nix). Node.js dependencies are declared in `package.json`, locked by `package-lock.json`, and built via `importNpmLock`; bin scripts from npm packages are automatically on PATH. Ghidra's JDK is configured via `GHIDRA_JAVA_HOME`.

## Installed Tools (General-Purpose)

Discipline-specific tools are documented in their respective skill files. The tools below are available across all RE disciplines.

### Native Binary Reverse Engineering

| Tool | Command | Description |
|------|---------|-------------|
| Ghidra | `ghidra` | NSA's software reverse engineering suite with decompiler; supports x86, x64, ARM, ARM64, MIPS, and more |
| radare2 | `r2 binary` | CLI-first RE framework for disassembly, analysis, patching, and debugging |
| rizin | `rizin binary` | Modern radare2 fork with improved APIs and Ghidra decompiler integration via rz-ghidra |
| binwalk | `binwalk firmware.bin` | Scan and extract embedded files, compressed streams, and filesystems from binaries |

### Dynamic Instrumentation

| Tool | Command | Description |
|------|---------|-------------|
| frida-tools | `frida -p <pid> -l script.js` | Inject JavaScript into running processes for runtime hooking |
| frida-tools | `frida-ps` | List running processes (add `-U` for USB device, `-R` for remote) |
| frida-tools | `frida-trace -p <pid> -i "open*"` | Auto-generate handler stubs for traced functions |

### Static Analysis

| Tool | Command | Description |
|------|---------|-------------|
| YARA | `yara rules.yar target/` | Match file patterns using YARA rules for malware identification |

### USB

| Tool | Command | Description |
|------|---------|-------------|
| usbutils | `lsusb -v -d 2e1a:` | Dump USB descriptors (configs, interfaces, endpoints) |

Raw USB from Python uses `pyusb` over the libusb-1.0 backend. `ctypes.util.find_library`
finds nothing on NixOS, so the dev shell exports `LIBUSB1_SO`; pass it explicitly:

```python
import os, usb.core, usb.backend.libusb1 as lb
be = lb.get_backend(find_library=lambda _: os.environ["LIBUSB1_SO"])
dev = usb.core.find(idVendor=0x1234, idProduct=0x5678, backend=be)
```

Control and bulk transfers need write access to `/dev/bus/usb/*`: run as root, or add a
udev rule for the target VID:PID. Note that a vendor device often changes VID:PID when it
switches USB modes, so match on all of the identities it can present.

### Password / Hash Cracking

Wordlists and rules are exposed as a stable dir-of-symlinks at `wordlists/` in the repo root (gitignored, points into the Nix store) so no `/nix/store` spelunking is needed. Contents: `wordlists/rockyou.txt`, `wordlists/seclists/` (full SecLists tree), `wordlists/best64.rule`, `wordlists/hashcat-rules/`, `wordlists/john-rules/`, `wordlists/john-password.lst`. To add more, edit the `wordlists` linkFarm in `flake.nix`.

| Tool | Command | Description |
|------|---------|-------------|
| hashcat | `hashcat -m 0 -a 0 hash.txt wordlists/rockyou.txt -r wordlists/best64.rule` | GPU/CPU password recovery |
| john | `john --wordlist=wordlists/rockyou.txt hash.txt` | John the Ripper (Jumbo); also bundles `*2john` converters (e.g. `zip2john`) |

### Embedded / RP2040-RP2350 (Pico) Firmware

| Tool | Command | Description |
|------|---------|-------------|
| picotool | `picotool info -a firmware.uf2` | Inspect/convert RP2 UF2 firmware, read binary info and chip details |
| pico-sdk | (via `PICO_SDK_PATH`) | Raspberry Pi Pico SDK; `PICO_SDK_PATH` is set automatically in the dev shell |
| cmake | `cmake -B build` | Build system for pico-sdk projects |
| gcc-arm-embedded | `arm-none-eabi-gcc` | ARM cross toolchain (`arm-none-eabi-{gcc,objcopy,gdb,...}`) |

### Network Interception

| Tool | Command | Description |
|------|---------|-------------|
| mitmproxy | `mitmproxy` / `mitmweb` / `mitmdump` | Intercept, inspect, and modify HTTPS traffic |
| tshark | `tshark -i any -f "host 10.0.0.1"` | Capture and analyze network packets (Wireshark CLI) |

### General Utilities

`unzip`, `7z` (p7zip), `file`, `jq`, `sqlite3`, `openssl` -- standard tools for archive extraction, file identification, JSON processing, database inspection, and certificate handling.

| Tool | Command | Description |
|------|---------|-------------|
| UPX | `upx -d packed.exe` | Decompress executables packed with UPX |
| xxd | `xxd binary` | Hex dump / reverse hex dump utility |
| exiftool | `exiftool file` | Read/write embedded metadata (images, documents, firmware) |
| uv | `uv add <pkg>` | Python package manager; add dependencies to pyproject.toml and uv.lock, then `direnv reload` to rebuild |
| npm | `npm install <pkg>` | Node.js package manager; add dependencies to package.json and package-lock.json, then `direnv reload` to rebuild |

### Python Scripting Environment

Python dependencies are managed via `pyproject.toml` and `uv.lock`, built into a Nix virtualenv by uv2nix. The following general-purpose libraries are pre-installed:

| Library | Import | Description |
|---------|--------|-------------|
| frida | `import frida` | Python API for Frida dynamic instrumentation |
| pyghidra | `import pyghidra` | Python API for Ghidra; run headless analysis, access the decompiler, and script Ghidra entirely from Python via JPype |
| yara-python | `import yara` | Compile and apply YARA rules from Python |
| IPython | `ipython` | Enhanced interactive Python shell for exploratory analysis |
| NumPy | `import numpy` | Array/numeric computing (byte-array math, entropy, correlation) |
| SciPy | `import scipy` | Scientific computing (FFT, signal processing, optimization) |
| Pillow | `from PIL import Image` | Image loading/manipulation (extracted textures, QR, framebuffers) |
| pyusb | `import usb.core` | Raw USB control/bulk/interrupt transfers (see [USB](#usb) for the libusb backend) |

Discipline-specific Python libraries are listed in their respective skill files. To add a Python package permanently, run `uv add <package>` then `direnv reload`. See [Augmenting the Environment](#augmenting-the-environment).

### Node.js Scripting Environment

Node.js dependencies are managed via `package.json` and `package-lock.json`, built into a Nix-managed `node_modules` by `importNpmLock`. Bin scripts from installed packages are automatically available on PATH via `linkNodeModulesHook`.

Discipline-specific Node.js tools are listed in their respective skill files. To add a Node.js package permanently, run `npm install <package>` then `direnv reload`. See [Augmenting the Environment](#augmenting-the-environment). Note that npm packages with native install scripts that download binaries (e.g., the `frida` npm package) will fail in the Nix sandbox -- use nixpkgs equivalents for those.

## Common Workflows

### Binary analysis with Ghidra

```sh
# GUI (requires display server on headless/WSL)
ghidra  # import binary, save project to tmp/

# Headless analysis
ghidra-analyzeHeadless tmp/ghidra_project ProjectName -import binary -postScript script.java
```

### Scripted Ghidra analysis with pyghidra

`pyghidra.start()` requires `GHIDRA_INSTALL_DIR` to point at the Ghidra install. The dev shell sets this automatically (along with `GHIDRA_JAVA_HOME`), so `import pyghidra; pyghidra.start()` works directly -- no manual `export GHIDRA_INSTALL_DIR=...` prefix needed.

```python
import pyghidra

# Start the Ghidra JVM (once per session)
pyghidra.start()

# Open a binary, auto-analyze, and access the Flat API
with pyghidra.open_program("binary", project_location="tmp/ghidra_project") as flat_api:
    program = flat_api.getCurrentProgram()
    listing = program.getListing()
    # iterate functions, read decompiled code, etc.

# Or run a Ghidra script (.java/.py) against a binary
pyghidra.run_script("binary", "script.java", project_location="tmp/ghidra_project")
```

### Quick CLI disassembly

```sh
# radare2
r2 -A binary
# rizin
rizin -A binary
```

### Network traffic interception

```sh
# Start mitmproxy, configure target to use proxy
mitmproxy --listen-port 8080

# Or capture raw packets
tshark -i any -w tmp/capture.pcap
```

### Adding Python packages with uv

Python dependencies are managed through `pyproject.toml` and built natively by Nix via uv2nix. To add a package:

```sh
# Add a dependency (updates pyproject.toml and uv.lock)
uv add protobuf

# Rebuild the Nix environment with the new dependency
direnv reload
```

For temporary/one-off usage without modifying the project, use `uv run`:

```sh
# Run a one-off script with a dependency not in the environment
uv run --with cryptography script.py

# Start a REPL with extra packages available
uv run --with pycryptodome ipython
```

### Adding Node.js packages with npm

Node.js dependencies are managed through `package.json` and built natively by Nix via `importNpmLock`. To add a package:

```sh
# Add a dependency (updates package.json and package-lock.json)
npm install some-tool

# Rebuild the Nix environment with the new dependency
direnv reload
```

Bin scripts from installed packages are automatically available on PATH (e.g., installing a package that provides a CLI tool makes it directly runnable).

For temporary/one-off usage without modifying the project, use `npx`:

```sh
# Run a one-off tool without installing
npx some-tool@latest
```

## Augmenting the Environment

When a task calls for a tool or library not currently in the dev shell, you have several options:

### Temporary: ad-hoc install

- **Python**: `uv run --with <pkg>` for one-off exploration. See [uv workflow above](#adding-python-packages-with-uv).
- **Node.js**: `npx <pkg>` for one-off CLI tools. See [npm workflow above](#adding-nodejs-packages-with-npm).

### Permanent: add to the environment

**For Python libraries**, use uv to add them to `pyproject.toml`:

1. Run `uv add <package>` (updates `pyproject.toml` and `uv.lock`).
2. Run `direnv reload` to rebuild the Nix virtualenv with the new dependency.
3. If the package needs native libraries or build fixups, add overrides to the `dependencyFixups` section in `flake.nix`. See comments there for examples.
4. **Update the appropriate skill file or `CLAUDE.md`** to document the new library.

**For Node.js packages**, use npm to add them to `package.json`:

1. Run `npm install <package>` (updates `package.json` and `package-lock.json`).
2. Run `direnv reload` to rebuild the Nix node_modules with the new dependency.
3. **Update the appropriate skill file or `CLAUDE.md`** to document the new tool.

**For non-Python/non-Node tools**, add them to `flake.nix`:

1. **Search nixpkgs** for the package using the `/nix-package-search` skill (e.g., `/nix-package-search protobuf`).
2. **Edit `flake.nix`** to add the package to the `packages` list under the appropriate category section.
3. **Reload the environment** by running `direnv reload` (or exiting and re-entering `nix develop`).
4. **Update the appropriate skill file or `CLAUDE.md`** to document the new tool so documentation stays in sync with the flake.

You are encouraged to self-modify `flake.nix`, `pyproject.toml`, `package.json`, skill files, and this file whenever the analysis requires a tool that should be part of the standard environment. Keep the existing organizational structure (category comments, table format) when adding entries.

**Important:** When documenting a new tool, verify that the actual binary name on PATH matches what you write in the Command column. Nix package names often differ from binary names (e.g., `pkgs.aapt` provides `aapt2`, `pkgs.avalonia-ilspy` provides `ILSpy`, `pkgs.ghidra` wraps binaries with a `ghidra-` prefix). Run `which <command>` or check the package's `bin/` directory after `direnv reload` to confirm before documenting.

## Notes

- Ghidra requires a display server for its GUI. On headless/WSL systems, use an X server (e.g., VcXsrv) or Ghidra's headless analyzer: `ghidra-analyzeHeadless`.
- Frida requires a matching `frida-server` binary running on the target (device or host).
