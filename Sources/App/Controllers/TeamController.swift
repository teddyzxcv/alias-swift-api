//
//  TeamController.swift
//
//
//  Created by ZhengWu Pan on 28.03.2023.
//

import Fluent
import Vapor

struct TeamController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let teams = routes.grouped("teams")
        let protectedTeams = teams.grouped(UserTokenAuthenticator())
        
        protectedTeams.get("list-teams", use: listTeamsForGameRoom)
        protectedTeams.post("create-team", use: createTeam)
        protectedTeams.post("join-team", use: joinTeam)
        protectedTeams.get("leave-team", use: leaveTeam)
        protectedTeams.post("close-team", use: closeTeam)
    }
    
    func leaveTeam(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }

        let teamId = try req.query.get(UUID.self, at: "teamId")

        return TeamUser.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$team.$id == teamId)
            .first()
            .flatMap { teamUser in
                if let teamUser = teamUser {
                    return teamUser.delete(on: req.db).transform(to: .ok)
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "User not found in the specified team."))
                }
            }
    }

    
    func listTeamsForGameRoom(req: Request) throws -> EventLoopFuture<[Team.Public]> {
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
                Team.query(on: req.db)
                    .filter(\.$gameRoom.$id == gameRoomId)
                    .all()
                    .flatMap { teams in
                        let teamUsersPublic = teams.map { team -> EventLoopFuture<Team.Public> in
                            return TeamUser.query(on: req.db)
                                .filter(\.$team.$id == team.id!)
                                .with(\.$user)
                                .all()
                                .map { teamUsers in
                                    let usersPublic = teamUsers.map { teamUser in
                                        User.Public(id: teamUser.user.id!, name: teamUser.user.name)
                                    }
                                    return Team.Public(id: team.id!, name: team.name, users: usersPublic)
                                }
                        }
                        return teamUsersPublic.flatten(on: req.eventLoop)
                    }
            }
    }

    
    
    func joinTeam(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(Team.Join.self)
        
        return Team.find(input.teamId, on: req.db).flatMap { foundTeam -> EventLoopFuture<HTTPStatus> in
            if let team = foundTeam {
                return GameRoomUser.query(on: req.db)
                    .filter(\.$user.$id == user.id!)
                    .filter(\.$gameRoom.$id == team.$gameRoom.id)
                    .first()
                    .flatMap { foundGameRoomUser -> EventLoopFuture<HTTPStatus> in
                        if foundGameRoomUser != nil {
                            // Find and delete any existing TeamUser relation with the user
                            return TeamUser.query(on: req.db)
                                .filter(\.$user.$id == user.id!)
                                .delete()
                                .flatMap { _ in
                                    // Create a new TeamUser relation between the user and the team
                                    let teamUser = TeamUser(userID: user.id!, teamID: team.id!)
                                    return teamUser.save(on: req.db).transform(to: .ok)
                                }
                        } else {
                            return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "User is not in the game room"))
                        }
                    }
            } else {
                return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Team not found"))
            }
        }
    }

    
    
    func createTeam(req: Request) throws -> EventLoopFuture<Team.Public> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let input = try req.content.decode(Team.Create.self)
        
        return GameRoom.find(input.gameRoomId, on: req.db)
            .unwrap(or: Abort(.notFound, reason: "Game room not found"))
            .flatMap { gameRoom -> EventLoopFuture<Team.Public> in
                if gameRoom.$admin.id == user.id {
                    let team = Team(name: input.name, gameRoomID: input.gameRoomId)
                    return team.save(on: req.db).map {
                        Team.Public(id: team.id!, name: team.name, users: [])
                    }
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can create teams"))
                }
            }
    }
    
    func closeTeam(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let user = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }

        let input = try req.content.decode(Team.Close.self)

        return Team.find(input.teamId, on: req.db)
            .flatMap { foundTeam in
                if let team = foundTeam {
                    return GameRoom.find(team.$gameRoom.id, on: req.db)
                        .flatMap { foundGameRoom in
                            if let gameRoom = foundGameRoom, gameRoom.$admin.id == user.id {
                                // Delete all TeamUser records related to the team
                                return TeamUser.query(on: req.db)
                                    .filter(\.$team.$id == team.id!)
                                    .delete()
                                    .flatMap {
                                        // Delete the team
                                        return team.delete(on: req.db).transform(to: .ok)
                                    }
                            } else {
                                return req.eventLoop.makeFailedFuture(Abort(.forbidden, reason: "Only the game room admin can close the team"))
                            }
                        }
                } else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Team not found"))
                }
            }
    }


}


extension User {
    struct Public: Content {
        var id: UUID
        var name: String
    }
}


extension Team {
    struct Public: Content {
        var id: UUID
        var name: String
        var users: [User.Public]
    }
    
    struct Join: Content {
        var teamId: UUID
    }
    
    struct Create: Content {
        var name: String
        var gameRoomId: UUID
    }
    
    struct Close: Content {
            var teamId: UUID
    }
}

