//
//  File.swift
//  
//
//  Created by ZhengWu Pan on 28.03.2023.
//

import Fluent


import Fluent

struct CreateGameRoom: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("game_rooms")
            .id()
            .field("name", .string, .required)
            .field("creator_id", .uuid, .required, .references(User.schema, "id"))
            .field("invitation_code", .string, .required)
            .field("is_private", .bool, .required)
            .field("admin_id", .uuid, .required, .references(User.schema, "id"))
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("game_rooms").delete()
    }
}
