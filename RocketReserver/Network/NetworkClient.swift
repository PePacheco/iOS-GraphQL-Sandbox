//
//  NetworkClient.swift
//  RocketReserver
//
//  Created by pedro.pacheco on 14/04/22.
//  Copyright © 2022 Apollo GraphQL. All rights reserved.
//

import Foundation
import Apollo
import ApolloWebSocket

class NetworkClient {
  static let shared = NetworkClient()
    
    private (set) lazy var apollo: ApolloClient = {
        // MARK: - Http Transport
        let client = URLSessionClient()
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)
        let provider = NetworkInterceptorProvider(store: store)
        let url = URL(string: "https://apollo-fullstack-tutorial.herokuapp.com/graphql")!
        let transport = RequestChainNetworkTransport(interceptorProvider: provider, endpointURL: url)
        
        // MARK: - WebSocket Transport
        let webSocket = WebSocket(url: URL(string: "https://apollo-fullstack-tutorial.herokuapp.com/graphql")!,
                                  protocol: .graphql_ws)
        let webSocketTransport = WebSocketTransport(websocket: webSocket)
        let splitTransport = SplitNetworkTransport(uploadingNetworkTransport: transport,
                                                   webSocketNetworkTransport: webSocketTransport)
        
        return ApolloClient(networkTransport: splitTransport, store: store)
    }()
}
