//
//  File.swift
//  
//
//  Created by ZhengWu Pan on 28.03.2023.
//

import Vapor
import Fluent

struct UserTokenAuthenticator: BearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
        UserToken.query(on: request.db)
            .filter(\.$value == bearer.token)
            .with(\.$user)
            .first()
            .map { userToken in
                if let user = userToken?.user {
                    request.auth.login(user)
                }
            }
    }
}
