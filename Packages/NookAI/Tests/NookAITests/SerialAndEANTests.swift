import Testing
@testable import NookAI

@Test func serialLabelsRankFirstAndAreStripped() {
    let reading = SerialParser.read(lines(["BREWMASTER", "MODEL: EM-4200", "S/N: 7XK2-48812-QA", "MFD 2025-03",
                                           "120V ~ 60Hz 1350W"]))
    #expect(reading.serial == "7XK2-48812-QA")
    #expect(reading.model == "EM-4200")
    #expect(reading.lines.map(\.kind).prefix(2) == [.serial, .model])
    #expect(reading.lines.count == 5)
}

@Test(arguments: ["SN 12345", "Serial No. 12345", "SER# 12345", "Serial Number: 12345", "s/n 12345"])
func serialLabelVariants(line: String) {
    #expect(SerialParser.read(lines([line])).serial == "12345")
}

@Test func unlabeledCodesRankAboveWords() {
    let reading = SerialParser.read(lines(["Made in China", "C02XK1JHJG5J"]))
    #expect(reading.lines.first?.value == "C02XK1JHJG5J")
    #expect(reading.serial == nil)
}

@Test(arguments: ["4006381333931", "96385074", "036000291452", "01234565", "0012345678905"])
func validBarcodes(code: String) { #expect(EAN.isValid(code)) }

@Test(arguments: ["4006381333932", "96385075", "036000291453", "12345", "40063813339A1", ""])
func invalidBarcodes(code: String) { #expect(!EAN.isValid(code)) }
