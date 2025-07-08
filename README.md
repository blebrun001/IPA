
<p align="center">
  <img src="AppIcon.png" alt="IPA Logo" width="120" />
</p>

# IPA


IPA (Integrated Photogrammetry Assistant) is a macOS application developed for internal use at the IPHES-CERCA laboratory. Its primary purpose is to support the digitization of the IPHES-CERCA Osteological Reference Collection. The software enables users to efficiently generate and scale 3D models, and to publish them on Dataverse. It also streamlines repetitive tasks such as nested folder creation and renaming of .OBJ and .MTL files.

## Features
- 3D model creation and scaling
- Readme generator
- Dataset preparation (Dataverse client, Readme generator)
- File management utilities

## Project Structure
- `IPA/` — Main app source code
  - `General/Logic/` — Core logic and settings
  - `General/UI/` — Main UI components
  - `Internationalization/` — Language management
  - `Modules/` — Main features (3D creation, dataset preparation, file management)
  - `Assets.xcassets/` — App assets and icons
  - `Sounds/` — Sound files and player
- `IPATests/` — Unit tests
- `IPAUITests/` — UI tests

## Requirements
- macOS
- Xcode (latest recommended)
- Swift

## Getting Started
1. Clone the repository
2. Open `IPA.xcodeproj` in Xcode
3. Build and run the app

## Fundings

This work is part of the Esqueletos en linea project held by Dr Palmira Saladié (IPHES-CERCA), financed by the Maria de Guzman action of Fundación Española para la Ciencia y la Tecnología

---

## License

This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) License.

See the full license at: [https://creativecommons.org/licenses/by-nc/4.0/](https://creativecommons.org/licenses/by-nc/4.0/)
