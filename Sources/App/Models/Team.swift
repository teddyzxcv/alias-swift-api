//
//  Team.swift
//  
//
//  Created by ZhengWu Pan on 05.04.2023.
//

import Fluent
import Vapor

import Fluent
import Vapor

final class Team: Model, Content {
    static let schema = "teams"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Parent(key: "game_room_id")
    var gameRoom: GameRoom
    
    init() { }
    
    init(id: UUID? = nil, name: String, gameRoomID: UUID) {
        self.id = id
        self.name = name
        self.$gameRoom.id = gameRoomID
    }
}
