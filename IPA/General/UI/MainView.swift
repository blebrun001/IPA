// MainView.swift
// Main interface with sidebar navigation and dynamic module display based on selected section.


import SwiftUI

// Enum representing each application section (tab)
enum AppSection: String, CaseIterable, Identifiable {
    case photogrammetry = "Photogrammetry"
    case objScaling = "OBJ Scaling"
    case objRenamer = "OBJ Renamer"
    case folderStructure = "Folder Structure"
    case readmeGenerator = "README Generator"
    case dataverse = "Dataverse Upload"
    case Viewer = "Viewer"
    case boneFolder = "Bone Folder"
    
    var id: String { rawValue }
    
    // System SF Symbols icon for each section
    var systemImage: String {
        switch self {
        case .photogrammetry:      return "cube.box"
        case .objScaling:          return "arrow.up.left.and.arrow.down.right"
        case .objRenamer:          return "text.badge.plus"
        case .folderStructure:     return "folder"
        case .readmeGenerator:     return "doc.text"
        case .dataverse:           return "icloud.and.arrow.up"
        case .Viewer:              return "dot.viewfinder"
        case .boneFolder:          return "bolt"
        }
    }
    
    // Logical category used for grouping in the sidebar
    var category: String {
        switch self {
        case .photogrammetry, .objScaling, .Viewer:
            return "3D creation"
        case .objRenamer, .folderStructure, .boneFolder:
            return "Files management"
        case .readmeGenerator, .dataverse:
            return "Dataset preparation"
        }
    }
}

struct MainView: View {
    
    // Currently selected section
    @State private var selectedSection: AppSection = .photogrammetry
    
    // ViewModel injection example
    @EnvironmentObject var photogrammetryVM: PhotogrammetryViewModel
    
    // Sections grouped by category
    private var groupedSections: [(key: String, value: [AppSection])] {
        Dictionary(grouping: AppSection.allCases, by: { $0.category })
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationSplitView {
            VStack {
                List(selection: $selectedSection) {
                    ForEach(groupedSections, id: \.key) { group in
                        Section(header: Text(group.key)) {
                            ForEach(group.value, id: \.self) { section in
                                Label(section.rawValue, systemImage: section.systemImage)
                                    .tag(section)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("Tools")

                Spacer()

                // Footer with logo and credits
                VStack {
                    Image("AppLogoFooter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .opacity(0.5)
                    Text("Version 1.0.0")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Text("© 2025 Brice Lebrun")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 10)
            }
        } detail: {
            // Dynamic content for the selected section
            contentView(for: selectedSection)
                .navigationTitle(selectedSection.rawValue)
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            // Language selector
                    ToolbarItem(placement: .primaryAction) {
                        LanguageMenuButton()
                    }
                }
        .toolbarRole(.automatic)
    }
    
    // Returns the view corresponding to the selected section
    @ViewBuilder
    private func contentView(for section: AppSection) -> some View {
        switch section {
        case .photogrammetry:
            PhotogrammetryTabView(viewModel: photogrammetryVM)
        case .objScaling:
            OBJScalingTabView()
        case .objRenamer:
            OBJRenameTabView()
        case .folderStructure:
            FolderStructureTabView()
        case .readmeGenerator:
            ReadmeGeneratorTabView()
        case .dataverse:
            DataverseTabView()
        case .Viewer:
            ViewerTabView()
        case .boneFolder:
            BoneFolderTabView()
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(PhotogrammetryViewModel())
            .environmentObject(MeasureViewModel())
            .environmentObject(OBJScalerViewModel())
            .environmentObject(OBJRenamerViewModel())
            .environmentObject(ReadmeGeneratorViewModel())
            .environmentObject(DataverseViewModel())
            .environmentObject(FolderStructureViewModel())
            .environmentObject(LanguageManager())
            .environmentObject(BoneFolderViewModel())
    }
}
