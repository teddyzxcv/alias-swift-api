//
//  CreateGameRoomUser.swift
//  
//
//  Created by ZhengWu Pan on 29.03.2023.
//
import Fluent

struct CreateGameRoomUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(GameRoomUser.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id"))
            .field("game_room_id", .uuid, .required, .references(GameRoom.schema, "id"))
            .unique(on: "user_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(GameRoomUser.schema).delete()
    }
}
