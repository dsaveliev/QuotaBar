import Foundation

/// Suite entry point. Run with `swift run quotabar-tests`.
///
/// This is an executable rather than a `.testTarget` because the installed
/// toolchain ships neither XCTest nor the swift-testing module, so `swift test`
/// cannot run here at all.
@main
enum Runner {
    static func main() async {
        let cases: [TestCase] =
            RowOrderTests.cases
            + DurationFormatTests.cases
            + PercentFormatTests.cases
            + SampleHistoryTests.cases
            + RunwayProjectionTests.cases
            + VerdictTests.cases
            + ZaiProviderTests.cases
            + MiniMaxProviderTests.cases
            + CredentialTests.cases
            + QuotaHTTPClientTests.cases
            + SettingsTests.cases
            + MenuBarItemsTests.cases
            + HistoryStoreTests.cases
            + QuotaEngineTests.cases
            + SecretHygieneTests.cases



        print("QuotaBarKit — \(cases.count) cases\n")
        await Harness.run(cases)
    }
}