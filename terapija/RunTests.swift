#!/usr/bin/swift

import Foundation

// First, compile and run the main app to ensure everything is up-to-date
print("🔄 Compiling and importing main application...")
let mainProcess = Process()
mainProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
mainProcess.arguments = ["main.swift", "-dry-run"]
try? mainProcess.run()
mainProcess.waitUntilExit()

// Load the test suite and execute it
print("🔄 Loading test suite...")
let testContents = try String(contentsOfFile: "MedicineTests.swift", encoding: .utf8)

// Create a temporary file that imports all the necessary components
let tempTestFile = "tempTests.swift"
try """
import Foundation

// Import all the code from main.swift
\(try String(contentsOfFile: "main.swift", encoding: .utf8))

// Import the test suite
\(testContents)

// Run tests
runTests()
""".write(to: URL(fileURLWithPath: tempTestFile), atomically: true, encoding: .utf8)

print("🔄 Running tests...")
let testProcess = Process()
testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
testProcess.arguments = [tempTestFile]
try testProcess.run()
testProcess.waitUntilExit()

// Clean up the temporary file
try FileManager.default.removeItem(atPath: tempTestFile) 