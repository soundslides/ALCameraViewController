//
//  ALImageFetchingInteractor.swift
//  ALImagePickerViewController
//
//  Created by Alex Littlejohn on 2015/06/09.
//  Copyright (c) 2015 zero. All rights reserved.
//

import UIKit
import Photos

public typealias ALImageFetchingInteractorSuccess = (assets: [PHAsset]) -> ()
public typealias ALImageFetchingInteractorFailure = (error: NSError) -> ()

extension PHFetchResult: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

public class ALImageFetchingInteractor {

    private var success: ALImageFetchingInteractorSuccess? = nil
    private var failure: ALImageFetchingInteractorFailure? = nil
    
    private var authRequested = false
    private let errorDomain = "com.zero.imageFetcher"
  
    public func onSuccess(success: ALImageFetchingInteractorSuccess) -> Self {
        self.success = success
        return self
    }
    
    public func onFailure(failure: ALImageFetchingInteractorFailure) -> Self {
        self.failure = failure
        return self
    }
    
    public func fetch() -> Self {
        handleAuthorization(PHPhotoLibrary.authorizationStatus())
        return self
    }
  
    public func fetch(localIdentifiers: [String]) -> Self {
      
      // local identifiers can include slashes if they come from an asset
      let lids = localIdentifiers.map { $0.componentsSeparatedByString("/").first ?? $0 }
      
      handleAuthorization(PHPhotoLibrary.authorizationStatus(), localIdentifiers: lids)
      return self
    }
    
    private func onAuthorized(localIdentifiers: [String]? = nil) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
          let assets = (localIdentifiers != nil) ?
            PHAsset.fetchAssetsWithLocalIdentifiers(localIdentifiers!, options: options) :
            PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: options)
            var imageAssets = [PHAsset]()
            for asset in assets {
                imageAssets.append(asset as! PHAsset)
            }
            dispatch_async(dispatch_get_main_queue()) {
              if assets.count > 0 {
                self.success?(assets: imageAssets)
              }else{
                self.noAssetsFetched()
              }
            }
        }
    }
  
    private func noAssetsFetched() {
      let errorString = NSLocalizedString("error.zero-assets-found", tableName: StringsTableName, comment: "error.zero-assets-found")
      let errorInfo = [NSLocalizedDescriptionKey: errorString]
      let error = NSError(domain: errorDomain, code: 0, userInfo: errorInfo)
      failure?(error: error)
    }
  
    private func onDeniedOrRestricted() {
        let errorString = NSLocalizedString("error.access-denied", tableName: StringsTableName, comment: "error.access-denied")
        let errorInfo = [NSLocalizedDescriptionKey: errorString]
        let error = NSError(domain: errorDomain, code: 0, userInfo: errorInfo)
        failure?(error: error)
    }
    
    private func handleAuthorization(status: PHAuthorizationStatus, localIdentifiers: [String]? = nil) -> Void {
      switch status {
      case .NotDetermined:
        if !authRequested {
          PHPhotoLibrary.requestAuthorization { status in
            self.handleAuthorization(status, localIdentifiers: localIdentifiers)
          }
          authRequested = true
        } else {
          onDeniedOrRestricted()
        }
        break
      case .Authorized:
        onAuthorized(localIdentifiers)
        break
      case .Denied, .Restricted:
        onDeniedOrRestricted()
        break
      }
    }
}
