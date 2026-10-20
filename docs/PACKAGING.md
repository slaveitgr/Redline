# Linux builds

The first native package target is **Ubuntu 26.10 amd64**. The development `.deb` has completed install/remove/reinstall/purge checks in a clean Ubuntu container. Hardware authorization, real GPU writes and desktop-session integration still require interactive testing on each target.

[Download Alpha 1](https://github.com/slaveitgr/Redline/releases/tag/v0.9.0-alpha.1) includes the locally validated Ubuntu `.deb`, AppImage Preview and SHA256SUMS. Release filenames use `-alpha1`; the Debian package metadata uses `~alpha1` for correct version ordering.

## Build outputs

| Format / target | Scope |
| --- | --- |
| Ubuntu 26.10 amd64 `.deb` | Native application, scoped hardware helpers, first-run setup and runtime dependencies. Local package build available. |
| Debian 13 amd64 `.deb` | Separate source build in the GitHub Actions matrix. Experimental until that build and distribution testing pass. |
| x86_64 AppImage Preview | Bundled Qt interface and monitoring preview; no privileged services are installed and hardware writes, installations and recording are disabled. |
| RPM, Arch and Flatpak | Not yet packaged or validated. These need their own dependency and authorization integration. |
| ARM64 | Not yet built. The initial installer/build-tool targets are x86_64. |

An AppImage built on a recent distribution does not automatically support older distributions. The build host's minimum glibc/libstdc++ requirements still apply. The current local AppImage is built on Ubuntu 26.10; do not treat it as a universal Linux binary. Python-based optional integrations use the host's Python/PyGObject; these are not bundled.

## Native package build

After building the application and integrated GPU engine:

```sh
python3 tools/build-deb.py --output dist
```

On another supported build container, use `--target 'Debian 13 amd64'` to label that container's actual native build. This flag does not cross-compile or make an Ubuntu binary compatible with Debian. Dependencies are generated from the built ELF files and supplemented with QML, media and authorization requirements.

Install the appropriate verified build with the distribution's package manager:

```sh
sudo apt install ./redline-graphics_0.9.0-alpha1_amd64.deb
```

Launch **Redline** from the application menu, or run `redline`, for the normal application. The optional `redline-preview` command inspects the interface without hardware writes; its desktop entry is hidden to avoid confusing the two modes. Normal **Redline** uses narrowly scoped services and first-run authorization for the local hardware-access group. Installing/updating optional third-party software can still require normal operating-system authorization.

## AppImage preview build

```sh
python3 tools/build-appimage.py --output dist
chmod +x dist/Redline-Preview-0.9.0-alpha1-x86_64.AppImage
./dist/Redline-Preview-0.9.0-alpha1-x86_64.AppImage
```

The builder downloads linuxdeploy and its Qt plugin using the recorded sizes and SHA-256 values in `packaging/appimage/tools.json`. Changed upstream assets fail verification until the manifest is reviewed. FUSE-free execution is available through `APPIMAGE_EXTRACT_AND_RUN=1`. Linux graphics libraries and a working desktop remain host requirements.

## Automated builds

[Linux development packages](https://github.com/slaveitgr/Redline/actions/workflows/build-packages.yml) builds from source in separate Ubuntu 26.10 and Debian 13 containers. It runs validation and the interface preview before packaging. Successful artifacts are available from the workflow run, with checksums; artifacts are development builds, not stable releases. Failed jobs retain any package files already produced for inspection. No release is published automatically.

Distribution compatibility is recorded only after the corresponding build and runtime checks pass. Broader coverage will require older-baseline AppImage builds, native RPM/Arch/Flatpak integration and real desktop/hardware testing.
