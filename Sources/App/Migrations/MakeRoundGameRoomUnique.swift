//
//  MakeRoundGameRoomUnique.swift
//
//
//  Created by ZhengWu Pan on 06.04.2023.
//
import Fluent

struct MakeRoundGameRoomUnique: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Round.schema)
            .unique(on: "game_room_id")
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Round.schema)
            .deleteUnique(on: "game_room_id")
            .update()
    }
}
