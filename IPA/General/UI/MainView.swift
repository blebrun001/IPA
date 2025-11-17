// MainView.swift
// Main interface with sidebar navigation and dynamic module display based on selected section.


import SwiftUI

extension Notification.Name {
    static let openDataverseUpload = Notification.Name("IPA.OpenDataverseUpload")
}

// Enum representing each application section (tab)
enum AppSection: String, CaseIterable, Identifiable {
    case photogrammetry
    case autoScale
    case objScaling
    case viewer
    case objRenamer
    case folderStructure
    case readmeGenerator
    case dataverseUpload
    case boneFolder
    
    var id: String { rawValue }
    
    // System SF Symbols icon for each section
    var systemImage: String {
        switch self {
        case .photogrammetry:      return "cube.box"
        case .autoScale:           return "ruler"
        case .objScaling:          return "arrow.up.left.and.arrow.down.right"
        case .viewer:              return "dot.viewfinder"
        case .objRenamer:          return "text.badge.plus"
        case .folderStructure:     return "folder"
        case .readmeGenerator:     return "doc.text"
        case .dataverseUpload:     return "square.and.arrow.up"
        case .boneFolder:          return "bolt"
        }
    }
    
    // Ordering index used to keep the sidebar sequence consistent
    var sortIndex: Int {
        AppSection.allCases.firstIndex(of: self) ?? 0
    }

    // Logical category used for grouping in the sidebar
    var category: SectionCategory {
        switch self {
        case .photogrammetry, .autoScale, .objScaling, .viewer:
            return .creation
        case .objRenamer, .folderStructure, .boneFolder:
            return .files
        case .readmeGenerator, .dataverseUpload:
            return .dataset
        }
    }
    
    // Localized title exposed to UI components
    var localizedTitle: String {
        switch self {
        case .photogrammetry:
            return NSLocalizedString("Photogrammetry", comment: "Sidebar entry for photogrammetry tools")
        case .autoScale:
            return NSLocalizedString("Auto Scale", comment: "Sidebar entry for semi-automatic scaling")
        case .objScaling:
            return NSLocalizedString("OBJ Scaling", comment: "Sidebar entry for OBJ scaling module")
        case .viewer:
            return NSLocalizedString("Viewer", comment: "Sidebar entry for 3D viewer")
        case .objRenamer:
            return NSLocalizedString("OBJ Renamer", comment: "Sidebar entry for OBJ renaming tool")
        case .folderStructure:
            return NSLocalizedString("Folder Structure", comment: "Sidebar entry for folder structure generator")
        case .readmeGenerator:
            return NSLocalizedString("README Generator", comment: "Sidebar entry for README generator")
        case .dataverseUpload:
            return NSLocalizedString("Dataverse Upload", comment: "Sidebar entry for Dataverse upload module")
        case .boneFolder:
            return NSLocalizedString("Bone Folder", comment: "Sidebar entry for bone folder utility")
        }
    }
}

// Sidebar categories used to group modules by purpose
enum SectionCategory: CaseIterable, Hashable {
    case creation
    case files
    case dataset
    
    var sortIndex: Int {
        switch self {
        case .creation: return 0
        case .files:    return 1
        case .dataset:  return 2
        }
    }
    
    var localizedTitle: String {
        switch self {
        case .creation:
            return NSLocalizedString("3D creation", comment: "Sidebar group title for 3D creation tools")
        case .files:
            return NSLocalizedString("Files management", comment: "Sidebar group title for file management tools")
        case .dataset:
            return NSLocalizedString("Dataset preparation", comment: "Sidebar group title for dataset preparation tools")
        }
    }
}

struct MainView: View {
    
    // Currently selected section
    @State private var selectedSection: AppSection = .photogrammetry
    
    // ViewModel injection example
    @EnvironmentObject var photogrammetryVM: PhotogrammetryViewModel
    
    // Sections grouped by category
    private var groupedSections: [(category: SectionCategory, sections: [AppSection])] {
        Dictionary(grouping: AppSection.allCases, by: { $0.category })
            .map { ($0.key, $0.value.sorted { $0.sortIndex < $1.sortIndex }) }
            .sorted { $0.category.sortIndex < $1.category.sortIndex }
    }

    var body: some View {
        NavigationSplitView {
            VStack {
                List(selection: $selectedSection) {
                    ForEach(groupedSections, id: \.category) { group in
                        Section(header: Text(group.category.localizedTitle)) {
                            ForEach(group.sections, id: \.self) { section in
                                Label(section.localizedTitle, systemImage: section.systemImage)
                                    .tag(section)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle(NSLocalizedString("Tools", comment: "Sidebar navigation title"))

                Spacer()

                // Footer with logo and credits
                VStack {
                    Image("AppLogoFooter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .opacity(0.5)
                    Text(NSLocalizedString("Version 1.1.0", comment: "Application version in sidebar footer"))
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Text(NSLocalizedString("© 2025 Brice Lebrun", comment: "Application copyright"))
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 10)
            }
        } detail: {
            // Dynamic content for the selected section
            contentView(for: selectedSection)
                .navigationTitle(selectedSection.localizedTitle)
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            // Language selector
                    ToolbarItem(placement: .primaryAction) {
                        LanguageMenuButton()
                    }
                }
        .toolbarRole(.automatic)
        .onReceive(NotificationCenter.default.publisher(for: .openDataverseUpload)) { _ in
            selectedSection = .dataverseUpload
        }
    }
    
    // Returns the view corresponding to the selected section
    @ViewBuilder
    private func contentView(for section: AppSection) -> some View {
        switch section {
        case .photogrammetry:
            PhotogrammetryTabView(viewModel: photogrammetryVM)
        case .autoScale:
            AutoScaleTabView()
        case .objScaling:
            OBJScalingTabView()
        case .objRenamer:
            OBJRenameTabView()
        case .folderStructure:
            FolderStructureTabView()
        case .readmeGenerator:
            ReadmeGeneratorTabView()
        case .dataverseUpload:
            DataverseUploadTabView()
        case .viewer:
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
            .environmentObject(AutoScaleViewModel())
            .environmentObject(OBJScalerViewModel())
            .environmentObject(OBJRenamerViewModel())
            .environmentObject(ReadmeGeneratorViewModel())
            .environmentObject(FolderStructureViewModel())
            .environmentObject(LanguageManager())
            .environmentObject(BoneFolderViewModel())
    }
}
