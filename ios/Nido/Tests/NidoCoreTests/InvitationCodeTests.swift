import Testing
@testable import NidoCore

struct InvitationCodeTests {
    @Test
    func parsesAndFormatsGroupedNewCodesWithoutLosingCharacters() throws {
        let invitation = try #require(InvitationCode.parse("abcd-efgh-jk23"))

        #expect(invitation.displayValue == "ABCD-EFGH-JK23")
        #expect(invitation.submissionValue == "ABCDEFGHJK23")
    }

    @Test
    func preservesLegacyBase64URLCaseAndPunctuationExactly() throws {
        let legacyCode = "aBcdEFgh_IJklMNopQRstU"
        let invitation = try #require(InvitationCode.parse(legacyCode))

        #expect(invitation.displayValue == legacyCode)
        #expect(invitation.submissionValue == legacyCode)
    }

    @Test
    func rejectsIncompleteOrOverlongInputInsteadOfTruncatingIt() {
        #expect(InvitationCode.parse("ABCD-EFGH-JK2") == nil)
        #expect(InvitationCode.parse("aBcdEFgh_IJklMNopQRstUV") == nil)
    }
}
