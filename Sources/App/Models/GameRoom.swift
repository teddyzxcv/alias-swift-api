//
//  File.swift
//  
//
//  Created by ZhengWu Pan on 28.03.2023.
//

import Fluent
import Vapor

final class GameRoom: Model, Content {
    static let schema = "game_rooms"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "invitation_code")
    var invitationCode: String
    
    @Field(key: "is_private")
    var isPrivate: Bool
    
    @Parent(key: "creator_id")
    var creator: User
    
    @Parent(key: "admin_id")
    var admin: User
    
    init() { }
    
    init(id: UUID? = nil,
         name: String,
         creatorID: UUID,
         code: String,
         isPrivate: Bool,
         adminID: UUID) {
        self.id = id
        self.name = name
        self.$creator.id = creatorID
        self.invitationCode = code
        self.isPrivate = isPrivate
        self.$admin.id = adminID
    }
}
