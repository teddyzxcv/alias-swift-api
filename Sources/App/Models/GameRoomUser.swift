//
//  GameRoomUser.swift
//  
//
//  Created by ZhengWu Pan on 29.03.2023.
//

import Fluent
import Vapor

final class GameRoomUser: Model, Content {
    static let schema = "game_room_users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "game_room_id")
    var gameRoom: GameRoom
    
    init() { }
    
    init(id: UUID? = nil, userID: UUID, gameRoomID: UUID) {
        self.id = id
        self.$user.id = userID
        self.$gameRoom.id = gameRoomID
    }
}
