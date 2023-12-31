//
//  Main ContentModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine
import AVFoundation
import SwiftUI
import Kingfisher
import Photos
class MainContentModel: ObservableObject {
    
    
    @Published internal var isShowSheet = false
    @Published internal var images: [UIImage] = []
    @Published internal var foldersImages: [UIImage] = []
    @Published internal var isPresentingCamera = false
    @Published internal var dates: [String] = []
    @Published internal var folderDates: [String] = []
    @Published internal var Music: [FirebaseMusic] = []
    @Published internal var documentIdArray = [String]()
    @Published internal var folderDocumentIdArray = [String]()
    @Published internal var folderUrl = []
    @Published internal var folders = [String]()
    @Published internal var foldersDocumentId = [String]()
    @Published var folderImages: [String: [UIImage]] = [:]
    @Published internal var getimage = false
    @Published internal var folderDocument = String()
    @Published internal var photoDataCache: [String: Data] = [:]
    @Published internal var nfc = false
    
    @Published var userDataList: String = ""
    var audioPlayer: AVPlayer?
    var url = URL.init(string: "https://www.hello.com/sample.wav")
    
    func firstgetUrl() async throws {
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "uid is nil"])
            }
            
            let db = Firestore.firestore()
            
            var urlArray = [String]()
            DispatchQueue.main.async {
                self.images = []
                self.documentIdArray = []
            }
            
            let ref = try await db.collection("users").document(uid).collection("folders").document("all").collection("photos").order(by: "date").getDocuments()
            
            for document in ref.documents {
                let data = document.data()
                let url = data["url"]
                if url != nil {
                    urlArray.append(url as! String)
                }
                let documentId = document.documentID
                DispatchQueue.main.async {
                    self.documentIdArray.append(documentId)
                    
                }
            }
            let storage = Storage.storage()
            let storageRef = storage.reference()
            
            for (index, photo) in urlArray.enumerated() {
                
                
                do {
                    let data = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Data, Error>) in
                        let imageRef = storageRef.child("images/" + photo)
                        imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else if let data = data {
                                continuation.resume(returning: data)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        if index <= self.images.count {
                            let image = UIImage(data: data)
                            
                            self.images.insert(image!, at: index)
                            
                        } else {
                            print("Index out of range. Ignoring data insertion.")
                        }
                    }
                } catch {
                    print("Error occurred! : \(error)")
                }
            }
            
            
            
        }
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let db = Firestore.firestore()
            DispatchQueue.main.async {
                self.folderDocument = "all"
            }
            try await db.collection("users").document(uid).collection("folders").document("all").updateData(["title": "all","date": FieldValue.serverTimestamp()])
            
            
            
            
        }
    }
    
    
    func getUrl() async throws {
        do {
            let db = Firestore.firestore()
            let uid = Auth.auth().currentUser?.uid
            var urlArray = [String]()
            
            let document = try await db.collection("users").document(uid ?? "").getDocument()
            let data = document.data()
            let date = data?["date"]
            
            if date != nil {
                let ref = try await db.collection("users").document(uid!).collection("folders").document("all").collection("photos").whereField("date", isGreaterThanOrEqualTo: date as Any).order(by: "date").getDocuments()
                
                for document in ref.documents {
                    let data = document.data()
                    let url = data["url"]
                    if url != nil {
                        urlArray.append(url as! String)
                    }
                    let documentId = document.documentID
                    DispatchQueue.main.async {
                        self.documentIdArray.append(documentId)
                        
                    }
                }
                
                let storage = Storage.storage()
                let storageRef = storage.reference()
                for (index, photo) in urlArray.enumerated() {
                    if let cachedData = photoDataCache[photo] {
                        let image = UIImage(data: cachedData)
                        DispatchQueue.main.async {
                            self.images.insert(image!, at: index)
                        }
                    } else {
                        let imageRef = storageRef.child("images/" + photo)
                        do {
                            
                            let data = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Data, Error>) in
                                imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                                    if let error = error {
                                        continuation.resume(throwing: error)
                                    } else if let data = data {
                                        continuation.resume(returning: data)
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.photoDataCache[photo] = data
                            }
                            let image = UIImage(data: data)
                            print(index)
                            DispatchQueue.main.async {
                                self.images.insert(image!, at: index)
                            }
                        } catch {
                            print("Error occurred during download! : \(error)")
                            
                        }
                    }
                }
            }
            
            try await db.collection("users").document(uid ?? "").setData(["date": FieldValue.serverTimestamp()])
        } catch {
            throw error
        }
    }
    
    
    func saveUserData(){
            
            let db = Firestore.firestore()
            
            if let currentUser = Auth.auth().currentUser {
                let uid = currentUser.uid
                db.collection("users").document(uid).collection("personal").document("info").setData([
                    "uid": uid ,
                    "email": currentUser.email ?? "",
                    "name": currentUser.displayName ?? ""
                ]) { error in
                    if let error = error {
                        print("データの保存に失敗しました: \(error.localizedDescription)")
                    } else {
                        
                        if let currentUser = Auth.auth().currentUser {
                            let uid = currentUser.uid
                            db.collection("users").document(uid).collection("folders").document("all").setData([
                                "title": "all",
                                "date": FieldValue.serverTimestamp()
                            ])
                            
                            db.collection("users").document(uid).collection("folders").document("all").updateData(["title": "all","date": FieldValue.serverTimestamp()])
                        }
                        
                        print("データがFirestoreに保存されましたよ")
                    }
                }
            }
        }
        
        
        func getDate() async throws {
            DispatchQueue.main.async {
            self.dates = []
        }
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "uid is nil"])
            }
            
            let db = Firestore.firestore()
            let ref = try await db.collection("users").document(uid).collection("folders").document("all").collection("photos").order(by: "date").getDocuments()
            
            for document in ref.documents {
                let data = document.data()
                let date = data["date"] as! Timestamp
                
                let formatterDate = DateFormatter()
                formatterDate.dateFormat = "yyyy-MM-dd-HH:mm"
                let createdDate = formatterDate.string(from: date.dateValue())
                
                DispatchQueue.main.async {
                    self.dates.append(createdDate)
                }
            }
        } catch {
            throw error
        }
    }
    func getMusic(documentId: String,folder: String,friendUid: String) async throws{
        DispatchQueue.main.async {
            self.Music = []
        }
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let db = Firestore.firestore()
            
            let ref = try await db.collection("users").document(uid).collection("folders").document(folder).collection("photos").document(documentId).getDocument()
            let data = ref.data()
            let artistName =  data?["artistName"] as?String ?? "ないよ"
            let imageName =  data?["imageName"] as?String ?? "ないよ"
            let trackName =  data?["trackName"] as?String ?? "ないよ"
            let id = data?["id"] as?String ?? "ないよ"
            let previewUrl = data?["previewUrl"] as?String ?? "ないよ"
            
            DispatchQueue.main.async {
                self.Music.append(FirebaseMusic(id: documentId, artistName: artistName , imageName: imageName , trackName: trackName , trackId: id , previewURL: previewUrl )
                )
            }
            
            
            
        }
    }
    
    
    func startPlay() {
        url =  URL.init(string: Music.first!.previewURL )
        let sampleUrl = URL.init(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/8f/c1/32/8fc1329a-bf7d-03f2-3082-6536f60666ee/mzaf_1239907852510333018.plus.aac.p.m4a")
        audioPlayer = AVPlayer.init(playerItem: AVPlayerItem(url: url ?? sampleUrl! ))
        
        audioPlayer?.play()
    }
    
    
    
    func stop() {
        audioPlayer?.pause()
    }
    
    func makeFolder(folderName: String){
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let folders = UUID().uuidString
            db.collection("users").document(uid).collection("folders").document(folders).setData([
                "title": folderName,
                "date": FieldValue.serverTimestamp()
            ])
            DispatchQueue.main.async {
                self.folders.append(folderName)
                self.foldersDocumentId.append(folders)
                print(self.folders,self.foldersDocumentId)
            }
            
            db.collection("users").document(uid).collection("folders").document("all").updateData(["title": "all","date": FieldValue.serverTimestamp()])
        }
        
        
    }
    
    func getFolder()async throws{
        DispatchQueue.main.async {
            self.folders = []
        }
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            
            let ref =  try await db.collection("users").document(uid).collection("folders").order(by: "date", descending: true).getDocuments()
            for document in ref.documents {
                let data = document.data()
                let folder = data["title"] as! String
                let documentId = document.documentID
                DispatchQueue.main.async {
                    self.folders.append(folder)
                    self.foldersDocumentId.append(documentId)
                }
            }
            
        }
        
    }
    func appendFolder(folderId: Int, index: Int) {
        let db = Firestore.firestore()
        
        let document = self.documentIdArray[index]
   
        
      
            self.folderDocument = self.foldersDocumentId[folderId]
            
            print(self.foldersDocumentId,folderId,self.folderDocument,"Aa")
            
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            
            let newCollectionName = "photos"
            
            let destinationCollectionRef = db.collection("users").document(uid).collection("folders").document(folderDocument).collection(newCollectionName).document()
            
            let batch = db.batch()
            
            let sourceDocumentRef =  db.collection("users").document(uid).collection("folders").document("all").collection("photos").document(document)
            sourceDocumentRef.getDocument { (documentSnapshot, error) in
                if let error = error {
                    print("Error getting document: \(error)")
                } else if let data = documentSnapshot?.data() {
                    batch.setData(data, forDocument: destinationCollectionRef)
                    batch.commit() { err in
                        if let err = err {
                            print("バッチの書き込みエラー: \(err)")
                        } else {
                            print("データが正常にコピーされました！")
                            
                        }
                    }
                }
            }
        }
    }
    func isImageInFolder(index: Int, folderIndex: Int) -> Bool {
        let documentId = documentIdArray[index]
        return folderImages[documentId] != nil
    }
    
    
    func FoldergetUrl(folderId: Int) async throws {
        do {
            let db = Firestore.firestore()
            let uid = Auth.auth().currentUser?.uid
            var urlArray = [String]()
            
            self.folderDocument = self.foldersDocumentId[folderId]

            
            DispatchQueue.main.async {
            
                self.images = []
                self.documentIdArray = []
                self.dates  = []
                
            }
            getLetter()
            
            let ref = try await db.collection("users").document(uid!).collection("folders").document(folderDocument).collection("photos").order(by: "date").getDocuments()
            
            for document in ref.documents {
                let data = document.data()
                
                let url = data["url"]
                let date = data["date"] as! Timestamp
                
                let formatterDate = DateFormatter()
                formatterDate.dateFormat = "yyyy-MM-dd-HH:mm"
                let createdDate = formatterDate.string(from: date.dateValue())
                if url != nil {
                    urlArray.append(url as! String)
                }
                let documentId = document.documentID
                DispatchQueue.main.async {
                    self.documentIdArray.append(documentId)
                    self.dates.append(createdDate)
                    self.images = []
                    
                }
                
            }
            let storage = Storage.storage()
            let storageRef = storage.reference()
            
            
            for (index, photo) in urlArray.enumerated() {
                let imageRef = storageRef.child("images/" + photo)
                
                
                if let cachedData = photoDataCache[photo] {
                    let image = UIImage(data: cachedData)
                    DispatchQueue.main.async {
                        if index <= self.images.count {
                            self.images.insert(image!, at: index)
                        }
                    }
                } else {
                    
                    do {
                        let data = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Data, Error>) in
                            imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                } else if let data = data {
                                    continuation.resume(returning: data)
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            if index <= self.images.count {
                                let image = UIImage(data: data)
                                
                                
                                
                                self.photoDataCache[photo] = data
                                self.images.insert(image!, at: index)
                                
                            }
                            
                            else {
                                print("Index out of range. Ignoring data insertion.")
                            }
                        }
                    } catch {
                        print("Error occurred! : \(error)")
                    }
                }
                
                
                
            }
            
            try await db.collection("users").document(uid ?? "").setData(["date": FieldValue.serverTimestamp()])
            
        } catch {
            throw error
        }
    }
    func saveLetter(){
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("folders").document(folderDocument).updateData([
                "letter": userDataList
            ])
        }
    }
    func getLetter(){
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("folders").document(folderDocument).getDocument { (document, error) in
                if let document = document, document.exists {
                    let data = document.data()
                    let letter = data?["letter"] as? String ?? ""
                    self.userDataList = letter
                    
                } else {
                    print("Document does not exist")
                    DispatchQueue.main.async {
                        self.userDataList = ""
                    }
                }
            }
        }
    }
    
    func deletePhoto(document: String){
        let db = Firestore.firestore()
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("folders").document(folderDocument).collection("photos").document(document).delete()
        }
    }
    func deletefolder(){
        let db = Firestore.firestore()
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid).collection("folders").document(folderDocument).delete()
            DispatchQueue.main.async {
                
                if let indexToRemove = self.foldersDocumentId.firstIndex(where: { $0 == self.folderDocument }) {
                    
                    self.foldersDocumentId.remove(at: indexToRemove)
                    self.folders.remove(at: indexToRemove)
                }
                
            }
        }
        
    }
    func getNFCData( NFCUid: String, NFCfolderid: String)async throws{
        
        if nfc == false{
            nfc = true
            
            
            if let currentUser = Auth.auth().currentUser {
                let uid = currentUser.uid
                
                let db = Firestore.firestore()
                var urlArray = [String]()
                
                let document = try await db.collection("users").document(NFCUid).collection("folders").document(NFCfolderid).getDocument()
                let data = document.data()
                let title = data?["title"] as? String ?? "デフォルトのタイトル"
                
                
                try await db.collection("users").document(uid).collection("folders").document(NFCfolderid).setData(["title": title, "date": FieldValue.serverTimestamp()])
                DispatchQueue.main.async {
                    self.folders.append(title)
                    self.foldersDocumentId.append(NFCfolderid)
                }
                
                let destinationCollectionRef =  db.collection("users").document(uid).collection("folders").document(NFCfolderid).collection("photos")
                
                
                let sourceCollectionRef = try await db.collection("users").document(NFCUid).collection("folders").document(NFCfolderid).collection("photos").order(by: "date").getDocuments()
                
                for document in sourceCollectionRef.documents {
                    let data = document.data()
                    let DocumentID = document.documentID
                    
                    let url = data["url"]
                    if url != nil {
                        urlArray.append(url as! String)
                    }
                    let ref = try await db.collection("users").document(uid).collection("folders").document(NFCfolderid).collection("photos").document(DocumentID).getDocument()
                    let data2 = ref.data()
                    let artistName =  data2?["artistName"] as?String ?? "ないよ"
                    let imageName =  data2?["imageName"] as?String ?? "ないよ"
                    let trackName =  data2?["trackName"] as?String ?? "ないよ"
                    let id = data2?["id"] as?String ?? "ないよ"
                    let previewUrl = data2?["previewUrl"] as?String ?? "ないよ"
                    
                    DispatchQueue.main.async {
                        self.Music.append(FirebaseMusic(id: DocumentID, artistName: artistName , imageName: imageName , trackName: trackName , trackId: id , previewURL: previewUrl )
                        )
                    }
                    
                    
                    
                    destinationCollectionRef.addDocument(data: data)
                }
                
                let storage = Storage.storage()
                let storageRef = storage.reference()
                
                for (index, photo) in urlArray.enumerated() {
                    
                    
                    do {
                        let data = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Data, Error>) in
                            let imageRef = storageRef.child("images/" + photo)
                            imageRef.getData(maxSize: 100 * 1024 * 1024) { data, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                } else if let data = data {
                                    continuation.resume(returning: data)
                                }
                            }
                        }
                        
                        if index <= self.images.count {
                            let image = UIImage(data: data)
                            DispatchQueue.main.async {
                                self.images.insert(image!, at: index)
                                
                            }
                        } else {
                            print("Index out of range. Ignoring data insertion.")
                        }
                    } catch {
                        print("Error occurred! : \(error)")
                    }
                }
            }
            
        }else{
            print("2回目")
        }
        
        
        
    }
    func downloadFile(documentId: String, folderId: String) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let db = Firestore.firestore()
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let docRef = db.collection("users").document(uid).collection("folders").document(folderId).collection("photos").document(documentId)

            docRef.getDocument { document, error in
                if let error = error {
                    print("Error getting document: \(error.localizedDescription)")
                    return
                }

                if let data = document?.data(), let fileName = data["url"] as? String {
                    print("File Name: \(fileName)")
                    let storageRef = Storage.storage().reference().child("images/"+fileName)

                            storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
                                if let error = error {
                                    print("Error downloading image: \(error.localizedDescription)")
                                    return
                                }

                                if let imageData = data, let image = UIImage(data: imageData) {
                                    self.saveImageToCameraRoll(image: image)
                                }
                            }
                } else {
                    print("Document does not exist or does not contain 'url' key.")
                }
            }
        }

    }
    private func saveImageToCameraRoll(image: UIImage) {
           PHPhotoLibrary.shared().performChanges {
               PHAssetChangeRequest.creationRequestForAsset(from: image)
           } completionHandler: { success, error in
               if let error = error {
                   print("Error saving image to camera roll: \(error.localizedDescription)")
               } else {
                   print("Image saved to camera roll successfully.")
               }
           }
       }
}
