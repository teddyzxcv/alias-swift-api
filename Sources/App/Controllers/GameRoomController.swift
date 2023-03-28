//
//  File.swift
//  
//
//  Created by ZhengWu Pan on 28.03.2023.
//

import Fluent
import Vapor

struct GameRoomController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let gameRooms = routes.grouped("game-rooms")
        let protectedGameRooms = gameRooms.grouped(UserTokenAuthenticator())
        
        protectedGameRooms.post("create", use: create)
        protectedGameRooms.get("list-all", use: listAll)
    }

    func create(req: Request) throws -> EventLoopFuture<GameRoom> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        let input = try req.content.decode(GameRoom.Create.self)
        let gameRoom = GameRoom(name: input.name, creatorID: user.id!, code: generateInvitationCode(), isPrivate: input.isPrivate)
        return gameRoom.save(on: req.db).map { gameRoom }
    }

    func listAll(req: Request) throws -> EventLoopFuture<[GameRoom]> {
        guard req.auth.has(User.self) else {
            throw Abort(.unauthorized)
        }
        return GameRoom.query(on: req.db).with(\.$creator).all()
    }

    // Private function that generate invitation code length of 5 
    private func generateInvitationCode() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<5).map{ _ in letters.randomElement()! })
    }
    


}

extension GameRoom {
    struct Create: Content {
        var name: String
        var isPrivate: Bool
    }
}

