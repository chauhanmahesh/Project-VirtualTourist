//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Mahesh Chauhan on 4/10/19.
//  Copyright © 2019 Mahesh Chauhan. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {
    
    @IBOutlet weak var map: MKMapView!
    
    @IBOutlet var photosCollectionView: UICollectionView!
    
    @IBOutlet var newCollectionButton: UIButton!
    
    var fetchedResultsController: NSFetchedResultsController<Image>!
    
    var tappedPin: DropppedPin!
    
    var dataController: DataController!
    
    var totalImagesForPin: Int = 0
    
    fileprivate func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<Image> = Image.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "photoId", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", tappedPin)
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "imagesFor\(tappedPin.latitude)->\(tappedPin.longitude)")
        fetchedResultsController.delegate = self
        performFetch()
    }
    
    func performFetch() {
        do {
            try fetchedResultsController.performFetch()
            photosCollectionView.reloadData()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    func setupMap() {
        let coordinate : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: tappedPin.latitude, longitude: tappedPin.longitude)
        let newPin = MKPointAnnotation()
        newPin.coordinate = coordinate
        map.addAnnotation(newPin)
        
        // And now let's setup the region.
        // Let's make the region. Before that's see if the region is actually stored.
        let locationToZoomIn = CLLocationCoordinate2DMake(tappedPin.latitude, tappedPin.longitude)
        let region = MKCoordinateRegion(center: locationToZoomIn, latitudinalMeters: 500, longitudinalMeters: 500)
        map.setRegion(region, animated: true)
    }
    
    func pinHasPhotos()-> Bool {
        return tappedPin.photos?.count ?? 0 > 0
    }
    
    override func viewDidLoad() {
        setupMap()
        
        newCollectionButton.setTitle("New Collection", for: UIControl.State.normal)
        
        if !pinHasPhotos() {
            // Let's not fetch photos again for this location.
            FlickrClient.getRecentPhotosForLocation(lat: tappedPin.latitude, lon: tappedPin.longitude) { photos, isError in
                guard let photos = photos else {
                    // not able to fetch the data.
                    return
                }
                
                guard !isError else {
                    // not able to fetch the data.
                    return
                }
                
                // Let's save photos.
                self.savePhotos(photos)
            }
        } else {
            totalImagesForPin = tappedPin.photos?.count ?? 0
        }
    }
    
    func savePhotos(_ photos: [PhotoModel]) {
        totalImagesForPin = photos.count
        // Let's reload the collectionview.
        photosCollectionView.reloadData()
        for photo in photos {
            downloadImageAsyncAndSave(imageToDownload: photo)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupFetchedResultsController()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        fetchedResultsController = nil
    }
    
    func downloadImageAsyncAndSave(imageToDownload: PhotoModel) {
        DispatchQueue.global(qos: .userInitiated).async { () -> Void in
            if let url = URL(string: imageToDownload.imageURL), let imgData = try? Data(contentsOf: url), let img = UIImage(data: imgData) {
                self.dataController.backgroundContext.perform {
                    // Let's save this image.
                    let photo = Image(context: self.dataController.backgroundContext)
                    photo.data = img.jpegData(compressionQuality: 1)
                    photo.photoId = imageToDownload.photoId
                    photo.pin = self.tappedPin
                    try? self.dataController.backgroundContext.save()
                }
            }
        }
    }
    
}

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocationPhotoCollectionViewCell", for: indexPath) as! LocationPhotoViewCell
        if let data = fetchedResultsController.object(at: indexPath).data {
            cell.locationPhoto.image = UIImage(data: data)
            cell.activityIndicator.stopAnimating()
        } else {
            cell.activityIndicator.startAnimating()
        }
        return cell
    }
    
}

extension PhotoAlbumViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let yourWidth = collectionView.bounds.width / 3.0
        let yourHeight = yourWidth

        return CGSize(width: yourWidth, height: yourHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            photosCollectionView.insertItems(at: [newIndexPath!])
        case .delete:
            photosCollectionView.deleteItems(at: [indexPath!])
        default:
            break
        }
    }
    
}

extension PhotoAlbumViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView?.animatesDrop = true
            pinView?.pinTintColor = .red
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
}
