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
    }
    
    func startRound(req: Request) throws -> EventLoopFuture<Round> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(Round.Start.self)
        
        let startTime = Date.now
        let state = "started"
                
        return GameRoom.find(input.id, on: req.db)
            .unwrap(or: Abort(.notFound, reason: "Game room not found"))
            .flatMap { gameRoom -> EventLoopFuture<Round> in
                if gameRoom.$admin.id == user.id {
                    let round = Round(gameRoomID: input.id, startTime: startTime, endTime: nil, state: state)
                    return round.save(on: req.db).map { round }
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can create teams"))
                }
            }
    }
}

extension Round {
    struct Start: Content {
        var id: UUID
    }
}
