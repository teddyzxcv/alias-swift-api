//
//  CreateRound.swift
//  
//
//  Created by ZhengWu Pan on 05.04.2023.
//

import Fluent

struct CreateRound: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Round.schema)
            .id()
            .field("game_room_id", .uuid, .required, .references(GameRoom.schema, "id"))
            .field("start_time", .datetime, .required)
            .field("end_time", .datetime, .required)
            .field("state", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Round.schema).delete()
    }
}
