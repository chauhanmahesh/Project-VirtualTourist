//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Mahesh Chauhan on 5/10/19.
//  Copyright © 2019 Mahesh Chauhan. All rights reserved.
//

import Foundation

class FlickrClient {
    
    static let apiKey = "c4da2568bcbe278964d1f4e17c7e6d3a"
    
    enum Endpoints {
        static let base = "https://api.flickr.com/services/rest"
        static let apiKeyParam = "?api_key=\(FlickrClient.apiKey)"
        
        case getRecentPhotosForLocation(Double, Double)
        case getSizes(String)
        
        var stringValue: String {
            switch self {
            case .getRecentPhotosForLocation(let lat, let lon): return Endpoints.base + Endpoints.apiKeyParam + "&method=flickr.photos.search&lat=\(lat)&lon=\(lon)&per_page=21&format=json&nojsoncallback=?"
            case .getSizes(let photoId): return Endpoints.base + Endpoints.apiKeyParam + "&method=flickr.photos.getSizes&photo_id=\(photoId)&format=json&nojsoncallback=?"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    class func getRecentPhotosForLocation(lat: Double, lon: Double, completion: @escaping ([PhotoModel]?, Bool) -> Void) {
        taskForGETRequest(url: Endpoints.getRecentPhotosForLocation(lat, lon).url, responseType: SearchPhotosResponse.self) { (response, error) in
            if let response = response {
                var photosCount = response.photos.photo.count
                guard photosCount > 0 else {
                    completion([], false)
                    return
                }
                // Let's get the url's for each photo.
                var photosUrl: [PhotoModel] = []
                for photo in response.photos.photo {
                    let photoId = photo.id
                    getSizes(photoId: photoId) { response, isError in
                        if let sourceurl = response?.sizes.size[1].source {
                            photosUrl.append(PhotoModel(photoId: photoId, imageURL: sourceurl))
                        } else {
                            photosCount = photosCount - 1
                        }
                        // If we got the url's for each photoId, let's send the response back.
                        if photosCount == photosUrl.count {
                            completion(photosUrl, false)
                        }
                     }
                }
            } else {
                completion(nil, true)
            }
        }
    }
    
    private class func getSizes(photoId: String, completion: @escaping (SizesResponse?, Bool) -> Void) {
        taskForGETRequest(url: Endpoints.getSizes(photoId).url, responseType: SizesResponse.self) { (response, error) in
            if let response = response {
                completion(response, false)
            } else {
                completion(nil, true)
            }
        }
    }
    
    @discardableResult class func taskForGETRequest<ResponseType: Decodable>(url: URL, responseType: ResponseType.Type, completion: @escaping (ResponseType?, Bool) -> Void) -> URLSessionTask {
        print("url : \(url)")
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, true)
                }
                return
            }
            let decoder = JSONDecoder()
            do {
                let updatedResponse = data
                let responseObject = try decoder.decode(ResponseType.self, from: data)
                DispatchQueue.main.async {
                    print("getSizes updatedResponse : \(responseObject)")
                    completion(responseObject, false)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, true)
                }
            }
        }
        task.resume()
        
        return task
    }
    
}
