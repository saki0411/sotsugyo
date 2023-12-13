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
    @Published internal var folders = []
    @Published internal var foldersDocumentId = [String]()
    @Published var folderImages: [String: [UIImage]] = [:]
    @Published internal var getimage = false
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
            
            let ref = try await db.collection("users").document(uid).collection("photo").order(by: "date").getDocuments()
            
            for document in ref.documents {
                let data = document.data()
                let url = data["url"]
                if url != nil {
                    urlArray.append(url as! String)
                }
                let documentId = document.documentID
                DispatchQueue.main.async {
                    self.documentIdArray.append(documentId)
                    print("取得してます")
                    
                }
            }
            
            let storage = Storage.storage()
            let storageRef = storage.reference()
            for (index, photo) in urlArray.enumerated() {
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
                    let image = UIImage(data: data)
                    DispatchQueue.main.async {
                        self.images.insert(image!, at: index)
                    }
                } catch {
                    print("Error occurred! : \(error)")
                }
            }
            
            
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
                let ref = try await db.collection("users").document(uid ?? "").collection("photo").whereField("date", isGreaterThanOrEqualTo: date as Any).order(by: "date").getDocuments()
                
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
                
                for (_, photo) in urlArray.enumerated() {
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
                        
                        let image = UIImage(data: data)
                        DispatchQueue.main.async {
                            self.images.append(image!)
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
    
    
    func saveUserData(){
        
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            db.collection("users").document(uid ).collection("personal").document("info").setData([
                "uid": uid ,
                "email": currentUser.email ?? "",
                "name": currentUser.displayName ?? ""
            ]) { error in
                if let error = error {
                    print("データの保存に失敗しました: \(error.localizedDescription)")
                } else {
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
            let ref = try await db.collection("users").document(uid).collection("photo").order(by: "date").getDocuments()
            
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
    func getMusic(documentId: String) async throws{
        DispatchQueue.main.async {
            self.Music = []
        }
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let db = Firestore.firestore()
            let ref = try await db.collection("users").document(uid).collection("photo").document(documentId).getDocument()
            let data = ref.data()
            let artistName =  data?["artistName"]
            let imageName =  data?["imageName"]
            let trackName =  data?["trackName"]
            let id = data?["id"]
            let previewUrl = data?["previewUrl"]
            DispatchQueue.main.async {
                self.Music.append(FirebaseMusic(id: documentId, artistName: artistName as! String, imageName: imageName as! String, trackName: trackName as! String, trackId: id as! String, previewURL: previewUrl as! String)
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
                "title": folderName
            ])
            DispatchQueue.main.async {
                self.folders.append(folders)
                self.foldersDocumentId.append(folders)
            }
        }
        
        
    }
  
    func getFolder()async throws{
        DispatchQueue.main.async {
            self.folders = []
        }
        let db = Firestore.firestore()
        
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            
            let ref =  try await db.collection("users").document(uid).collection("folders").getDocuments()
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
    func appendFolder(folderId: Int, index: Int,selectedFolderIndex: Binding<Int>) {
        let db = Firestore.firestore()
        let document = documentIdArray[index]
        let folderDocument = foldersDocumentId[folderId]

        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid

            // 新しいコレクション名
            let newCollectionName = "photos"

            // 新しいコレクションのドキュメントリファレンスを作成
            let destinationCollectionRef = db.collection("users").document(uid).collection("folders").document(folderDocument).collection(newCollectionName).document()

            // バッチを新しく作成
            let batch = db.batch()

            // "photo" コレクションからデータを取得して新しいコレクションに追加
            let sourceDocumentRef = db.collection("users").document(uid).collection("photo").document(document)
            sourceDocumentRef.getDocument { (documentSnapshot, error) in
                if let error = error {
                    print("Error getting document: \(error)")
                } else if let data = documentSnapshot?.data() {
                    // 対応する document のデータを新しいコレクション内の新しいドキュメントにセット
                    batch.setData(data, forDocument: destinationCollectionRef)

                    // バッチをコミット
                    batch.commit() { err in
                        if let err = err {
                            print("バッチの書き込みエラー: \(err)")
                        } else {
                            print("データが正常にコピーされました！")
                            selectedFolderIndex.wrappedValue = folderId
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
        print("A")
        do {
            let db = Firestore.firestore()
            let uid = Auth.auth().currentUser?.uid
            var urlArray = [String]()
            let folderDocument = foldersDocumentId[folderId]
            DispatchQueue.main.async {
                self.images = []
                self.documentIdArray = []
                self.dates  = []
            }
            let ref = try await db.collection("users").document(uid!).collection("folders").document(folderDocument).collection("photos").getDocuments()

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
                }

                let storage = Storage.storage()
                let storageRef = storage.reference()

                for (_, photo) in urlArray.enumerated() {
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

                        let image = UIImage(data: data)
                        DispatchQueue.main.async {
                            self.images.append(image!)
                            print(image!)
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

}

