import SwiftUI

struct MainContentView: View {
    var authenticationManager = AuthenticationManager()
    private let gridItemLayout = [GridItem(.flexible()), GridItem(.flexible())]

    @ObservedObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = MainContentModel()
    
    // タップされた画像を保持するための State 変数を追加
    @State var selectedImage: UIImage?
    @State var selectedIndex = Int()
    @State var dates  = [String]()
    @State var tapdocumentId = String()
    @State private var Music: [FirebaseMusic] = []
    @State var documentIdArray = []
    @State var first = true

   
    var body: some View {
        NavigationView {
            VStack {
                if authenticationManager.isSignIn == false {
                    HStack {
                        Spacer()
                        Button {
                            viewModel.isShowSheet.toggle()
                            viewModel.saveUserData()
                        } label: {
                            Text("Sign-In")
                        }
                        .padding()
                    }
                } else {
                    HStack {
                        Button {
                            authenticationManager.signOut()
                        } label: {
                            Text("Sign-Out")
                        }
                    }
                    Button("Open Camera") {
                        viewModel.isPresentingCamera = true
                        
                    }
                    .fullScreenCover(isPresented: $viewModel.isPresentingCamera) {
                        Camera2View(isPresentingCamera: $viewModel.isPresentingCamera, cameraManager: cameraManager, isPresentingSearch: .constant(true))
                    }
               
                    ScrollView {
                        LazyVGrid(columns: gridItemLayout, spacing: 3) {
                            ForEach($viewModel.images.indices, id: \.self) { index in
                                // 画像を NavigationLink でラップ
                                NavigationLink(
                                    destination: ImageDetailView(image: $selectedImage, documentId: $tapdocumentId, tapdocumentId: $tapdocumentId, viewModel: viewModel, selectedIndex: selectedIndex),
                                    tag: viewModel.images[index],
                                    selection: $selectedImage,
                                    label: {
                                        Image(uiImage: viewModel.images[index])
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 200, height: 350)
                                            .clipped()
                                            .onTapGesture {
                                                tapdocumentId  = viewModel.documentIdArray[index] as! String
                                                selectedImage = viewModel.images[index]
                                                selectedIndex = index 
                                            }
                                    }
                                )

                                
                            }
                        }
                    }


            
                    .refreshable {
                        Task {
                            do {
                                try await viewModel.getUrl()
                            }
                        }
                    }
                    .onReceive(cameraManager.$newImage) { newImage in
                        if newImage != nil {
                            // self.images.append(newImage)
                        }
                    }
                }
                
                Spacer()
                    .sheet(isPresented: $viewModel.isShowSheet) {
                        LoginView()
                    }
                    .onAppear {
                        Task {
                            if first == true{
                                try await viewModel.firstgetUrl()
                                try await viewModel.getDate()
                               
                                first = false
                            }else{
                                try await viewModel.getUrl()
                            }
                        
                        }
                    }
                
            }
            .background(Color(red: 229 / 255, green: 217 / 255, blue: 255 / 255, opacity: 1.0))
            .navigationTitle("チェキ一覧")
        }
    }
}
