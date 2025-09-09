import Foundation

struct RobloxUser {
    let id: Int
    let username: String
    let displayName: String
    let avatarURL: String?
}

struct RobloxAuthTicket {
    let authTicket: String
    let csrfToken: String
}

class RobloxAPIService: ObservableObject {
    static let shared = RobloxAPIService()
    
    private init() {}
    
    // MARK: - Logging
    private func log(_ tag: String, _ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let ts = formatter.string(from: Date())
        print("[API][\(tag)][\(ts)] \(message)")
    }
    
    func fetchUserInfo(from cookie: String) async throws -> RobloxUser {
        // First, get the authenticated user info
        guard let url = URL(string: "https://users.roblox.com/v1/users/authenticated") else {
            throw RobloxAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
        
        log("UserInfo", "Requesting authenticated user info …")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RobloxAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw RobloxAPIError.invalidCookie
            }
            throw RobloxAPIError.serverError(httpResponse.statusCode)
        }
        
        let userResponse = try JSONDecoder().decode(AuthenticatedUserResponse.self, from: data)
        log("UserInfo", "Authenticated as id=\(userResponse.id) name=\(userResponse.name) display=\(userResponse.displayName)")
        
        // Get avatar headshot URL
        let avatarURL = try? await fetchAvatarURL(for: userResponse.id)
        
        return RobloxUser(
            id: userResponse.id,
            username: userResponse.name,
            displayName: userResponse.displayName,
            avatarURL: avatarURL
        )
    }
    
    private func fetchAvatarURL(for userId: Int) async throws -> String {
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=\(userId)&size=150x150&format=Png&isCircular=false") else {
            throw RobloxAPIError.invalidURL
        }
        
        log("Avatar", "Fetching avatar headshot for userId=\(userId)")
        let (data, _) = try await URLSession.shared.data(from: url)
        let avatarResponse = try JSONDecoder().decode(AvatarResponse.self, from: data)
        
        return avatarResponse.data.first?.imageUrl ?? ""
    }
    
    func getCSRFToken(from cookie: String) async throws -> String {
        // Try multiple endpoints to get CSRF token
        let endpoints = [
            "https://auth.roblox.com/v1/logout",
            "https://friends.roblox.com/v1/my/friends/requests",
            "https://accountinformation.roblox.com/v1/birthdate"
        ]
        
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("https://www.roblox.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
            
            do {
                log("CSRF", "Attempting token from \(endpoint)")
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                
                // CSRF token should be in the response headers when we get a 403
                if httpResponse.statusCode == 403,
                   let csrfToken = httpResponse.value(forHTTPHeaderField: "x-csrf-token"),
                   !csrfToken.isEmpty {
                    log("CSRF", "Received token (len=\(csrfToken.count)) from \(endpoint)")
                    return csrfToken
                }
            } catch {
                log("CSRF", "Error on \(endpoint): \(error.localizedDescription)")
                continue // Try next endpoint
            }
        }
        
        throw RobloxAPIError.invalidResponse
    }
    
    func getAuthTicket(from cookie: String, csrfToken: String) async throws -> String {
        guard let url = URL(string: "https://auth.roblox.com/v1/authentication-ticket") else {
            throw RobloxAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
        
        log("AuthTicket", "Requesting auth ticket …")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RobloxAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            log("AuthTicket", "Server code=\(httpResponse.statusCode) body=\(String(data: data, encoding: .utf8) ?? "")")
            throw RobloxAPIError.serverError(httpResponse.statusCode)
        }
        
        guard let authTicketResponse = httpResponse.value(forHTTPHeaderField: "rbx-authentication-ticket") else {
            throw RobloxAPIError.invalidResponse
        }
        
        log("AuthTicket", "Received ticket len=\(authTicketResponse.count)")
        return authTicketResponse
    }
    
    func getAuthTicketForLaunch(from cookie: String) async throws -> RobloxAuthTicket {
        let csrfToken = try await getCSRFToken(from: cookie)
        let authTicket = try await getAuthTicket(from: cookie, csrfToken: csrfToken)
        
        return RobloxAuthTicket(authTicket: authTicket, csrfToken: csrfToken)
    }
    
    func fetchGameThumbnail(for universeId: Int) async throws -> String {
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=\(universeId)&size=768x432&format=Png&isCircular=false") else {
            throw RobloxAPIError.invalidURL
        }
        
        log("Thumb", "Fetching universe thumbnail for id=\(universeId)")
        let (data, _) = try await URLSession.shared.data(from: url)
        let thumbnailResponse = try JSONDecoder().decode(GameThumbnailResponse.self, from: data)
        
        return thumbnailResponse.data.first?.thumbnails.first?.imageUrl ?? ""
    }

    func fetchGameIconForPlace(placeId: Int) async throws -> String {
        // Fallback square icon for a place (works even for placeholder)
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=\(placeId)&size=150x150&format=Png&isCircular=false&returnPolicy=PlaceHolder") else {
            throw RobloxAPIError.invalidURL
        }
        log("Thumb", "Fetching place icon for placeId=\(placeId)")
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PlaceIconResponse.self, from: data)
        return response.data.first?.imageUrl ?? ""
    }

    // MARK: - Friends & Presence
    struct FriendBasic: Codable, Identifiable {
        let id: Int
        let name: String
        let displayName: String
    }
    
    struct PresenceItem: Codable {
        let userPresenceType: Int
        let userId: Int
        let lastLocation: String?
        let placeId: Int?
        let universeId: Int?
        let gameId: String?
        let lastOnline: String?
    }
    
    func fetchFriends(of userId: Int, cookie: String) async throws -> [FriendBasic] {
        guard let url = URL(string: "https://friends.roblox.com/v1/users/\(userId)/friends") else {
            throw RobloxAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        log("Friends", "Fetching friends for userId=\(userId)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse { log("Friends", "HTTP \(http.statusCode) bytes=\(data.count)") }
        let decoded = try JSONDecoder().decode(FriendsListResponse.self, from: data)
        return decoded.data.map { FriendBasic(id: $0.id, name: $0.name, displayName: $0.displayName) }
    }
    
    func fetchPresence(userIds: [Int], cookie: String) async throws -> [PresenceItem] {
        guard !userIds.isEmpty else { return [] }
        let csrf = try await getCSRFToken(from: cookie)
        guard let url = URL(string: "https://presence.roblox.com/v1/presence/users") else { throw RobloxAPIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
        req.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        let body: [String: Any] = ["userIds": Array(userIds.prefix(100))]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        log("Presence", "POST presence for count=\(min(100, userIds.count))")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse { log("Presence", "HTTP \(http.statusCode) bytes=\(data.count)") }
        let decoded = try JSONDecoder().decode(UserPresenceResponse.self, from: data)
        return decoded.userPresences.map {
            PresenceItem(
                userPresenceType: $0.userPresenceType,
                userId: $0.userId,
                lastLocation: $0.lastLocation,
                placeId: $0.placeId,
                universeId: $0.universeId,
                gameId: $0.gameId,
                lastOnline: $0.lastOnline
            )
        }
    }
    
    func fetchAvatarHeadshots(userIds: [Int]) async throws -> [Int: String] {
        guard !userIds.isEmpty else { return [:] }
        let idsParam = userIds.map(String.init).joined(separator: ",")
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=\(idsParam)&size=150x150&format=Png&isCircular=false") else {
            throw RobloxAPIError.invalidURL
        }
        log("AvatarBatch", "Fetching headshots for count=\(userIds.count)")
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(UserHeadshotResponse.self, from: data)
        var map: [Int: String] = [:]
        for item in decoded.data {
            map[item.targetId] = item.imageUrl ?? ""
        }
        return map
    }

    // MARK: - Games Search (legacy web API)
    func searchGames(keyword: String) async throws -> [Game] {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlString = "https://www.roblox.com/games/api/v1/games/list?model.keyword=\(encoded)&model.startRows=0&model.maxRows=25&model.gameFilter=1&model.timeFilter=0&model.genreFilter=0"
        guard let url = URL(string: urlString) else { throw RobloxAPIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("RobloxAccountManager/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        log("Search", "Query=\(keyword)")
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse {
            log("Search", "HTTP \(http.statusCode) bytes=\(data.count)")
        }
        if let snippet = String(data: data.prefix(256), encoding: .utf8) {
            log("Search", "Body snippet: \(snippet.replacingOccurrences(of: "\n", with: " "))")
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(LegacyGamesListResponse.self, from: data)
        
        // Map legacy items to our Game model, hydrating universeId and thumbnails
        var games: [Game] = []
        games.reserveCapacity(response.games.count)
        
        for item in response.games.prefix(25) {
            let placeId = item.placeId
            var universeId = item.universeId
            if universeId == nil {
                universeId = try? await fetchUniverseId(forPlaceId: placeId)
            }
            let resolvedUniverseId = universeId ?? 0
            
            var game = Game(
                id: resolvedUniverseId > 0 ? resolvedUniverseId : placeId,
                name: item.name,
                description: item.description ?? "",
                creatorName: item.creatorName ?? "",
                creatorId: item.creatorId ?? 0,
                placeId: placeId,
                universeId: resolvedUniverseId
            )
            game.playerCount = item.playerCount ?? 0
            if let up = item.totalUpVotes, let down = item.totalDownVotes, up + down > 0 {
                let ratio = Double(up) / Double(up + down)
                game.rating = ratio * 5.0
            }
            // Thumbnail
            if resolvedUniverseId > 0 {
                if let thumb = try? await fetchGameThumbnail(for: resolvedUniverseId), !thumb.isEmpty {
                    game.thumbnailURL = thumb
                } else if let icon = try? await fetchGameIconForPlace(placeId: placeId), !icon.isEmpty {
                    game.thumbnailURL = icon
                }
            } else if let icon = try? await fetchGameIconForPlace(placeId: placeId), !icon.isEmpty {
                game.thumbnailURL = icon
            }
            games.append(game)
        }
        
        log("Search", "Mapped results=\(games.count)")
        return games
    }
    
    // MARK: - Games Search (Omni + Details + Icons)
    func searchGamesOmni(keyword: String, cookie: String) async throws -> [Game] {
        let sessionId = UUID().uuidString
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let omniURLString = "https://apis.roblox.com/search-api/omni-search?searchQuery=\(encoded)&pageType=games&sessionId=\(sessionId)"
        guard let omniURL = URL(string: omniURLString) else { throw RobloxAPIError.invalidURL }
        var request = URLRequest(url: omniURL)
        request.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        log("Omni", "Query=\(keyword) sessionId=\(sessionId)")
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse { log("Omni", "HTTP \(http.statusCode) bytes=\(data.count)") }
        
        // Extract up to 40 universeIds by scanning objects where contentType == Game and contentId exists
        let universeIds = extractUniverseIdsFromOmni(data: data)
        log("Omni", "UniverseIds=\(universeIds.prefix(10)) total=\(universeIds.count)")
        guard !universeIds.isEmpty else { return [] }
        let idsParam = universeIds.map(String.init).joined(separator: ",")
        
        async let detailsTask: GameDetailsResponse = fetchGameDetails(universeIds: idsParam, cookie: cookie)
        async let iconsTask: GameIconsResponse = fetchGameIcons(universeIds: idsParam, cookie: cookie)
        let (details, icons) = try await (detailsTask, iconsTask)
        
        // Build maps for quick lookup
        var detailById: [Int: GameDetail] = [:]
        for d in details.data { detailById[d.id] = d }
        var iconById: [Int: String] = [:]
        for t in icons.data { iconById[t.targetId] = t.imageUrl ?? "" }
        
        // Preserve order returned by omni
        var games: [Game] = []
        games.reserveCapacity(universeIds.count)
        for uid in universeIds {
            guard let d = detailById[uid] else { continue }
            let placeId = d.rootPlaceId ?? 0
            var game = Game(
                id: uid,
                name: d.name ?? "",
                description: d.description ?? "",
                creatorName: d.creator?.name ?? d.creatorName ?? "",
                creatorId: d.creator?.id ?? d.creatorId ?? 0,
                placeId: placeId,
                universeId: uid
            )
            game.thumbnailURL = iconById[uid]
            game.playerCount = d.playerCount ?? 0
            games.append(game)
        }
        log("Omni", "Mapped games=\(games.count)")
        return games
    }

    // MARK: - Discovery Recommendation (Trending/Personalized)
    func getRecommendedGames(limit: Int = 20, cookie: String) async throws -> [Game] {
        let sessionId = UUID().uuidString
        guard let url = URL(string: "https://apis.roblox.com/discovery-api/omni-recommendation") else {
            throw RobloxAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = [
            "pageType": "Home",
            "sessionId": sessionId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        log("Discover", "POST omni-recommendation sessionId=\(sessionId)")
        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse { log("Discover", "HTTP \(http.statusCode) bytes=\(data.count)") }
        let universeIds = extractUniverseIdsFromOmniRecommendation(data: data)
        log("Discover", "Extracted ids=\(universeIds.prefix(10)) total=\(universeIds.count)")
        guard !universeIds.isEmpty else { return [] }
        let idsParam = universeIds.prefix(limit).map(String.init).joined(separator: ",")
        async let detailsTask: GameDetailsResponse = fetchGameDetails(universeIds: idsParam, cookie: cookie)
        async let iconsTask: GameIconsResponse = fetchGameIcons(universeIds: idsParam, cookie: cookie)
        let (details, icons) = try await (detailsTask, iconsTask)
        var detailById: [Int: GameDetail] = [:]
        for d in details.data { detailById[d.id] = d }
        var iconById: [Int: String] = [:]
        for t in icons.data { iconById[t.targetId] = t.imageUrl ?? "" }
        var games: [Game] = []
        games.reserveCapacity(min(limit, universeIds.count))
        for uid in universeIds.prefix(limit) {
            guard let d = detailById[uid] else { continue }
            let placeId = d.rootPlaceId ?? 0
            var game = Game(
                id: uid,
                name: d.name ?? "",
                description: d.description ?? "",
                creatorName: d.creator?.name ?? d.creatorName ?? "",
                creatorId: d.creator?.id ?? d.creatorId ?? 0,
                placeId: placeId,
                universeId: uid
            )
            game.thumbnailURL = iconById[uid]
            game.playerCount = d.playerCount ?? 0
            games.append(game)
        }
        return games
    }
    
    func searchGamesAuto(keyword: String, cookie: String?) async throws -> [Game] {
        if let cookie = cookie, !cookie.isEmpty {
            do { return try await searchGamesOmni(keyword: keyword, cookie: cookie) } catch {
                log("Omni", "Failed, falling back: \(error.localizedDescription)")
            }
        }
        return try await searchGames(keyword: keyword)
    }
    
    // MARK: - Helpers for Omni
    private func extractUniverseIdsFromOmni(data: Data) -> [Int] {
        var ids: [Int] = []
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return [] }
        func walk(_ any: Any) {
            if let dict = any as? [String: Any] {
                if let type = dict["contentType"] as? String, type == "Game" {
                    if let cid = dict["contentId"] as? String, let id = Int(cid) { ids.append(id) }
                    if let cidNum = dict["contentId"] as? Int { ids.append(cidNum) }
                }
                for v in dict.values { walk(v) }
            } else if let arr = any as? [Any] {
                for v in arr { walk(v) }
            }
        }
        walk(obj)
        // unique preserving order and limit 40
        var seen = Set<Int>()
        var out: [Int] = []
        for id in ids where !seen.contains(id) {
            out.append(id); seen.insert(id)
            if out.count >= 40 { break }
        }
        return out
    }
    
    // Explore API content can be nested differently than Omni. Walk JSON and collect Game contentIds.
    private func extractUniverseIdsFromExploreContent(data: Data) -> [Int] {
        var ids: [Int] = []
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return [] }
        func walk(_ any: Any) {
            if let dict = any as? [String: Any] {
                if let type = dict["contentType"] as? String, type == "Game" {
                    if let cid = dict["contentId"] as? String, let id = Int(cid) { ids.append(id) }
                    if let cidNum = dict["contentId"] as? Int { ids.append(cidNum) }
                }
                for v in dict.values { walk(v) }
            } else if let arr = any as? [Any] {
                for v in arr { walk(v) }
            }
        }
        walk(obj)
        // unique preserving order
        var seen = Set<Int>()
        var out: [Int] = []
        for id in ids where !seen.contains(id) {
            out.append(id); seen.insert(id)
            if out.count >= 40 { break }
        }
        return out
    }

    // Omni Recommendation response parser: collect contentId where contentType == Game
    private func extractUniverseIdsFromOmniRecommendation(data: Data) -> [Int] {
        var ids: [Int] = []
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return [] }
        func walk(_ any: Any) {
            if let dict = any as? [String: Any] {
                if let type = dict["contentType"] as? String, type == "Game" {
                    if let cid = dict["contentId"] as? String, let id = Int(cid) { ids.append(id) }
                    if let cidNum = dict["contentId"] as? Int { ids.append(cidNum) }
                }
                for v in dict.values { walk(v) }
            } else if let arr = any as? [Any] {
                for v in arr { walk(v) }
            }
        }
        walk(obj)
        var seen = Set<Int>()
        var out: [Int] = []
        for id in ids where !seen.contains(id) {
            out.append(id); seen.insert(id)
            if out.count >= 60 { break }
        }
        return out
    }
    
    private func fetchGameDetails(universeIds: String, cookie: String?) async throws -> GameDetailsResponse {
        guard let url = URL(string: "https://games.roblox.com/v1/games?universeIds=\(universeIds)") else {
            throw RobloxAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        if let cookie, !cookie.isEmpty {
            req.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(GameDetailsResponse.self, from: data)
        return decoded
    }
    
    private func fetchGameIcons(universeIds: String, cookie: String?) async throws -> GameIconsResponse {
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/games/icons?universeIds=\(universeIds)&size=150x150&format=Png&isCircular=false") else {
            throw RobloxAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        if let cookie, !cookie.isEmpty {
            req.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(GameIconsResponse.self, from: data)
        return decoded
    }

    // MARK: - Popular Games via Explore API
    func getPopularGames(sortPattern: String = "trending", cookie: String? = nil) async throws -> [Game] {
        let sessionId = UUID().uuidString
        guard let sortsURL = URL(string: "https://apis.roblox.com/explore-api/v1/get-sorts?sessionId=\(sessionId)") else {
            throw RobloxAPIError.invalidURL
        }
        var sortsReq = URLRequest(url: sortsURL)
        sortsReq.setValue("application/json", forHTTPHeaderField: "Accept")
        sortsReq.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
        sortsReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        if let cookie, !cookie.isEmpty { sortsReq.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie") }
        log("Explore", "Fetching sorts sessionId=\(sessionId)")
        let (sortsData, _) = try await URLSession.shared.data(for: sortsReq)
        let candidates = listSortCandidates(from: sortsData)
        if candidates.isEmpty { log("Explore", "No sorts returned"); return [] }

        // Build an ordered list of sortIds to try
        let lowered = sortPattern.lowercased()
        let namePatterns = (lowered == "popular" || lowered == "trending")
            ? ["top trending", "trending", "up and coming", "up-and-coming", "engaging", "popular", "ccu"]
            : [sortPattern]
        let preferredIds = ["Top_Trending_V4", "Up_And_Coming_V4", "CCU_Based_V1", "Popular_Worldwide_V4"]
        let availableIds = Set(candidates.map { $0.0 })
        var ordered: [String] = []
        // 1) known IDs
        for id in preferredIds where availableIds.contains(id) { ordered.append(id) }
        // 2) name pattern matches
        let nameMatched = candidates.compactMap { (id, name) -> String? in
            let ln = name.lowercased(); let lid = id.lowercased()
            for pat in namePatterns { if ln.contains(pat) || lid.contains(pat) { return id } }
            if ln.contains("trend") || ln.contains("coming") || ln.contains("ccu") { return id }
            return nil
        }
        for id in nameMatched where !ordered.contains(id) { ordered.append(id) }
        // 3) all remaining
        for (id, _) in candidates where !ordered.contains(id) { ordered.append(id) }

        // Try sorts until one yields universeIds
        var universeIds: [Int] = []
        var chosenSortId: String?
        for sid in ordered {
            guard let contentURL = URL(string: "https://apis.roblox.com/explore-api/v1/get-sort-content?sessionId=\(sessionId)&sortId=\(sid)") else { continue }
            var contentReq = URLRequest(url: contentURL)
            contentReq.setValue("application/json", forHTTPHeaderField: "Accept")
            contentReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            if let cookie, !cookie.isEmpty { contentReq.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie") }
            do {
                let (contentData, _) = try await URLSession.shared.data(for: contentReq)
                let ids = extractUniverseIdsFromExploreContent(data: contentData)
                log("Explore", "sortId=\(sid) yielded ids=\(ids.count)")
                if !ids.isEmpty {
                    universeIds = ids
                    chosenSortId = sid
                    break
                }
            } catch {
                log("Explore", "sortId=\(sid) error: \(error.localizedDescription)")
                continue
            }
        }
        guard !universeIds.isEmpty, let sortId = chosenSortId else { return [] }
        log("Explore", "Using sortId=\(sortId) with ids=\(universeIds.count)")
        let idsParam = universeIds.prefix(10).map(String.init).joined(separator: ",")
        async let detailsTask: GameDetailsResponse = fetchGameDetails(universeIds: idsParam, cookie: cookie)
        async let iconsTask: GameIconsResponse = fetchGameIcons(universeIds: idsParam, cookie: cookie)
        let (details, icons) = try await (detailsTask, iconsTask)
        var detailById: [Int: GameDetail] = [:]
        for d in details.data { detailById[d.id] = d }
        var iconById: [Int: String] = [:]
        for t in icons.data { iconById[t.targetId] = t.imageUrl ?? "" }
        var games: [Game] = []
        for uid in universeIds.prefix(10) {
            guard let d = detailById[uid] else { continue }
            let placeId = d.rootPlaceId ?? 0
            var game = Game(
                id: uid,
                name: d.name ?? "",
                description: d.description ?? "",
                creatorName: d.creator?.name ?? d.creatorName ?? "",
                creatorId: d.creator?.id ?? d.creatorId ?? 0,
                placeId: placeId,
                universeId: uid
            )
            game.thumbnailURL = iconById[uid]
            game.playerCount = d.playerCount ?? 0
            games.append(game)
        }
        return games
    }

    // MARK: - Top Rated via Explore API
    func getTopRatedGames(topN: Int = 10, cookie: String? = nil) async throws -> [Game] {
        let sessionId = UUID().uuidString
        guard let sortsURL = URL(string: "https://apis.roblox.com/explore-api/v1/get-sorts?sessionId=\(sessionId)") else {
            throw RobloxAPIError.invalidURL
        }
        var sortsReq = URLRequest(url: sortsURL)
        sortsReq.setValue("application/json", forHTTPHeaderField: "Accept")
        sortsReq.setValue("https://www.roblox.com", forHTTPHeaderField: "Referer")
        sortsReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        if let cookie, !cookie.isEmpty { sortsReq.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie") }
        log("Explore", "Fetching sorts for Top Rated sessionId=\(sessionId)")
        let (sortsData, _) = try await URLSession.shared.data(for: sortsReq)
        // Find sortId matching any Top Rated synonyms
        let patterns = ["top rated", "highest rated", "most liked", "top-rated", "rating"]
        var sortId = extractSortId(from: sortsData, patterns: patterns)
        if sortId == nil {
            log("Explore", "Top Rated sort not found via patterns. Listing available sorts…")
            let candidates = listSortCandidates(from: sortsData)
            if !candidates.isEmpty {
                log("Explore", "Candidates: \(candidates.prefix(10).map { "\($0.0):\($0.1)" }.joined(separator: ", "))")
                sortId = candidates.first?.0 // fallback to first available sort
            }
        }
        guard let sortId else { return [] }
        log("Explore", "Top Rated sortId=\(sortId)")
        guard let contentURL = URL(string: "https://apis.roblox.com/explore-api/v1/get-sort-content?sessionId=\(sessionId)&sortId=\(sortId)") else {
            throw RobloxAPIError.invalidURL
        }
        var contentReq = URLRequest(url: contentURL)
        contentReq.setValue("application/json", forHTTPHeaderField: "Accept")
        contentReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        if let cookie, !cookie.isEmpty { contentReq.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie") }
        let (contentData, _) = try await URLSession.shared.data(for: contentReq)
        var universeIds = extractUniverseIdsFromExploreContent(data: contentData)
        if universeIds.isEmpty { return [] }
        universeIds = Array(universeIds.prefix(topN))
        let idsParam = universeIds.map(String.init).joined(separator: ",")
        async let detailsTask: GameDetailsResponse = fetchGameDetails(universeIds: idsParam, cookie: cookie)
        async let iconsTask: GameIconsResponse = fetchGameIcons(universeIds: idsParam, cookie: cookie)
        let (details, icons) = try await (detailsTask, iconsTask)
        var detailById: [Int: GameDetail] = [:]
        for d in details.data { detailById[d.id] = d }
        var iconById: [Int: String] = [:]
        for t in icons.data { iconById[t.targetId] = t.imageUrl ?? "" }
        var games: [Game] = []
        for uid in universeIds {
            guard let d = detailById[uid] else { continue }
            let placeId = d.rootPlaceId ?? 0
            var game = Game(
                id: uid,
                name: d.name ?? "",
                description: d.description ?? "",
                creatorName: d.creator?.name ?? d.creatorName ?? "",
                creatorId: d.creator?.id ?? d.creatorId ?? 0,
                placeId: placeId,
                universeId: uid
            )
            game.thumbnailURL = iconById[uid]
            game.playerCount = d.playerCount ?? 0
            games.append(game)
        }
        log("Explore", "Top Rated mapped=\(games.count)")
        return games
    }
    
    private func extractSortId(from data: Data, pattern: String) -> String? {
        return extractSortId(from: data, patterns: [pattern])
    }

    private func extractSortId(from data: Data, patterns: [String]) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        let lowerPats = patterns.map { $0.lowercased() }
        if let dict = obj as? [String: Any] {
            let sorts = (dict["sorts"] as? [Any]) ?? (dict["Sorts"] as? [Any]) ?? []
            for item in sorts {
                guard let d = item as? [String: Any] else { continue }
                let idStr: String? = (d["id"] as? String)
                    ?? (d["sortId"] as? String)
                    ?? ((d["id"] as? Int).map(String.init))
                let candidateKeys = [
                    "name","displayName","displayText","displayNameText",
                    "title","titleText","carouselTitle","contextualTitle",
                    "sortName","localeTitle","text","label","labelText"
                ]
                var nameStr: String = ""
                for key in candidateKeys {
                    if let s = d[key] as? String, !s.isEmpty { nameStr = s; break }
                }
                if nameStr.isEmpty, let titleDict = d["title"] as? [String: Any] {
                    // Try pulling any string inside nested title
                    for (_, v) in titleDict {
                        if let s = v as? String, !s.isEmpty { nameStr = s; break }
                    }
                }
                if nameStr.isEmpty {
                    // As a last resort, concatenate all string values in the dict
                    let allStrings = d.values.compactMap { $0 as? String }
                    nameStr = allStrings.joined(separator: " ")
                }
                let lowerName = nameStr.lowercased()
                let lowerId = idStr?.lowercased() ?? ""
                for pat in lowerPats {
                    if lowerName.contains(pat) || lowerId.contains(pat) {
                        if let idStr { return idStr }
                    }
                }
            }
        }
        return nil
    }

    private func listSortCandidates(from data: Data) -> [(String, String)] {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return [] }
        var out: [(String, String)] = []
        if let dict = obj as? [String: Any] {
            let sorts = (dict["sorts"] as? [Any]) ?? (dict["Sorts"] as? [Any]) ?? []
            for item in sorts {
                guard let d = item as? [String: Any] else { continue }
                let idStr: String? = (d["id"] as? String)
                    ?? (d["sortId"] as? String)
                    ?? ((d["id"] as? Int).map(String.init))
                let name = (d["name"] as? String)
                    ?? (d["displayName"] as? String)
                    ?? (d["displayText"] as? String)
                    ?? (d["displayNameText"] as? String)
                    ?? (d["title"] as? String)
                    ?? ""
                if let idStr { out.append((idStr, name)) }
            }
        }
        return out
    }
    private func fetchUniverseId(forPlaceId placeId: Int) async throws -> Int {
        guard let url = URL(string: "https://api.roblox.com/universes/get-universe-containing-place?placeId=\(placeId)") else {
            throw RobloxAPIError.invalidURL
        }
        log("Universe", "Lookup for placeId=\(placeId)")
        let (data, _) = try await URLSession.shared.data(from: url)
        let res = try JSONDecoder().decode(UniverseLookupResponse.self, from: data)
        return res.universeId
    }
}

// MARK: - Response Models
private struct AuthenticatedUserResponse: Codable {
    let id: Int
    let name: String
    let displayName: String
}

private struct AvatarResponse: Codable {
    let data: [AvatarData]
}

private struct AvatarData: Codable {
    let imageUrl: String
}

private struct GameThumbnailResponse: Codable {
    let data: [GameThumbnailData]
}

private struct GameThumbnailData: Codable {
    let universeId: Int
    let thumbnails: [GameThumbnail]
}

private struct GameThumbnail: Codable {
    let imageUrl: String
}

private struct PlaceIconResponse: Codable {
    let data: [PlaceIcon]
}

private struct PlaceIcon: Codable {
    let targetId: Int
    let state: String
    let imageUrl: String?
}

private struct FriendsListResponse: Codable { let data: [FriendUser] }
private struct FriendUser: Codable { let id: Int; let name: String; let displayName: String }

private struct UserPresenceResponse: Codable { let userPresences: [UserPresence] }
private struct UserPresence: Codable {
    let userPresenceType: Int
    let userId: Int
    let lastLocation: String?
    let placeId: Int?
    let universeId: Int?
    let gameId: String?
    let lastOnline: String?
}

private struct UserHeadshotResponse: Codable { let data: [UserHeadshotItem] }
private struct UserHeadshotItem: Codable {
    let targetId: Int
    let state: String
    let imageUrl: String?
}

private struct LegacyGamesListResponse: Codable {
    let games: [LegacyGameItem]
    enum CodingKeys: String, CodingKey { case games = "Games" }
}

private struct LegacyGameItem: Codable {
    let creatorName: String?
    let creatorId: Int?
    let placeId: Int
    let name: String
    let universeId: Int?
    let description: String?
    let playerCount: Int?
    let totalUpVotes: Int?
    let totalDownVotes: Int?
    
    enum CodingKeys: String, CodingKey {
        case creatorName = "CreatorName"
        case creatorId = "CreatorId"
        case placeId = "PlaceId"
        case name = "Name"
        case universeId = "UniverseId"
        case description = "Description"
        case playerCount = "PlayerCount"
        case totalUpVotes = "TotalUpVotes"
        case totalDownVotes = "TotalDownVotes"
    }
}

private struct UniverseLookupResponse: Codable {
    let universeId: Int
    enum CodingKeys: String, CodingKey { case universeId = "UniverseId" }
}

// MARK: - Omni Search Models
private struct GameDetailsResponse: Codable { let data: [GameDetail] }
private struct GameDetail: Codable {
    let id: Int
    let rootPlaceId: Int?
    let name: String?
    let description: String?
    let creator: GameCreator?
    let creatorName: String?
    let creatorId: Int?
    let playing: Int?
    let visits: Int?
    let favoritedCount: Int?
    
    var playerCount: Int? { playing }
}

private struct GameCreator: Codable { let id: Int; let name: String }

private struct GameIconsResponse: Codable { let data: [GameIconItem] }
private struct GameIconItem: Codable { let targetId: Int; let imageUrl: String? }

// MARK: - Error Types
enum RobloxAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidCookie
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidCookie:
            return "Invalid or expired cookie. Please check your cookie and try again."
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
