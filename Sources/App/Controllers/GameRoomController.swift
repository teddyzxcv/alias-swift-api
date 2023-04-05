//
//  GameRoomController.swift
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
        protectedGameRooms.post("join-room", use: joinGameRoom)
        protectedGameRooms.post("change-setting", use: updateGameRoom)
        protectedGameRooms.get("list-members", use: listMembersForGameRoom)
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
                                adminID: user.id!,
                                pointsPerWord: 10)
        return gameRoom.save(on: req.db).map { gameRoom }
    }
    
    func listAll(req: Request) throws -> EventLoopFuture<[GameRoom.Public]> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        return GameRoom.query(on: req.db)
            .filter(\.$isPrivate == false)
            .with(\.$creator)
            .with(\.$admin)
            .all().flatMapThrowing { gameRooms in
                gameRooms.map { gameRoom in
                    var code: String? = nil
                    if user.id == gameRoom.admin.id {
                        code = gameRoom.invitationCode
                    }
                    return GameRoom.Public(id: gameRoom.id,
                                           name: gameRoom.name,
                                           creator: gameRoom.creator.name,
                                           isPrivate: gameRoom.isPrivate,
                                           invitationCode: code,
                                           admin: gameRoom.admin.name)
                }
            }
    }
    
    func joinGameRoom(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(GameRoom.Join.self)
        let gameRoom = GameRoom.query(on: req.db)
            .filter(\.$id == input.gameRoomId)
            .filter(\.$invitationCode == input.invitationCode)
            .all()
            .flatMapThrowing { gameRooms -> GameRoom in
                guard let gameRoom = gameRooms.first else {
                    throw Abort(.notFound)
                }
                guard gameRooms.count == 1 else {
                    throw Abort(.notFound)
                }
                return gameRoom
            }
        return gameRoom.flatMap { gameRoom in
            let gameRoomUser = GameRoomUser(userID: user.id!, gameRoomID: gameRoom.id!)
            return gameRoomUser.save(on: req.db)
        }.transform(to: .ok)
    }
    
    func updateGameRoom(req: Request) throws -> EventLoopFuture<GameRoom.Public> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(GameRoom.Update.self)
        
        return GameRoom.find(input.gameRoomId, on: req.db)
            .flatMap { foundGameRoom in
                if let gameRoom = foundGameRoom {
                    if gameRoom.$admin.id == user.id {
                        gameRoom.name = input.name
                        gameRoom.isPrivate = input.isPrivate
                        gameRoom.pointsPerWord = input.points
                        
                        return gameRoom.save(on: req.db).flatMap {
                            gameRoom.$creator.load(on: req.db).flatMap {
                                gameRoom.$admin.load(on: req.db).map {
                                    GameRoom.Public(id: gameRoom.id,
                                                    name: gameRoom.name,
                                                    creator: gameRoom.creator.name,
                                                    isPrivate: gameRoom.isPrivate,
                                                    invitationCode: gameRoom.invitationCode,
                                                    admin: gameRoom.admin.name)
                                }
                            }
                        }
                    } else {
                        return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "You are not authorized to edit this game room."))
                    }
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound))
                }
            }
    }

    
    
    func listMembersForGameRoom(req: Request) throws -> EventLoopFuture<[User.Public]> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let gameRoomId = try req.query.get(UUID.self, at: "gameRoomId")
        
        return GameRoomUser.query(on: req.db)
            .filter(\.$gameRoom.$id == gameRoomId)
            .with(\.$user)
            .all()
            .flatMapThrowing { gameRoomUsers in
                gameRoomUsers.map { gameRoomUser in
                    User.Public(id: gameRoomUser.user.id!, name: gameRoomUser.user.name)
                }
            }
    }
    


    
    // MARK: Private
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
        var invitationCode: String?
        var admin: String
    }
    
    struct Update: Content {
        var isPrivate: Bool
        var gameRoomId: UUID
        var points: Int
        var name: String
    }
    
    struct Create: Content {
        var name: String
        var isPrivate: Bool
    }
    
    struct Join: Content {
        var gameRoomId: UUID
        var invitationCode: String
    }
}

