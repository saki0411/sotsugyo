//
//  SignInedView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/13.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore


struct SignInedView: View {
    @ObservedObject var viewModel: MainContentModel
    @ObservedObject var cameraManager: CameraManager
    @State private var selectedImage: UIImage?
    @State private var selectedIndex = 0
    @State private var tapDocumentId = ""
    @State private var showAlart = false
    @State private var folderBuf = ""
    @State var first = true
    @State var authenticationManager = AuthenticationManager()
    
    
    var body: some View {
        
        VStack {
            HStack {
                Button {
                    authenticationManager.signOut()
                    first = true
                    viewModel.folderDocumentIdArray = []
                } label: {
                    Text("Sign-Out")
                }
            }
            VStack {
                CameraFolderView(
                    isPresentingCamera: $viewModel.isPresentingCamera,
                    showAlart: $showAlart,
                    folderBuf: $folderBuf,
                    cameraManager: cameraManager,
                    viewModel: viewModel, friendUid: .constant("")
                )
                
            }
            FolderContentView(viewModel: viewModel, selectedFolderIndex: $selectedIndex)
            FolderTextView(viewModel: viewModel, selectedFolderIndex: $selectedIndex, userDataList: viewModel, folderDocument:  $viewModel.folderDocument)
            
            
            MainImageView(
                tapImage: $selectedImage,
                tapIndex: $selectedIndex,
                tapdocumentId: $tapDocumentId, selectedFolderIndex: $viewModel.folderDocument, selectedFolderIndex2: $selectedIndex,
                viewModel: viewModel
            )
            Spacer()
            
                .onAppear {
                    Task {
                        if first == true{
                            try await viewModel.firstgetUrl()
                            try await viewModel.getFolder()
                          
                            try await viewModel.getDate()
                           
                            first = false
                        } else {
                            try await viewModel.firstgetUrl()
                            try await viewModel.getFolder()
                        }
                    }
                }
        }
    }
}

