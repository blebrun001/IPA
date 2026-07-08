<p align="center">
  <img src="IPA/Assets.xcassets/AppIcon.appiconset/IPA512.png" alt="Integrated Photogrammetry Assistant logo" width="140" />
</p>

# Integrated Photogrammetry Assistant

Integrated Photogrammetry Assistant is a macOS application developed at IPHES-CERCA by Brice Lebrun to streamline the production, scaling, organisation, and publication of osteological 3D datasets. The toolkit brings together photogrammetry automation, OBJ post-processing utilities, dataset preparation helpers, and Dataverse publishing tools inside a single interface.

## Key Capabilities
- Photogrammetry capture orchestration with automated clean-up and optional texture compression.
- Semi-automatic and manual OBJ scaling workflows, including Micro QR-based measurement extraction.
- Interactive 3D viewer with measurement scraping and quick transfer to scaling modules.
- Dataset preparation helpers: README generator, Dataverse uploader, folder templating, and OBJ renaming.
- Bone folder creation assistant backed by UBERON suggestions.

## Dataverse Upload Module
The **Dataverse upload** tab (under *Dataset preparation*) is now a native Integrated Photogrammetry Assistant module. It shares credentials with the global settings screen and requires:

- A Dataverse base URL (e.g. `https://demo.dataverse.org`).
- An API key with write access to the target dataset.
- The dataset persistent identifier (`doi:...`) that will be prefilled automatically when coming from the README Generator.

### Configuration & Options
- **Exclude regex** filters dotfiles or any custom pattern before uploads.
- **Direct upload** toggles the S3 presigned flow; the coordinator automatically falls back to server-side multipart uploads if the endpoint is missing (404) or the dataset exceeds the S3 limit.
- **Retries & backoff**: set maximum attempts, initial delay, and whether to resume automatically on transient URLError/POSIX codes.
- **Index refresh**: refresh by time or by file count to keep remote duplicate detection in sync.
- **Checksum matching**: optionally compute MD5/SHA checksums locally when the Dataverse draft listing exposes them for reliable deduplication.

### Runtime Behaviour
- Security-scoped bookmarks are resolved for each dropped folder/file so the sandbox can read the content.
- Duplicate detection runs both before and after each upload using the remote draft file list (path+size or path+checksum).
- Progress shows the current file, byte-transfer text, and a console-style log with retry hints.
- Direct uploads stream straight to the storage provider; if a file exceeds the provider limit or the server rejects the request, Integrated Photogrammetry Assistant switches to the multipart fallback automatically without losing progress.
- Practical limits follow the Dataverse deployment configuration (typical direct-upload size caps mirror the backing object store, while server-side multipart handles very large files but is constrained by HTTP timeouts).

## Project Layout
- `IPA/`
  - `General/` – Scene setup, global settings, shared UI.
  - `Internationalization/` – Localization resources and language picker utilities.
  - `Modules/` – Feature groups (3D creation, dataset preparation, file management).
  - `Assets.xcassets/`, `Sounds/`, `Preview Content/` – Media and design resources.
- `IPATests/`, `IPAUITests/` – Unit and UI test targets.
- `assets/` – Marketing and documentation assets.

## Requirements
- macOS 13 Ventura or later.
- Xcode 15 or later with the Swift 5.9 toolchain.
- Apple Silicon or Intel Mac capable of running RealityKit photogrammetry workflows.

## Getting Started
1. Clone the repository and ensure submodules (if any) are initialised.
2. Open `IPA.xcodeproj` in Xcode.
3. Select the `IPA` scheme and build/run on macOS.
4. Provide the necessary Dataverse credentials under **Settings → General** before using upload features.

## Releases
Tagged versions matching `v*` are built by GitHub Actions as unsigned macOS release archives. The packaged app is named `Integrated Photogrammetry Assistant.app`.

Because release builds are unsigned and not notarized, macOS Gatekeeper will warn before opening the downloaded app.

## Localization
Integrated Photogrammetry Assistant ships with four fully translated interfaces:
- English *(default UI language)*
- French
- Spanish
- Catalan

The active language can be changed at runtime from the toolbar globe button. Switching languages restarts the app to reload localized resources.

## Development Notes
- Project preferences are stored via `AppStorage` in `SettingsManager`.
- Photogrammetry sessions are coordinated by `PhotogrammetryManager`, which also supervises export clean-up.
- Micro QR detection and auto-scaling live inside `AutoScaleViewModel` and related views.
- When adding new UI text, use `NSLocalizedString` with a descriptive comment and add translations in `Internationalization/Localizable.xcstrings`.

## Funding Acknowledgement
This work is part of the *Esqueletos en línea* project led by Dr. Palmira Saladié (IPHES-CERCA), funded by the María de Guzmán programme of the Fundación Española para la Ciencia y la Tecnología.

## License
Licensed under the GNU General Public License, Version 3, 29 June 2007.

See `LICENSE` for the full license text.
