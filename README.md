# Vitamin Browser

**Supplement your search.** A privacy-focused browser based on LibreWolf with built-in data poisoning to fight tracker profiling.

## What it does

Vitamin Browser includes a "Data Poison" feature that runs fake browsing sessions in the background, generating realistic but false activity to pollute the profiles that data brokers and ad networks build about you.

## Features

- Built on LibreWolf (Firefox fork) with strict privacy defaults
- Data Poison mode: generates fake browsing sessions with human-like behavior
- Enhanced Tracking Protection in Strict mode out of the box
- No telemetry, no sponsored content, no pocket

## Install

Download the latest `.deb` from [Releases](https://github.com/realvitali/vitamin-browser/releases):

```bash
sudo dpkg -i vitamin-browser_*.deb
```

## Building from source

Requires a LibreWolf build in `~/vitamin-deb-build/librewolf/`.

```bash
cd vitamin-source
bash build.sh deb
```

Output: `~/vitamin-deb-build/vitamin-browser_<version>_amd64.deb`

## Project structure

- `vitamin-source/` - Build script, icons, and Vitamin-specific browser modules
- `vitamin-patches/` - Theme and content patches applied to the base browser

## License

Vitamin Browser is free and open-source software licensed under GPL-3.0.
See [LICENSE](./LICENSE) for details.
