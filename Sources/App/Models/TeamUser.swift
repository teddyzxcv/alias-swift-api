//
//  TeamUser.swift
//  
//
//  Created by ZhengWu Pan on 05.04.2023.
//

import Fluent
import Vapor

final class TeamUser: Model, Content {
    static let schema = "team_users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "team_id")
    var team: Team
    
    init() { }
    
    init(id: UUID? = nil, userID: UUID, teamID: UUID) {
        self.id = id
        self.$user.id = userID
        self.$team.id = teamID
    }
}
