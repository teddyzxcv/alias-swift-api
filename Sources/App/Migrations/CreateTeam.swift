//
//  CreateTeam.swift
//  
//
//  Created by ZhengWu Pan on 05.04.2023.
//

import Fluent

struct CreateTeam: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Team.schema)
            .id()
            .field("name", .string, .required)
            .field("game_room_id", .uuid, .required, .references(GameRoom.schema, "id"))
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Team.schema).delete()
    }
}
