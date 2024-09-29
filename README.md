# Go Upgrader and Version Manager

Upgrades to the latest version of Go, or manages more versions of Go on the same machine, supporting all platforms including RISC-V, as simple es `rustup`.

* Small. Written in `bash`, easily extensible.
* Fast. Downloads and unpacks pre-built binary builds.
* Portable. Writes only to the user home directory.
* Simple. Switches the version globally, no environment variable changes needed.
* Efficient. Just run `goup up`.

Platforms: `aix-ppc64`, `darwin-amd64`, `darwin-arm64`, `dragonfly-amd64`, `freebsd-386`, `freebsd-amd64`, `freebsd-arm64`, `freebsd-arm`, `freebsd-riscv64`, `illumos-amd64`, `linux-386`, `linux-amd64`, `linux-arm64`, `linux-armv6l`, `linux-loong64`, `linux-mips`, `linux-mips64`, `linux-mips64le`, `linux-mipsle`, `linux-ppc64`, `linux-ppc64le`, `linux-riscv64`, `linux-s390x`, `netbsd-386`, `netbsd-amd64`, `netbsd-arm64`, `netbsd-arm`, `openbsd-386`, `openbsd-amd64`, `openbsd-arm64`, `openbsd-arm`, `openbsd-ppc64`, `plan9-386`, `plan9-amd64`, `plan9-arm`, `solaris-amd64`, `windows-386`, `windows-amd64`, `windows-arm64`, `windows-arm`.

## Getting Started

Make sure that you have `bash` 4 or newer and `curl` available, execute the following command:

    curl -fSs https://raw.githubusercontent.com/prantlf/goup/master/install.sh | bash

Before you continue, make sure that you have the following tools available: `curl`, `grep`, `jq`, `ln`, `rm`, `rmdir`, `sed`, `tar` (non-Windows), `uname`, `unzip` (Windows). It's likely that `jq` will be missing. You can install it like this on Debian: `apt-get install -y jq`.

Install the latest version of Go, if it hasn't been installed yet:

    goup install latest

Upgrade both the installer script and the Go language, if they're not the latest versions, and delete the previously active latest version from the disk too:

    goup up

## Installation

Make sure that you have `bash` 4 or newer and `curl` available, execute the following command:

    curl -fSs https://raw.githubusercontent.com/prantlf/goup/master/install.sh | bash

Both the `goup` and `go` should be executable in any directory via the `PATH` environment variable. The installer script will modify the RC-file of the shell, from which you launched it. The following RC-files are supported:

    ~/.bashrc
    ~/.zshrc
    ~/.config/fish/config.fish

If you use other shell or more shells, update the other RC-files by putting both the installer directory and the Go binary directory to `PATH`, for example:

    $HOME/.goup:$HOME/.go/bin:$PATH

Start a new shell after the installer finishes. Or extend the `PATH` in the current shell as the instructions on the console will tell you.

## Locations

| Path      | Description                                            |
|:----------|:-------------------------------------------------------|
| `~/.goup` | directory with the installer script and versions of Go |
| `~/.go`   | symbolic link to the currently active version of Go    |

For example, with the Go 1.23.0 activated:

    /home/prantlf/.goup
      ├── 1.22.0  (another version)
      ├── 1.23.0  (linked to /home/prantlf/.go)
      └── goup    (installer script)

## Usage

    goup <task> [version]

    Tasks:

      current              print the currently selected version of Go
      latest               print the latest version of Go for download
      local                print versions of Go ready to be selected
      remote               print versions of Go available for download
      update               update this tool to the latest version
      upgrade              upgrade Go to the latest and remove the current version
      up                   perform both update and upgrade tasks
      install <version>    add the specified or the latest version of Go
      uninstall <version>  remove the specified version of Go
      use <version>        use the specified or the latest version of Go
      help                 print usage instructions for this tool
      version              print the version of this tool

You can enter just `MAJ` or `MAJ.MIN` as `<version>`, instead of the full `MAJ.MIN.PAT`. When using the `install` or `use` tasks, the *most* recent full version that starts by the entered partial version will be picked. When using the `uninstall` task, the *least* recent full version that starts by the entered partial version will be picked.

## Debugging

If you enable `bash` debugging, every line of the script will be printed on the console. You'll be able to see values of local variables and follow the script execution:

    bash -x goup ...

You can debug the installer too:

    curl -fSs https://raw.githubusercontent.com/prantlf/goup/master/install.sh | bash -x

## Platform Detection

### Environment Variables

The following environment variables can be set before running `install.sh` or `goup`, if you know what you're doing:

| Variable          | Default value                            |
|:------------------|:-----------------------------------------|
| `PLATFORM`        | detected using `uname`                   |
| `OS`              | part of `PLATFORM` before `-`            |
| `ARCH`            | part of `PLATFORM` after `-`             |
| `TOOL_URL_LIST`   | https://go.dev/dl/?mode=json&include=all |
| `TOOL_URL_LATEST` | https://go.dev/dl/?mode=json             |
| `TOOL_URL_DIR`    | https://dl.google.com/go                 |
| `INST_DIR`        | `$HOME/.goup`                            |
| `TOOL_DIR`        | `$HOME/.go`                              |

### ARM Architectures

The detection of the architecture ARM v6 and v7 may not work in your environment. For example, `uname -m` in Debian reports:

| Architecture | Output   |
|:-------------|:---------|
| ARM v6       | `armhf`  |
| ARM v7       | `armhf`  |
| ARM v8       | `arm64`  |

While, `uname -m` in Raspbian reports:

| Architecture | Output    |
|:-------------|:----------|
| ARM v6       | `armhf`   |
| ARM v7       | `armv7l`  |
| ARM v8       | `aarch64` |

`nodeup` regognises `armhf` as ARM v6. If you use it on Debian and ARM v7, enforce the proper architecture by setting the environment variable `ARCH` explicitly:

    ARCH=armv7l nodeup ...

If you don't do it, the `node` executable will work well nevertheless, because binaries for ARM v6 can be run on ARM v7. Just the performance of floating point computations may be lower.

If `uname` reports other value than `armhf`, the platform recognition will work well. Pay attention to the console output, in particular to this line:

    detected platform linux-armv6l

## Contributing

In lieu of a formal styleguide, take care to maintain the existing coding style. Lint and test your code.

## License

Copyright (c) 2024 Ferdinand Prantl

Licensed under the MIT license.
