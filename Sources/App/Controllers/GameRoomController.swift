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
        let gameRoom = GameRoom(name: input.name,
                                creatorID: user.id!,
                                code: generateInvitationCode(),
                                isPrivate: input.isPrivate,
                                adminID: user.id!)
        return gameRoom.save(on: req.db).map { gameRoom }
    }

    func listAll(req: Request) throws -> EventLoopFuture<[GameRoom.Public]> {
        guard req.auth.has(User.self) else {
            throw Abort(.unauthorized)
        }
        return GameRoom.query(on: req.db)
            .filter(\.$isPrivate == false)
            .with(\.$creator)
            .with(\.$admin)
            .all().flatMapThrowing { gameRooms in
            gameRooms.map { gameRoom in
                return GameRoom.Public(id: gameRoom.id,
                                       name: gameRoom.name,
                                       creator: gameRoom.creator.name,
                                       isPrivate: gameRoom.isPrivate,
                                       invitationCode: gameRoom.invitationCode,
                                       admin: gameRoom.admin.name)
            }
        }
    }

    // Private function that generate invitation code length of 5 
    private func generateInvitationCode() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<5).map{ _ in letters.randomElement()! })
    }
    


}



extension GameRoom {
    struct Public: Content {
        var id: UUID?
        var name: String
        var creator: String
        var isPrivate: Bool
        var invitationCode: String
        var admin: String
    }
    struct Create: Content {
        var name: String
        var isPrivate: Bool
    }
}

