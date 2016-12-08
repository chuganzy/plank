#!/usr/bin/swift

import Foundation

var classNames: [String] = []

func printTestCaseExtension(withClassName className:String, andTestNames testNames:[String]) -> String {
    classNames.append(className)
    let testLines = testNames.map { (testName) -> String in
        return  "       (\"\(testName)\", \(testName))"
    }.joined(separator: ",\n")

	let output = [
        "// Generated Test Extension for \(className)",
		"extension \(className) {",
        "   static var allTests = [",
                    testLines,
        "   ]",
		"}",
		""
	].joined(separator: "\n")

    return output
}


func printLinuxMain(withClassNames classNames:[String]) -> String {
    let classNameList = classNames.map { (className) -> String in
        return "   tests += [testCase(\(className).allTests)]"
    }.joined(separator: "\n")
    return [
        "// @generated - Generated by GeneratedTestCaseProvider.swift",
        "import XCTest",
        "@testable import pinmodelTests",
        "",
        "var tests = [XCTestCaseEntry]()",
        classNameList,
        "XCTMain(tests)"
    ].joined(separator: "\n")
}

func processFile(withPath path:String) -> String {
    if path == "GenerateTestCaseProvider.swift" {
        return ""
    }

    if let file = try? String(contentsOfFile: path, encoding: .utf8) {
		var output: [String] = []
        var currentClassName: String? = nil
        var testNames: [String] = []
        file.enumerateLines { (currentLine, stop) in
            let line = currentLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if line.hasPrefix("class") {
                // class FooBar: XCTestCase
                if let className = line.components(separatedBy:
                    ":").first?.replacingOccurrences(of: "class", with:
                        "").trimmingCharacters(in: CharacterSet.whitespaces) {
					if currentClassName != className {
						if currentClassName != nil && testNames.count > 0 {
							output.append(printTestCaseExtension(withClassName: currentClassName!, andTestNames: testNames))
						}
						currentClassName = className
						testNames = []
					}
				}
            } else if line.contains("test") && line.contains("func") {
				let testComponent =
					line.components(separatedBy: " ")
					.map{ $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
					.filter { $0 != "" }
					.filter { $0.hasPrefix("test") }

				if let testName = testComponent.first?.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "") {
					testNames.append(testName)
				}	else {
					print("Error parsing test declaration with line: \(line)")
				}
			}
        }

        if currentClassName != nil && testNames.count > 0 {
            output.append(printTestCaseExtension(withClassName: currentClassName!, andTestNames: testNames))
        }

        return output.joined(separator: "\n")
    }
    return ""
}

func processDirectory() {
    if let executionPath = ProcessInfo.processInfo.environment["PWD"] {
        if let files = try? FileManager.default.contentsOfDirectory(atPath: executionPath) {

            let generatedOutput = files.map { processFile(withPath: $0) }.joined(separator: "\n")
            let output = [
                "// @generated by GenerateTestCaseProvider.swift",
                "import XCTest",
                "",
                "#if os(Linux)",
                generatedOutput,
                "#endif"
            ].joined(separator: "\n")
            try? output.write(toFile: "LinuxTestIndex.swift", atomically: true, encoding: .utf8)

            let linuxMainOutput = printLinuxMain(withClassNames: classNames)
            try? linuxMainOutput.write(toFile: "../LinuxMain.swift", atomically: true, encoding: .utf8)
        }
    } else {
        return print("invalid pwd")
    }
}

processDirectory()