//
//  Round.swift
//  
//
//  Created by ZhengWu Pan on 05.04.2023.
//

import Fluent
import Vapor

final class Round: Model, Content {
    static let schema = "rounds"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "game_room_id")
    var gameRoom: GameRoom
    
    @Field(key: "start_time")
    var startTime: Date
    
    @Field(key: "end_time")
    var endTime: Date
    
    @Field(key: "state")
    var state: String
    
    init() { }
    
    init(id: UUID? = nil, gameRoomID: UUID, startTime: Date, endTime: Date, state: String) {
        self.id = id
        self.$gameRoom.id = gameRoomID
        self.startTime = startTime
        self.endTime = endTime
        self.state = state
    }
}
