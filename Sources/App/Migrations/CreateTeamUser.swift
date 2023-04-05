//
//  CreateTeamUser.swift
//  
//
//  Created by ZhengWu Pan on 05.04.2023.
//

import Fluent

struct CreateTeamUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TeamUser.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id"))
            .field("team_id", .uuid, .required, .references(Team.schema, "id"))
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(TeamUser.schema).delete()
    }
}
