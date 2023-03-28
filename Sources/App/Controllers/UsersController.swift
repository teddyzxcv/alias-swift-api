//
//  File.swift
//  
//
//  Created by ZhengWu Pan on 28.03.2023.
//

import Foundation
import Fluent
import Vapor
import Crypto

struct UsersController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.post("register", use: register)
        users.post("login", use: login)
        
        let protectedUsers = users.grouped(UserTokenAuthenticator())
        protectedUsers.get("profile", use: getProfile)
    }
    
    func register(req: Request) throws -> EventLoopFuture<User> {
        try User.Create.validate(content: req)
        let input = try req.content.decode(User.Create.self)
        
        let passwordHash = try Bcrypt.hash(input.password)
        let user = User(name: input.name, email: input.email, passwordHash: passwordHash)
        return user.save(on: req.db).map { user }
    }
    
    func login(req: Request) throws -> EventLoopFuture<UserToken> {
        try User.Login.validate(content: req)
        let input = try req.content.decode(User.Login.self)
        
        return User.query(on: req.db)
            .filter(\.$email == input.email)
            .first()
            .flatMap { user in
                guard let user = user else {
                    return req.eventLoop.future(error: Abort(.unauthorized))
                }
                
                do {
                    if try Bcrypt.verify(input.password, created: user.passwordHash) {
                        let token = try self.generateToken()
                        let userToken = UserToken(userID: user.id!, value: token)
                        return userToken.save(on: req.db).transform(to: userToken)
                    } else {
                        return req.eventLoop.future(error: Abort(.unauthorized))
                    }
                } catch {
                    return req.eventLoop.future(error: Abort(.internalServerError))
                }
            }
    }
    
    // Add the getProfile function in the UsersController
    func getProfile(req: Request) throws -> EventLoopFuture<String> {
        // You can safely access the authenticated user since the middleware has already checked for the token.
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        return req.eventLoop.future(user.name)
    }
    
    
    // MARK: Private section.
    
    private func generateToken() throws -> String {
        let token = SymmetricKey(size: .bits256)
        let tokenString = token.withUnsafeBytes { body in
            Data(body).base64EncodedString()
        }
        return tokenString
    }
}
