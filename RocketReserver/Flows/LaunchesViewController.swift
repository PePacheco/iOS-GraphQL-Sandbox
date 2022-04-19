//
//  LaunchesViewController.swift
//  RocketReserver
//
//  Created by Ellen Shapiro on 11/13/19.
//  Copyright © 2019 Apollo GraphQL. All rights reserved.
//

import UIKit
import SDWebImage
import Apollo

enum ListSection: Int, CaseIterable {
    case launches
    case loading
}

class LaunchesViewController: UITableViewController {
    
    var detailViewController: DetailViewController? = nil
    private var launches = [LaunchListQuery.Data.Launch.Launch]()
    private var currentConnection: LaunchListQuery.Data.Launch?
    private var activeRequest: Cancellable?
    private var activeSubscription: Cancellable?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.loadMoreLaunchesIfTheyExist()
        // self.startSubscriptions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }
    
    // MARK: - Segues
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showProfile" {
            return true
        }
        
        guard let selectedIndexPath = self.tableView.indexPathForSelectedRow,
              let listSection = ListSection(rawValue: selectedIndexPath.section)
        else {
            return false
        }
        
        switch listSection {
        case .launches:
            return true
        case .loading:
            if self.activeRequest == nil {
                self.loadMoreLaunchesIfTheyExist()
            }
            self.tableView.reloadRows(at: [selectedIndexPath], with: .automatic)
            return false
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showProfile" {
            return
        }
        
        guard let selectedIndexpath = self.tableView.indexPathForSelectedRow,
              let listSection = ListSection(rawValue: selectedIndexpath.section)
        else {
            return
        }
        
        switch listSection {
        case .launches:
            guard let destination = segue.destination as? UINavigationController,
                  let detail = destination.topViewController as? DetailViewController else {
                    assertionFailure("Wrong kind of destination")
                    return
            }
            let launch = self.launches[selectedIndexpath.row]
            detail.launchID = launch.id
        
            self.detailViewController = detail
        case .loading:
            break
        }
    }
    
    // MARK: - Functionalities
    
    private func loadLaunches() {
        NetworkClient.shared.apollo.fetch(query: LaunchListQuery()) { [weak self] result in
            print(result)
           guard let self = self else {
             return
           }

           defer {
             self.tableView.reloadData()
           }
                   
           switch result {
           case .success(let graphQLResult):
               if let launchConnection = graphQLResult.data?.launches {
                   self.currentConnection = launchConnection
                   self.launches.append(contentsOf: launchConnection.launches.compactMap { $0 })
               }
               
               if let errors = graphQLResult.errors {
                   let message = errors
                           .map { $0.localizedDescription }
                           .joined(separator: "\n")
                   self.showAlert(title: "GraphQL Error(s)", message: message)
               }
               
           case .failure(let error):
             self.showAlert(title: "Network Error",
                            message: error.localizedDescription)
           }
         }
    }
    
    private func loadMoreLaunchesIfTheyExist() {
        guard let connection = self.currentConnection else {
            self.loadLaunches()
            return
        }
        
        guard connection.hasMore else {
            return
        }
        
        self.loadMoreLaunches(from: connection.cursor)
    }
    
    private func loadMoreLaunches(from cursor: String?) {
        NetworkClient.shared.apollo.fetch(query: LaunchListQuery(cursor: cursor)) { [weak self] result in
           guard let self = self else {
             return
           }

           defer {
             self.tableView.reloadData()
           }
                   
           switch result {
           case .success(let graphQLResult):
               if let launchConnection = graphQLResult.data?.launches {
                   self.currentConnection = launchConnection
                   self.launches.append(contentsOf: launchConnection.launches.compactMap { $0 })
               }
               
               if let errors = graphQLResult.errors {
                   let message = errors
                           .map { $0.localizedDescription }
                           .joined(separator: "\n")
                   self.showAlert(title: "GraphQL Error(s)", message: message)
               }
               
           case .failure(let error):
             self.showAlert(title: "Network Error",
                            message: error.localizedDescription)
           }
         }
    }
    
    // MARK: - Subscriptions
    
    private func startSubscriptions() {
        activeSubscription = NetworkClient.shared.apollo.subscribe(subscription: TripsBookedSubscription(), resultHandler: { result in
            switch result {
            case .success(let graphQLResult):
                if let errors = graphQLResult.errors {
                    self.showAlertForErrors(errors)
                } else if let tripsBooked = graphQLResult.data?.tripsBooked {
                    self.handleTripsBooked(value: tripsBooked)
                } else {
                    
                }
                
            case .failure(let error):
                self.showAlert(title: "Network Error", message: error.localizedDescription)
            }
        })
    }
    
    private func handleTripsBooked(value: Int) {
        let message = "A new trip was booked! 🚀"
        NotificationView.show(in: self.navigationController!.view,
                                     with: message,
                                     for: 4.0)
    }
    
    
    // MARK: - IBActions
    
    @IBAction private func launchTypeSelectorTapped(_ sender: UISegmentedControl) {
        // TODO: In the future, actually have this do something.
        sender.selectedSegmentIndex = 0
    }
    
    @IBAction private func profileTapped() {
        self.performSegue(withIdentifier: "showProfile", sender: nil)
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return ListSection.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = ListSection(rawValue: section) else {
            return 0
        }
        switch section {
        case .launches:
            return launches.count
        case .loading:
            if self.currentConnection?.hasMore == false {
                return 0
            } else {
                return 1
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = nil
        cell.imageView?.image = nil
        cell.detailTextLabel?.text = nil
        
        guard let section = ListSection(rawValue: indexPath.section) else {
            return cell
        }
        
        switch section {
        case .launches:
            let launch = launches[indexPath.row]
            cell.textLabel?.text = launch.site
            cell.detailTextLabel?.text = launch.site
            
            let placeholder = UIImage(named: "placeholder")
            
            if let missionPatch = launch.mission?.missionPatch {
                cell.imageView?.sd_setImage(with: URL(string: missionPatch), placeholderImage: placeholder)
            } else {
                cell.imageView?.image = placeholder
            }
        case .loading:
            if self.activeRequest == nil {
                cell.textLabel?.text = "Tap to load more"
            } else {
                cell.textLabel?.text = "Loading"
            }
        }
        
        return cell
    }
}

