import Foundation

// Import the Models module - in Swift all files in the same module are accessible
// Explicit import is not needed, but we need to specify TimingRule enum values explicitly
class MedicineParser {
    static func parseMedicineList(from filePath: String) -> [Medicine] {
        var medicines: [Medicine] = []
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("//") } // Skip comments
            
            for line in lines {
                if let medicine = parseMedicineLine(line) {
                    medicines.append(medicine)
                }
            }
        } catch {
            print("Error reading medicine list file: \(error)")
        }
        
        return medicines
    }
    
    private static func parseMedicineLine(_ line: String) -> Medicine? {
        // Lines are expected to be in format: "- MedicineName: instructions"
        guard line.hasPrefix("-") else { return nil }
        
        // Remove the leading dash and trim whitespace
        var medicineText = line.dropFirst().trimmingCharacters(in: .whitespaces)
        
        // Split by colon to get name and instructions
        guard let colonIndex = medicineText.firstIndex(of: ":") else { return nil }
        
        let name = String(medicineText[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let instructionsText = String(medicineText[medicineText.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        
        // Parse timing rules and special notes from the instructions
        let (rules, notes) = parseRulesAndNotes(from: instructionsText)
        
        return Medicine(
            name: name,
            dosageInstructions: instructionsText,
            timingRules: rules,
            specialNotes: notes
        )
    }
    
    private static func parseRulesAndNotes(from instructions: String) -> ([TimingRule], [String]) {
        var rules: [TimingRule] = []
        var notes: [String] = []
        
        // Parse per-day dosage
        if instructions.contains("1x per day") {
            rules.append(TimingRule.timesPerDay(1))
        } else if instructions.contains("2x per day") {
            rules.append(TimingRule.timesPerDay(2))
        } else if instructions.contains("3x per day") {
            rules.append(TimingRule.timesPerDay(3))
        }
        
        // Parse timing relative to food
        if instructions.contains("on empty stomach") {
            rules.append(TimingRule.emptyStomach)
        }
        if instructions.contains("after breakfast") {
            rules.append(TimingRule.specificMeal("breakfast"))
        }
        if instructions.contains("with the dinner") {
            rules.append(TimingRule.specificMeal("dinner"))
        }
        
        // Parse separation from other medicines
        if let range = instructions.range(of: "must be taken at least (\\d+)-(\\d+)h apart from ([\\w]+)", options: .regularExpression) {
            let matchedText = String(instructions[range])
            // Simple extraction - in a real app would use proper regex capturing groups
            if matchedText.contains("Utrogestan") {
                rules.append(TimingRule.separationFromMedicine(medicineName: "Utrogestan", minutes: 90)) // Using average of 1-2h = 90min
            }
        }
        
        // Parse special notes
        if instructions.contains("NOT with milk NOR calcium") {
            notes.append("Do not take with milk or calcium")
        }
        if instructions.contains("with C vitamin or citruses") {
            notes.append("Take with vitamin C or citrus")
        }
        
        // Add any complex instructions as custom rules
        if instructions.contains("4 days = 50mg + 3 days = 75mg") {
            rules.append(TimingRule.custom(description: "4 days 50mg + 3 days 75mg rotation"))
            notes.append("Rotating schedule: 50mg for 4 days, then 75mg for 3 days")
        }
        
        return (rules, notes)
    }
} 