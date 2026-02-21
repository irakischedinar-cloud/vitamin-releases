# I REUPLOADED IT BECAUSE IT HAS NO FEDORA VERSION, NOW IT HAS!


# Vitamin Browser

Vitamin Browser is a privacy-focused browser based on LibreWolf, with a built-in data-poisoning mode designed to make tracker profiles less accurate.

## What It Does

Vitamin Browser includes a **Data Poison** feature that can run fake browsing sessions in the background. These sessions generate realistic but false activity to pollute the behavior profiles built by ad networks and data brokers.

## Features

- Built on LibreWolf (Firefox fork) with strict privacy defaults
- Data Poison mode with human-like behavior simulation
- Enhanced Tracking Protection in Strict mode by default
- No telemetry, no sponsored content, no Pocket

## Install

Download a package from [Releases](https://github.com/realvitali/vitamin-releases/releases).

### Debian/Ubuntu

```bash
sudo dpkg -i vitamin-browser_*.deb
sudo apt -f install
```

### Fedora

```bash
sudo dnf install ./vitamin-browser-*.x86_64.rpm
```

## Building from source

Requires a LibreWolf build in `~/vitamin-deb-build/librewolf/`.

```bash
cd vitamin-source
bash build.sh deb
```

Output: `~/vitamin-deb-build/vitamin-browser_<version>_amd64.deb`

## Project Structure

- `vitamin-source/`: Build script, icons, and Vitamin-specific browser modules
- `vitamin-patches/`: Theme and content patches applied to the base browser

## License

Vitamin Browser is free and open-source software licensed under GPL-3.0.
See [LICENSE](./LICENSE) for details.
