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
        protectedGameRooms.get("leave-room", use: leaveGameRoom)
        protectedGameRooms.post("close-room", use: closeGameRoom)
        protectedGameRooms.post("kick-participant", use: kickParticipant)
        protectedGameRooms.post("pass-admin-status", use: passAdminStatus)
    }
    
    func passAdminStatus(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(GameRoom.PassAdminStatus.self)

        // Check if the current user is the admin of the game room
        return GameRoom.query(on: req.db)
            .filter(\.$id == input.gameRoomId)
            .filter(\.$admin.$id == user.id!)
            .with(\.$admin)
            .first()
            .flatMap { gameRoom in
                if let gameRoom = gameRoom {
                    // Pass the admin status to another user
                    return User.find(input.newAdminId, on: req.db)
                        .flatMap { newAdmin in
                            if let newAdmin = newAdmin {
                                gameRoom.$admin.id = newAdmin.id!
                                gameRoom.admin = newAdmin
                                return gameRoom.save(on: req.db).transform(to: .ok)
                            } else {
                                return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "New admin not found"))
                            }
                        }
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can pass admin status"))
                }
            }
    }
    
    func kickParticipant(req: Request) throws -> EventLoopFuture<HTTPStatus> {
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }
            
        let input = try req.content.decode(GameRoom.KickParticipant.self)

            // Check if the current user is the admin of the game room
            return GameRoom.query(on: req.db)
                .filter(\.$id == input.gameRoomId)
                .filter(\.$admin.$id == user.id!)
                .first()
                .flatMap { gameRoom in
                    if let gameRoom = gameRoom {
                        // Delete the GameRoomUser record for the user to be kicked
                        return GameRoomUser.query(on: req.db)
                            .filter(\.$user.$id == input.userIdToKick)
                            .filter(\.$gameRoom.$id == gameRoom.id!)
                            .delete()
                            .transform(to: .ok)
                    } else {
                        return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can kick participants"))
                    }
                }
        }
    
    // Update the leaveGameRoom function
    func leaveGameRoom(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let gameRoomId = try req.query.get(UUID.self, at: "gameRoomId")
        
        return GameRoom.find(gameRoomId, on: req.db)
            .flatMap { foundGameRoom in
                if let gameRoom = foundGameRoom {
                        // Delete all GameRoomUser records related to the game room
                        return GameRoomUser.query(on: req.db)
                        .filter(\.$gameRoom.$id == gameRoom.id!)
                        .filter(\.$user.$id == user.id!)
                        .delete().transform(to: .ok)
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Game room not found"))
                }
            }
    }
    
    func closeGameRoom(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }

        let input = try req.content.decode(GameRoom.Close.self)

        return GameRoom.find(input.gameRoomId, on: req.db)
            .flatMap { foundGameRoom in
                if let gameRoom = foundGameRoom {
                    if gameRoom.$admin.id == user.id {
                        // Find all Team records related to the game room
                        return Team.query(on: req.db)
                            .filter(\.$gameRoom.$id == gameRoom.id!)
                            .all()
                            .flatMap { teams in
                                // Delete all TeamUser records related to the game room's teams
                                return TeamUser.query(on: req.db)
                                    .join(Team.self, on: \TeamUser.$team.$id == \Team.$id)
                                    .filter(Team.self, \.$gameRoom.$id == gameRoom.id!)
                                    .delete()
                                    .flatMap {
                                        // Delete all Round records related to the game room
                                        return Round.query(on: req.db)
                                            .filter(\.$gameRoom.$id == gameRoom.id!)
                                            .delete()
                                            .flatMap {
                                                // Delete all Team records related to the game room
                                                return Team.query(on: req.db)
                                                    .filter(\.$gameRoom.$id == gameRoom.id!)
                                                    .delete()
                                                    .flatMap {
                                                        // Delete the game room
                                                        return gameRoom.delete(on: req.db).transform(to: .ok)
                                                    }
                                            }
                                    }
                            }
                    } else {
                        return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can close the game room"))
                    }
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Game room not found"))
                }
            }
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
    
    func joinGameRoom(req: Request) throws -> EventLoopFuture<GameRoom.JoinResponse> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(GameRoom.Join.self)
        let gameRoomQuery = GameRoom.query(on: req.db)
            .filter(\.$id == input.gameRoomId)
        
        // If an invitation code is provided, add it to the query
        if let invitationCode = input.invitationCode {
            gameRoomQuery.filter(\.$invitationCode == invitationCode)
        }
        
        return gameRoomQuery.first().flatMap { foundGameRoom in
            if let gameRoom = foundGameRoom {
                // If the game room is private and the invitation code does not match, return an error
                if gameRoom.isPrivate && gameRoom.invitationCode != input.invitationCode {
                    return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Invalid invitation code for private game room"))
                }
                
                // If the game room is not private or if the invitation code matches, add the user to the game room
                let gameRoomUser = GameRoomUser(userID: user.id!, gameRoomID: gameRoom.id!)
                return gameRoomUser.save(on: req.db).flatMap { _ in
                    return User.find(gameRoom.$admin.id, on: req.db).flatMap { admin in
                        return User.find(gameRoom.$creator.id, on: req.db).map{ creator in
                            GameRoom.JoinResponse(
                                id: gameRoom.id,
                                name: gameRoom.name,
                                creator: creator?.$name.value ?? "default value",
                                isPrivate: gameRoom.isPrivate,
                                invitationCode: gameRoom.invitationCode,
                                admin: admin?.$name.value ?? "default value",
                                points: gameRoom.pointsPerWord) // Return the game room as a successful result
                        }
                    }
                }
            } else {
                return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Game room not found"))
            }
        }
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
        
        // Check if the user is part of the game room
        return GameRoomUser.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$gameRoom.$id == gameRoomId)
            .first()
            .flatMapThrowing { gameRoomUser in
                if gameRoomUser == nil {
                    throw Abort(.forbidden, reason: "User is not in the game room")
                }
            }
            .flatMap { _ in
                GameRoomUser.query(on: req.db)
                    .filter(\.$gameRoom.$id == gameRoomId)
                    .with(\.$user)
                    .all()
                    .flatMapThrowing { gameRoomUsers in
                        gameRoomUsers.map { gameRoomUser in
                            User.Public(id: gameRoomUser.user.id!, name: gameRoomUser.user.name)
                        }
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
    struct PassAdminStatus: Content {
           var gameRoomId: UUID
           var newAdminId: UUID
    }
    
    struct KickParticipant: Content {
        var gameRoomId: UUID
        var userIdToKick: UUID
    }
    
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
        var invitationCode: String?
    }
    
    struct Close: Content {
        var gameRoomId: UUID
    }
    
    struct JoinResponse: Content {
        var id: UUID?
        var name: String
        var creator: String
        var isPrivate: Bool
        var invitationCode: String?
        var admin: String
        var points: Int
    }
}

