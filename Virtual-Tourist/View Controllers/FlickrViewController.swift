//
//  ViewController.swift
//  Virtual-Tourist
//
//  Created by Dustin Mahone on 1/16/20.
//  Copyright © 2020 Dustin. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class FlickrViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    //MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noImagesLabel: UILabel!
    @IBOutlet weak var editCollectionButton: UIButton!
    
    //TO DO:
    // retrieve photos into array from coredata - Done
    // correct image removal selection
    // randomize the page the pictures are pulled from - Done
    // update individual pictures removed from the array
    
    //var selectedPin: Pin?
    var pinId: String?
    var pin: Pin!
    
    var fetchedResultsController:NSFetchedResultsController<Photo>!
    //var photo: Photo?
    var photos: [Photo] = []
    let spacing: CGFloat = 8
    var flickrPhotos: FlickrPhotos?
    var dataController: DataController!
    //var photoArrary: [Photo]?
    var photoArray: [UIImage] = []
    var photoDict: [UIImage:String] = [:]
    
    var page: Int = 1
    //var totalPages: Int = 1
    var perPage: Int = 21
    var imagesInCollectionView: Int = 0
    var randomNumberPage: Int?
    
    var photosSelected = false
    var selectedPhotosArray: [Int] = []
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("view did load sees \(pin.photos!.count)")
        //print(pin)
        mapView.delegate = self
        collectionView.delegate = self
        
        setupMap()
        setButton()
        setupFetchedResultsController()
        fetchMorePhotos()
        setupCollectionLayout()
        
        //new 1/30
        collectionView.allowsMultipleSelection = true
        
    }
    

    
    override func viewDidDisappear(_ animated: Bool) {
        //reset the search variables?
    }
    
    //MARK: - Methods
    func checkForPhotos() {
        
    }
    func fetchMorePhotos() {
        if /*pin.firstSearch*/ pin.photos!.count == 0 {
        //if pin.firstSearch {
            print("view did load sees \(pin.photos!.count)")
            print("running first search")
            flickrGeoSearchRedux(lat: pin.latitude, lon: pin.longitude, randomNumberPage: getRandomNumberPage())
        } else {
            print("fetching photos from data store")
            let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
            let predicate = NSPredicate(format: "pin == %@", pin)
            fetchRequest.predicate = predicate
            
            if let result = try? dataController.viewContext.fetch(fetchRequest) {
                photos = result
            }
            
            for img in photos {
                
                let photoImage = UIImage(data: img.image!)
                self.photoArray.append(photoImage!)
            }
        }
        print("there are \(photos.count) photos")
        print("there are \(pin.photos!.count) pin photos")
    }
    
    //testing began sat night
    func flickrGeoSearchRedux(lat: Double, lon: Double, randomNumberPage: Int) {
        print("flickrGeoSearchRedux")
        editCollectionButton.isEnabled = false
        photoArray.removeAll()
        
        let endpoint = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(FlickrClient.apiKey)&min_upload_date=2017-01-01+00%3A00%3A00&lat=\(lat)&lon=\(lon)&radius=0.5&per_page=\(perPage)&page=\(randomNumberPage)&format=json&nojsoncallback=1"
        let url = URL(string: endpoint)!
        
        let task = URLSession.shared.dataTask(with: url) {
            data, response, error in
            
            guard let data = data else { return }
            let decoder = JSONDecoder()
            
            //should change this to do catch
            if let searchData = try? decoder.decode(FlickrPhotos.self, from: data) {
                self.flickrPhotos = searchData
                //print(self.flickrPhotos)
                self.pin.totalPhotos = (self.flickrPhotos?.photos.total)!
                let imagesFound = Int((self.flickrPhotos?.photos.total)!)
                let pagesOfImages = (self.flickrPhotos?.photos.pages)
                //let photosFound = Int(self.pin.totalPhotos!)
                DispatchQueue.main.async {
                    if imagesFound == 0 {
                        self.noImagesLabel.isHidden = false
                        self.collectionView.reloadData()
                    } else {
                        self.noImagesLabel.isHidden = true
                    }
                }
            }
            
            for img in (self.flickrPhotos?.photos.photo)! {
                let url = img.photoUrl
                let id = img.photoId
                
                if let imageData = try? Data(contentsOf: url as URL) {
                    //print(imageData)
                    self.addPhoto(data: imageData, id: id)
                    let photoImage = UIImage(data: imageData)
                    self.photoArray.append(photoImage!)
                    self.photoDict.updateValue(id, forKey: photoImage!)
                    DispatchQueue.main.async {
                        self.collectionView.reloadData()
                    }
                }
            }
        }
        task.resume()
        pin.firstSearch = false
        editCollectionButton.isEnabled = true
        print("photoDict is \(photoDict)")
    }
    
    func getAvailableCellCount() -> Int {
        let number = 21 - photos.count
        print("available cells is \(number)")
        return 21 - photos.count
    }
    
    func setupCollectionLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        self.collectionView?.collectionViewLayout = layout
    }

    func addPhoto(data: Data, id: String) {
        let photo = Photo(context: dataController.viewContext)
        photo.image = data
        photo.photoId = Double(id)!
        photo.pin = pin
        try? dataController.viewContext.save()
        
    }
    
    
    
    
    func deleteAllPhotos() {
        //disable button while function is running
        guard let photos = pin.photos else { return }
        print("delete all photos sees \(pin.photos!.count) photos")
        if let photos = fetchedResultsController.fetchedObjects {
            for photo in photos {
                print("deleting photo")
                fetchedResultsController.managedObjectContext.delete(photo)
            
                guard fetchedResultsController.managedObjectContext.hasChanges else {
                    print("save failed")
                    return
                    
                }
                
            }
            do {
                try fetchedResultsController.managedObjectContext.save()
            } catch {
                //print("The fetch could not be performed: \(error.localizedDescription)")
                showAlert(title: "Data did not save", message: "Please try again")
            }
            
        }
        flickrGeoSearchRedux(lat: pin.latitude, lon: pin.longitude, randomNumberPage: getRandomNumberPage())
    }
    
    func deletePhoto() {
        
        var reverseArray = selectedPhotosArray.sorted { $0 > $1 }
        
        //let nextToDelete = selectedPhotosArray.max()
        if let photos = fetchedResultsController.fetchedObjects {
            
            for photo in photos {
                
                fetchedResultsController.managedObjectContext.delete(photo)
            }

            do {
                try fetchedResultsController.managedObjectContext.save()
            } catch {
                //print("The fetch could not be performed: \(error.localizedDescription)")
                showAlert(title: "Data did not save", message: "Please try again")
            }
            
        }
        fetchMorePhotos()
        
    }
    
    func setupMap() {
        guard pin.pinId != nil else { return }
        let mapLatitude = CLLocationDegrees(pin.latitude)
        let mapLongitude = CLLocationDegrees(pin.longitude)
        let coordinate = CLLocationCoordinate2D(latitude: mapLatitude, longitude: mapLongitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        self.mapView.addAnnotation(annotation)
        
        let center = CLLocationCoordinate2DMake(mapLatitude, mapLongitude)
        mapView.setCenter(center, animated: false)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.16)
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.region = region
        mapView.isUserInteractionEnabled = false
    }
    
    func setButton() {
        if selectedPhotosArray.count >= 1 {
            photosSelected = true
            editCollectionButton.titleLabel?.adjustsFontSizeToFitWidth = true
            editCollectionButton.titleLabel?.adjustsFontSizeToFitWidth = false
            editCollectionButton.titleLabel?.text = "Remove Selected Photos"
        } else if selectedPhotosArray.count == 0 {
            photosSelected = false
            editCollectionButton.titleLabel?.text = "New Collection"
        }
    }
    
    func getRandomNumberPage() -> Int {
        let totalPhotosString = pin.totalPhotos! //get the total number of photos
        let totalPhotosInt = Int(totalPhotosString)! //convert total into an Int, currently defaults to 21 in the Pin Entity in core data
        let imagesNeededToFillArray = perPage //determine how many images we want from the search
        let totalPages = totalPhotosInt / imagesNeededToFillArray //determing the total number of pages available
        
        if pin.firstSearch {
            return 1
        } else {
            return Int.random(in: 1 ... totalPages) //generate a random page number to grab pics from
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)

        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { _ in
            self.editCollectionButton.isEnabled = true
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
        
    @IBAction func editCollectionButtonPressed(_ sender: Any) {
        if selectedPhotosArray.isEmpty {
            deleteAllPhotos()
            } else {
            deletePhoto()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "reuseIdentifier", for: indexPath) as! FlickrCell
        if photoArray.count == 0 {
            //
        }
        if photoArray.count >= 1 {
            cell.imageView.image = UIImage(named: "cellLoading")
            cell.activityIndicatorView.isHidden = false
            cell.activityIndicatorView.startAnimating()
            let photoImage = photoArray[indexPath.row]
            cell.imageView.image = photoImage
            cell.imageView.contentMode = .scaleAspectFill
            cell.activityIndicatorView.stopAnimating()
            cell.imageView.alpha = 1.0
        }/*
        if photoDict.count >= 1 {
            cell.imageView.image = UIImage(named: "cellLoading")
            cell.activityIndicatorView.isHidden = false
            cell.activityIndicatorView.startAnimating()
            let photoImage = photoDict[indexPath.row]
            cell.imageView.image = photoImage
            cell.imageView.contentMode = .scaleAspectFill
            cell.activityIndicatorView.stopAnimating()
            cell.imageView.alpha = 1.0
        }*/
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        selectedPhotosArray.append(indexPath.row)
        //selectedPhotosArray.append(contentsOf: indexPath)
        /*
        if selectedPhotosArray.contains(cellNumber) == false {
            let cell = collectionView.cellForItem(at: indexPath)
            cell?.alpha = 0.5
            selectedPhotosArray.append(indexPath.row)
                        
        } else if selectedPhotosArray.contains(cellNumber) {
            let cell = collectionView.cellForItem(at: indexPath)
            cell?.alpha = 1.0
            selectedPhotosArray = selectedPhotosArray.filter { $0 != cellNumber }
        }
        */
        print(selectedPhotosArray)
        setButton()
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        //let cellToRemove = "\(indexPath.row)"
        var itemToRemove = indexPath.row
        if let index = selectedPhotosArray.index(of: itemToRemove) {
            selectedPhotosArray.remove(at: index)
        }
        print(selectedPhotosArray)
        
    }

    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
      
        let numberOfItemsPerRow:CGFloat = 3
        let spacingBetweenCells:CGFloat = 8
        let totalSpacing = (2 * spacing) + ((numberOfItemsPerRow - 1) * spacingBetweenCells)
        
        guard let collection = self.collectionView else { return CGSize(width: 0, height: 0)}
        let width = (collection.bounds.width - totalSpacing)/numberOfItemsPerRow
        
        return CGSize(width: width, height: width)

    }
    
    
}

//MARK: - Extensions
extension FlickrViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let pinIdentifier = "pinIdentifier"
        let pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: pinIdentifier)
        pinView.annotation = annotation
        return pinView
    }
}

extension FlickrViewController: NSFetchedResultsControllerDelegate {
    fileprivate func setupFetchedResultsController() {
        let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", pin)
        fetchRequest.predicate = predicate
        
        let sortDescriptor = NSSortDescriptor(key: "photoId", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "\(pin)-photos")
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
}




