import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
    if app.environment != .development {
        print("Start stage or prodiction")
        tlsConfiguration.certificateVerification = .none
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database",
            tlsConfiguration: tlsConfiguration
        ), as: .psql)
    } else {
        print("Start development")
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database"
        ), as: .psql)
    }

    
    
    app.middleware.use(UserTokenAuthenticator())
    
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateGameRoom())
    app.migrations.add(CreateGameRoomUser())
    app.migrations.add(CreateTeam())
    app.migrations.add(CreateTeamUser())
    app.migrations.add(CreateRound())
    app.migrations.add(MakeTeamUserUnique())
    app.migrations.add(MakeRoundGameRoomUnique())



    // register routes
    try routes(app)
}
