import Testing
@testable import Spent

struct PhoneAppsTests {
    @Test func cleansStoreNames() {
        #expect(PhoneApps.clean("Gmail - Email by Google") == "Gmail")
        #expect(PhoneApps.clean("INDmoney: US Stocks, Mutual Funds") == "INDmoney")
        #expect(PhoneApps.clean("WhatsApp Messenger") == "WhatsApp Messenger")
        #expect(PhoneApps.clean("Shop Fast, Pay Easy") == "Shop Fast")
    }

    @Test func builtinsAndGuesses() {
        #expect(PhoneApps.name("com.google.ios.youtube", allowNetwork: false) == "YouTube")
        #expect(PhoneApps.name("com.apple.InCallService", allowNetwork: false) == "Phone")
        #expect(PhoneApps.guess("com.example.ios") == "Example")
        #expect(PhoneApps.guess("com.acme.fancy-app") == "Fancy app")
    }
}
