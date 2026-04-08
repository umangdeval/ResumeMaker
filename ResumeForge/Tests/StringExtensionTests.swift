import Testing
@testable import ResumeForge

@Suite("String+Extensions")
struct StringExtensionTests {
    @Test("isNotEmpty returns false for blank string")
    func blankStringIsEmpty() {
        #expect("   ".isNotEmpty == false)
        #expect("".isNotEmpty == false)
    }

    @Test("isNotEmpty returns true for non-blank string")
    func nonBlankStringIsNotEmpty() {
        #expect("hello".isNotEmpty == true)
    }

    @Test("trimmed removes leading and trailing whitespace")
    func trimmed() {
        #expect("  hello  ".trimmed == "hello")
    }

    @Test("nonBlankLines filters empty lines")
    func nonBlankLines() {
        let input = "line1\n\nline2\n   \nline3"
        #expect(input.nonBlankLines == ["line1", "line2", "line3"])
    }
}
