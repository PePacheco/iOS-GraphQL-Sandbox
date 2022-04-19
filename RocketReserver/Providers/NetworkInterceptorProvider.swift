//
//  NetworkInterceptorProvider.swift
//  RocketReserver
//
//  Created by pedro.pacheco on 18/04/22.
//  Copyright © 2022 Apollo GraphQL. All rights reserved.
//

import Foundation
import Apollo

class NetworkInterceptorProvider: DefaultInterceptorProvider {
    override func interceptors<Operation>(for operation: Operation) -> [ApolloInterceptor] where Operation : GraphQLOperation {
        var interceptors = super.interceptors(for: operation)
        interceptors.insert(TokenAddingInterceptor(), at: 0)
        return interceptors
    }
}
