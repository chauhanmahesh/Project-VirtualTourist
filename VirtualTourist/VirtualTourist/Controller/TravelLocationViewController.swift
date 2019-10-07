//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Mahesh Chauhan on 4/10/19.
//  Copyright © 2019 Mahesh Chauhan. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationViewController: UIViewController {
    
    @IBOutlet weak var map: MKMapView!
    
    var dataController:DataController!
    
    var droppedPins: [DropppedPin] = []
    
    var selectedPin: DropppedPin!
    
    fileprivate func setupGestures() {
        // add gesture recognizer
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(TravelLocationViewController.onLongPress(_:))) // colon needs to pass
        //add gesture recognition
        map.addGestureRecognizer(longPress)
    }
    
    fileprivate func fetchDroppedPins() {
        let fetchRequest:NSFetchRequest<DropppedPin> = DropppedPin.fetchRequest()
        if let result = try? dataController.backgroundContext.fetch(fetchRequest) {
            droppedPins = result
        }
        let mapPins: [MKPointAnnotation] = droppedPins.map {
            let coordinate : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            let newPin = MKPointAnnotation()
            newPin.coordinate = coordinate
            return newPin
        }
        // Now let's add those pins to map.
        map.addAnnotations(mapPins)
    }
    
    fileprivate func setMapRegion() {
        // Let's make the region. Before that's see if the region is actually stored.
        if UserDefaults.standard.double(forKey: UserDefaultsKey.mapCurrentLatitude) != 0 {
            let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: UserDefaults.standard.double(forKey: UserDefaultsKey.mapCurrentLatitude), longitude: UserDefaults.standard.double(forKey: UserDefaultsKey.mapCurrentLongitude)), span: MKCoordinateSpan(latitudeDelta: UserDefaults.standard.double(forKey: UserDefaultsKey.mapCurrentLatitudeDelta), longitudeDelta: UserDefaults.standard.double(forKey: UserDefaultsKey.mapCurrentLongitudeDelta)))
            map.region = region
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchDroppedPins()
        
        setMapRegion()
        
        setupGestures()
    }
    
    fileprivate func saveMapCurrentLocation() {
        let currentRegion: MKCoordinateRegion = map.region
        UserDefaults.standard.set(currentRegion.center.latitude, forKey: UserDefaultsKey.mapCurrentLatitude)
        UserDefaults.standard.set(currentRegion.center.longitude, forKey: UserDefaultsKey.mapCurrentLongitude)
        UserDefaults.standard.set(currentRegion.span.latitudeDelta, forKey: UserDefaultsKey.mapCurrentLatitudeDelta)
        UserDefaults.standard.set(currentRegion.span.longitudeDelta, forKey: UserDefaultsKey.mapCurrentLongitudeDelta)
    }
    
    fileprivate func saveDroppedPin(_ coordinate: CLLocationCoordinate2D) {
        dataController.backgroundContext.perform {
            // Also let's persist pin location
            let droppedPin = DropppedPin(context: self.dataController.backgroundContext)
            droppedPin.latitude = coordinate.latitude
            droppedPin.longitude = coordinate.longitude
            // Also let's save this in current pins.
            self.droppedPins.append(droppedPin)
            try? self.dataController.backgroundContext.save()
        }
    }
    
    @objc func onLongPress(_ recognizer: UIGestureRecognizer) {
        if(recognizer.state == UIGestureRecognizer.State.began) {
            let touchedAt = recognizer.location(in: self.map)
            let coordinate : CLLocationCoordinate2D = map.convert(touchedAt, toCoordinateFrom: self.map)
            let newPin = MKPointAnnotation()
            newPin.coordinate = coordinate
            map.addAnnotation(newPin)
            
            saveDroppedPin(coordinate)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? PhotoAlbumViewController {
            vc.dataController = dataController
            vc.tappedPin = self.selectedPin
        }
    }
    
}

extension TravelLocationViewController: MKMapViewDelegate {
    
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
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        // Let's save map current location.
        saveMapCurrentLocation()
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let matchedPin = droppedPins.first(where: { $0.latitude == view.annotation?.coordinate.latitude &&  $0.longitude == view.annotation?.coordinate.longitude}) {
            selectedPin = matchedPin
        }
        // Now let's deselect the pin so that user can tap again after coming back to this page.
        map.deselectAnnotation(view.annotation, animated: false)
        self.performSegue(withIdentifier: "showAlbum", sender: self)
    }
    
}

