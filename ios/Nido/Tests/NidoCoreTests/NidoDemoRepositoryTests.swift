import Foundation
import Testing
@testable import NidoCore

@Suite(.serialized)
struct NidoDemoRepositoryTests {
    @Test
    func demoAPISupportsTheDailyAndHouseholdFlows() async throws {
        let repository = NidoDemoRepository()
        let api = NidoDemoRepository.makeAPI(repository: repository)
        let token = NidoDemoRepository.accessToken

        let initial = try await api.load(accessToken: token)
        #expect(initial.profile?.babyName == NidoDemoFixtures.profile.babyName)
        #expect(Set(initial.entries.map(\.kind)) == Set(EntryKind.allCases))
        #expect(initial.caregivers.count >= 2)

        var profile = try #require(initial.profile)
        profile.babyName = "Luz"
        #expect(try await api.save(profile: profile, accessToken: token).babyName == "Luz")

        var entry = try #require(initial.entries.first)
        entry = Entry(
            id: "demo-created-entry",
            kind: .feed,
            title: "Toma",
            detail: "Biberón · 120 ml",
            occurredAt: 1_792_000_000_000,
            durationMinutes: nil,
            amountMl: 120
        )
        #expect(try await api.create(entry: entry, accessToken: token).id == entry.id)
        let edited = entry.edited(
            detail: "Biberón · 150 ml",
            occurredAt: entry.date.addingTimeInterval(60),
            durationMinutes: nil,
            amountMl: 150
        )
        #expect(try await api.update(entry: edited, accessToken: token).amountMl == 150)
        try await api.delete(entryID: entry.id, accessToken: token)
        #expect(try await api.load(accessToken: token).entries.contains { $0.id == entry.id } == false)

        let sleepStart = Date(timeIntervalSince1970: 1_792_000_000)
        #expect(try await api.syncSleep(startedAt: sleepStart, expectedStartedAt: nil, accessToken: token) == sleepStart)
        #expect(try await api.syncSleep(startedAt: nil, expectedStartedAt: sleepStart, accessToken: token) == nil)

        let invitation = try await api.inviteCaregiver(name: "Alex", accessToken: token)
        #expect(invitation.status == .pending)
        #expect(invitation.inviteCode != nil)
        try await api.removeCaregiver(id: invitation.id, accessToken: token)

        await #expect(throws: APIError.server(status: 409, message: "Ya formas parte de este hogar.")) {
            try await api.joinCaregiver(code: "DEMO-1234", accessToken: token)
        }
        let caregiversAfterJoin = try await api.load(accessToken: token).caregivers
        #expect(caregiversAfterJoin.first { $0.inviteCode == "DEMO-1234" }?.status == .pending)

        try await api.logout(accessToken: token)
        let reset = try await api.load(accessToken: token)
        #expect(reset.profile?.babyName == NidoDemoFixtures.profile.babyName)
        #expect(reset.entries.contains { $0.id == entry.id } == false)
    }

    @Test
    func demoRepositoryRejectsForeignHostsAndCredentials() async throws {
        let repository = NidoDemoRepository()
        var request = URLRequest(url: URL(string: "https://api.nido.app/api/nido")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(NidoDemoRepository.accessToken)", forHTTPHeaderField: "Authorization")
        let foreignHost = try await repository.handle(request)
        #expect((foreignHost.1 as? HTTPURLResponse)?.statusCode == 403)

        request.url = URL(string: "https://demo.nido.invalid/api/nido")
        request.setValue("Bearer production-token", forHTTPHeaderField: "Authorization")
        let foreignCredential = try await repository.handle(request)
        #expect((foreignCredential.1 as? HTTPURLResponse)?.statusCode == 401)
    }

    @Test
    func demoRepositoryNeverSimulatesAppleAuthenticationOrDeletion() async throws {
        let repository = NidoDemoRepository()
        for (method, path) in [
            ("POST", "/api/nido/auth/apple/challenge"),
            ("POST", "/api/nido/auth/apple/session"),
            ("DELETE", "/api/nido/auth/account"),
        ] {
            var request = URLRequest(url: URL(string: "https://demo.nido.invalid\(path)")!)
            request.httpMethod = method
            request.setValue("Bearer \(NidoDemoRepository.accessToken)", forHTTPHeaderField: "Authorization")
            let response = try await repository.handle(request)
            #expect((response.1 as? HTTPURLResponse)?.statusCode == 403)
        }
        #expect(await repository.snapshot().profile.babyName == NidoDemoFixtures.profile.babyName)
    }
}
