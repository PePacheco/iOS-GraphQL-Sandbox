//
//  DetailViewController.swift
//  RocketReserver
//
//  Created by Ellen Shapiro on 11/13/19.
//  Copyright © 2019 Apollo GraphQL. All rights reserved.
//

import UIKit
import Apollo
import KeychainSwift

class DetailViewController: UIViewController {
    
    @IBOutlet private var missionPatchImageView: UIImageView!
    @IBOutlet private var missionNameLabel: UILabel!
    @IBOutlet private var rocketNameLabel: UILabel!
    @IBOutlet private var launchSiteLabel: UILabel!
    @IBOutlet private var bookCancelButton: UIBarButtonItem!
    
    var launchID: GraphQLID? {
        didSet {
            self.loadLaunchDetails(forceReload: false)
        }
    }
    
    private var launch: LaunchDetailsQuery.Data.Launch? {
        didSet {
            self.configureView()
        }
    }
    
    func configureView() {
        guard self.missionNameLabel != nil,
              let launch = self.launch else {
            return
        }
        
        self.missionNameLabel.text = launch.mission?.name
        self.title = launch.mission?.name

        let placeholder = UIImage(named: "placeholder")!
            
        if let missionPatch = launch.mission?.missionPatch {
            self.missionPatchImageView.sd_setImage(with: URL(string: missionPatch)!, placeholderImage: placeholder)
        } else {
            self.missionPatchImageView.image = placeholder
        }

        if let site = launch.site {
            self.launchSiteLabel.text = "Launching from \(site)"
        } else {
            self.launchSiteLabel.text = nil
        }
            
        if
          let rocketName = launch.rocket?.name ,
          let rocketType = launch.rocket?.type {
            self.rocketNameLabel.text = "🚀 \(rocketName) (\(rocketType))"
        } else {
            self.rocketNameLabel.text = nil
        }
            
        if launch.isBooked {
            self.bookCancelButton.title = "Cancel trip"
            self.bookCancelButton.tintColor = .red
        } else {
            self.bookCancelButton.title = "Book now!"
            self.bookCancelButton.tintColor = UIApplication.shared.windows.first?.tintColor
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.missionNameLabel.text = "Loading..."
        self.launchSiteLabel.text = nil
        self.rocketNameLabel.text = nil
        self.configureView()
    }
    
    private func loadLaunchDetails(forceReload: Bool) {
        guard
           let launchID = self.launchID,
           (forceReload || launchID != self.launch?.id) else {
             return
         }
        
        let cachePolicy: CachePolicy
        
        if forceReload {
            cachePolicy = .fetchIgnoringCacheData
        } else {
            cachePolicy = .returnCacheDataElseFetch
        }
           
         NetworkClient.shared.apollo.fetch(query: LaunchDetailsQuery(launchId: launchID), cachePolicy: cachePolicy) { [weak self] result in
           guard let self = self else {
             return
           }
           
           switch result {
           case .failure(let error):
             self.showAlert(title: "Network Error",
                            message: error.localizedDescription)
           case .success(let graphQLResult):
             if let launch = graphQLResult.data?.launch {
               self.launch = launch
             }
           
             if let errors = graphQLResult.errors {
               let message = errors
                               .map { $0.localizedDescription }
                               .joined(separator: "\n")
               self.showAlert(title: "GraphQL Error(s)",
                              message: message)
             }
           }
         }
    }
    
    @IBAction private func bookOrCancelTapped() {
        guard self.isLoggedIn() else {
            self.performSegue(withIdentifier: "showLogin", sender: self)
            return
        }
        
        guard let launch = self.launch,
              let id = launchID
        else {
            return
        }
        
        if launch.isBooked {
            self.cancelTrip(with: id)
        } else {
            self.bookTrip(with: id)
        }
    }
    
    private func bookTrip(with id: GraphQLID) {
        NetworkClient.shared.apollo.perform(mutation: BookTripMutation(id: id)) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let graphQLResult):
                if let bookingResult = graphQLResult.data?.bookTrips {
                    if bookingResult.success {
                        self.showAlert(title: "Success!",
                                  message: bookingResult.message ?? "Trips booked successfully.")
                    } else {
                        self.showAlert(title: "Could not book tripe",
                                  message: bookingResult.message ?? "Unknown failure.")
                    }
                }
                
                if let errors = graphQLResult.errors {
                    self.showAlertForErrors(errors)
                }
                
                self.loadLaunchDetails(forceReload: true)
                
            case .failure(let error):
                self.showAlert(title: "Network Error", message: error.localizedDescription)
            }
        }
    }
    
    private func cancelTrip(with id: GraphQLID) {
        NetworkClient.shared.apollo.perform(mutation: CancelTripMutation(launchId: id)) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let graphQLResult):
                if let cancelResult = graphQLResult.data?.cancelTrip {
                    if cancelResult.success {
                        self.showAlert(title: "Trip cancelled",
                                       message: cancelResult.message ?? "Your trip has been cancelled.")
                    } else {
                        self.showAlert(title: "Could not cancel trip",
                                       message: cancelResult.message ?? "Unknown failure.")
                    }
                }
                
                if let errors = graphQLResult.errors {
                    self.showAlertForErrors(errors)
                }
                
                self.loadLaunchDetails(forceReload: true)
                
            case .failure(let error):
                self.showAlert(title: "Network Error", message: error.localizedDescription)
            }
        }
    }
    
    private func isLoggedIn() -> Bool {
        let keychain = KeychainSwift()
        return keychain.get(LoginViewController.loginKeychainKey) != nil
    }
}

