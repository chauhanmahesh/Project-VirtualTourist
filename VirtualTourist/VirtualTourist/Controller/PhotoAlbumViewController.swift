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
    
    // This variable is required to show the empty images. We can't show the message unless we are sure we don't have images for the pin. So let's wait and set this to true once we have the information.
    var hasImagesInfo: Bool = false
    
    override func viewDidLoad() {
        setupMap()
        
        newCollectionButton.setTitle("New Collection", for: UIControl.State.normal)
        
        checkIfImagesNeedToFetch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupFetchedResultsController()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        fetchedResultsController = nil
    }
       
    @IBAction func onNewCollectionTapped() {
        newCollectionButton.isEnabled = false
        if let objects = fetchedResultsController.sections?[0].objects ?? nil {
            for object in objects {
                dataController.viewContext.delete(object as! NSManagedObject)
                try? dataController.viewContext.save()
            }
        }
        // Now let's try to fetch images again.
        checkIfImagesNeedToFetch()
    }
    
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
    
    fileprivate func checkIfImagesNeedToFetch() {
        if !pinHasPhotos() {
            newCollectionButton.isEnabled = false
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
                
                self.hasImagesInfo = true
                // let's collection view reload so that we can show spinner or empty view.
                self.photosCollectionView.reloadData()
                // Let's save photos.
                self.savePhotos(photos)
            }
        } else {
            hasImagesInfo = true
            newCollectionButton.isEnabled = true
            totalImagesForPin = tappedPin.photos?.count ?? 0
        }
    }
    
   
    func savePhotos(_ photos: [PhotoModel]) {
        totalImagesForPin = photos.count
        newCollectionButton.isEnabled = true
        for photo in photos {
            downloadImageAsyncAndSave(imageToDownload: photo)
        }
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
    
    func deleteSelectedImage(_ indexPath: IndexPath) {
        dataController.viewContext.delete(fetchedResultsController.object(at: indexPath))
        try? dataController.viewContext.save()
        totalImagesForPin = totalImagesForPin - 1
    }
    
}

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if (totalImagesForPin == 0 && hasImagesInfo) {
            self.photosCollectionView.setEmptyMessage("This pin has no images 😞")
            newCollectionButton.isEnabled = false
        } else {
            newCollectionButton.isEnabled = true
            self.photosCollectionView.restore()
        }

        return totalImagesForPin//fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocationPhotoCollectionViewCell", for: indexPath) as! LocationPhotoViewCell
        
        // let's check if the image is available or not.
        if fetchedResultsController.sections?[0].numberOfObjects ?? 0 > indexPath.row {
            if let data = fetchedResultsController.object(at: indexPath).data {
                cell.locationPhoto.image = UIImage(data: data)
                cell.activityIndicator.stopAnimating()
            }
        } else {
            // Image is not available yet.
            cell.locationPhoto.image = nil
            cell.activityIndicator.startAnimating()
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        deleteSelectedImage(indexPath)
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
