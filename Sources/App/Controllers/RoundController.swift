//
//  RoundController.swift
//  
//
//  Created by ZhengWu Pan on 06.04.2023.
//

import Fluent
import Vapor

struct RoundController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let gameRooms = routes.grouped("round")
        let protectedRound = gameRooms.grouped(UserTokenAuthenticator())
        protectedRound.post("start", use: startRound)
        protectedRound.post("pause", use: pauseRound)
    }
    
    func startRound(req: Request) throws -> EventLoopFuture<Round> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(Round.Start.self)
        
        let startTime = Date.now
        let state = "started"
                
        return GameRoom.find(input.gameRoomId, on: req.db)
            .flatMapThrowing { gameRoom -> GameRoom in
                guard let gameRoom = gameRoom else {
                    throw Abort(.notFound, reason: "Game room not found")
                }
                return gameRoom
            }
            .flatMap { gameRoom -> EventLoopFuture<Round> in
                if gameRoom.$admin.id == user.id {
                    return Round.query(on: req.db)
                        .filter(\.$gameRoom.$id == gameRoom.id!)
                        .first()
                        .flatMap { existingRound -> EventLoopFuture<Round> in
                            if let existingRound = existingRound {
                                existingRound.state = "started"
                                existingRound.startTime = startTime
                                existingRound.endTime = nil
                                return existingRound.update(on: req.db).map { existingRound }
                            } else {
                                let newRound = Round(gameRoomID: gameRoom.id!, startTime: startTime, endTime: nil, state: state)
                                return newRound.save(on: req.db).map { newRound }
                            }
                        }
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can start round"))
                }
            }
    }


    
    func pauseRound(req: Request) throws -> EventLoopFuture<Round> {
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized)
            }

            let input = try req.content.decode(Round.Pause.self)

            return GameRoom.find(input.gameRoomId, on: req.db)
                .unwrap(or: Abort(.notFound, reason: "Game room not found"))
                .flatMap { gameRoom -> EventLoopFuture<Round> in
                    if gameRoom.$admin.id == user.id {
                        return Round.query(on: req.db)
                            .filter(\.$gameRoom.$id == gameRoom.id!)
                            .filter(\.$state == "started")
                            .first()
                            .unwrap(or: Abort(.notFound, reason: "No active round found for the game room"))
                            .flatMap { round -> EventLoopFuture<Round> in
                                round.state = "paused"
                                round.endTime = Date.now
                                return round.update(on: req.db).map { round }
                            }
                    } else {
                        return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can pause a round"))
                    }
                }
        }
}

extension Round {
    struct Start: Content {
        var gameRoomId: UUID
    }
    
    struct Pause: Content {
        var gameRoomId: UUID
    }
}
