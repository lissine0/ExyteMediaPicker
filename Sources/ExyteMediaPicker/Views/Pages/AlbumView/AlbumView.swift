//
//  Created by Alex.M on 27.05.2022.
//

import SwiftUI
import AnchoredPopup

struct AlbumView: View {

    @EnvironmentObject private var selectionService: SelectionService
    @EnvironmentObject private var permissionsService: PermissionsService
    @Environment(\.mediaPickerTheme) private var theme

    @ObservedObject var keyboardHeightHelper = KeyboardHeightHelper.shared

    @StateObject var viewModel: BaseMediasProvider
    @Binding var showingCamera: Bool
    @Binding var currentFullscreenMedia: Media?

    var title: String?
    var shouldShowCamera: Bool
    var selectionParamsHolder: SelectionParamsHolder
    var dismiss: ()->()

    @State private var fullscreenItem: AssetMediaModel.ID?

    private var shouldShowLoadingCell: Bool {
        viewModel.isLoading && viewModel.assetMediaModels.count > 0
    }

    var body: some View {
        VStack {
            if let title = title {
                Text(title)
            }
            content
        }
        .onAppear {
            viewModel.reload()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    @ViewBuilder
    var content: some View {
        ScrollView {
            VStack {
                if let action = permissionsService.photoLibraryAction {
                    PermissionsActionView(action: .library(action))
                }

                if shouldShowCamera, let action = permissionsService.cameraAction {
                    PermissionsActionView(action: .camera(action))
                }

                if viewModel.isLoading, viewModel.assetMediaModels.isEmpty {
                    ProgressView()
                        .padding()
                } else if !viewModel.isLoading, viewModel.assetMediaModels.isEmpty {
                    Text("Empty data")
                        .font(.title3)
                        .foregroundColor(theme.main.pickerText)
                } else {
                    mediasGrid
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(theme.main.pickerBackground)
        .onTapGesture {
            if keyboardHeightHelper.keyboardDisplayed {
                dismissKeyboard()
            }
        }
    }

    var mediasGrid: some View {
        MediasGrid(viewModel.assetMediaModels) {
#if !targetEnvironment(simulator)
            if shouldShowCamera && permissionsService.cameraAction == nil {
                LiveCameraCell {
                    showingCamera = true
                }
            }
#endif
        } content: { assetMediaModel, index, cellSize in
            cellView(assetMediaModel, index, cellSize)
        } loadingCell: {
            if shouldShowLoadingCell {
                ZStack {
                    Color.white.opacity(0.5)
                    ProgressView()
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .onChange(of: viewModel.assetMediaModels) { newValue in
            selectionService.updateSelection(with: newValue)
        }
    }

    @ViewBuilder
    func cellView(_ assetMediaModel: AssetMediaModel, _ index: Int, _ size: CGFloat) -> some View {
        let imageButton = Button {
            if keyboardHeightHelper.keyboardDisplayed {
                dismissKeyboard()
            }
            if !selectionParamsHolder.showFullscreenPreview { // select immediately
                selectionService.onSelect(assetMediaModel: assetMediaModel)
                if selectionService.mediaSelectionLimit == 1 {
                    dismiss()
                }
            }
            else if fullscreenItem == nil {
                fullscreenItem = assetMediaModel.id
            }
        } label: {
            let id = "fullscreen_photo_\(index)"
            MediaCell(viewModel: MediaViewModel(assetMediaModel: assetMediaModel), size: size)
                .useAsPopupAnchor(id: id) {
                    FullscreenContainer(
                        currentFullscreenMedia: $currentFullscreenMedia,
                        selection: $fullscreenItem,
                        animationID: id,
                        assetMediaModels: viewModel.assetMediaModels,
                        selectionParamsHolder: selectionParamsHolder,
                        dismiss: dismiss
                    )
                    .environmentObject(selectionService)
                } customize: {
                    $0.closeOnTap(false)
                        .animation(.easeIn(duration: 0.2))
                }
        }
        .buttonStyle(MediaButtonStyle())
        .contentShape(Rectangle())

        if selectionService.mediaSelectionLimit == 1 {
            imageButton
        } else {
            SelectableView(selected: selectionService.index(of: assetMediaModel), isFullscreen: false, canSelect: selectionService.canSelect(assetMediaModel: assetMediaModel), selectionParamsHolder: selectionParamsHolder) {
                selectionService.onSelect(assetMediaModel: assetMediaModel)
            } content: {
                imageButton
            }
        }
    }
}
