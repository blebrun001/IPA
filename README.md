<p align="center">
  <img src="IPA/Assets.xcassets/AppIcon.appiconset/IPA512.png" alt="IPA Logo" width="140" />
</p>

# IPA - Integrated Photogrammetry Assistant

IPA is a macOS application developed at IPHES-CERCA by Brice Lebrun to streamline the production, scaling, organisation, and publication of osteological 3D datasets. The toolkit brings together photogrammetry automation, OBJ post-processing utilities, dataset preparation helpers, and Dataverse publishing tools inside a single interface.

## Key Capabilities
- Photogrammetry capture orchestration with automated clean-up and optional texture compression.
- Semi-automatic and manual OBJ scaling workflows, including Micro QR-based measurement extraction.
- Interactive 3D viewer with measurement scraping and quick transfer to scaling modules.
- Dataset preparation helpers: README generator, Dataverse uploader, folder templating, and OBJ renaming.
- Bone folder creation assistant backed by UBERON suggestions.

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

## Localization
IPA ships with four fully translated interfaces:
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
Licensed under the Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) License.

Full text: <https://creativecommons.org/licenses/by-nc/4.0/>
