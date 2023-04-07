//
//  MakeTeamUserUnique.swift
//  
//
//  Created by ZhengWu Pan on 06.04.2023.
//
import Fluent

struct MakeTeamUserUnique: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TeamUser.schema)
            .unique(on: "user_id")
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(TeamUser.schema)
            .deleteUnique(on: "user_id")
            .update()
    }
}

