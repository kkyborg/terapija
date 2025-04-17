//
//  main.swift
//  terapija
//
//  Created by Nemanja Bondzulic on 14.04.2025.
//

import Foundation

// MARK: - Models

// Medicine model to store details about each medicine
struct Medicine {
    let name: String
    let dosageInstructions: String
    let timingRules: [TimingRule]
    let specialNotes: [String]
    
    // Helper function to determine if this medicine can be taken at a specific time
    func canBeTakenAt(dailyEvent: DailyEvent, takenMedicines: [String]) -> Bool {
        for rule in timingRules {
            switch rule {
            case .emptyStomach:
                if dailyEvent.type == .meal || dailyEvent.timeSinceLastMeal < 60 {
                    return false
                }
            case .withFood:
                if dailyEvent.type != .meal {
                    return false
                }
            case .specificMeal(let meal):
                if dailyEvent.type != .meal || dailyEvent.name.lowercased() != meal.lowercased() {
                    return false
                }
            case .specificTime(let time):
                // Simple time string comparison for now
                if dailyEvent.time != time {
                    return false
                }
            case .timesPerDay(_):
                // This would be handled by the scheduler
                continue
            case .separationFromMedicine(let medicineName, _):
                for takenMedicine in takenMedicines {
                    if takenMedicine == medicineName {
                        // Would need more complex time comparison in a real app
                        return false
                    }
                }
            case .custom(_):
                // Custom rules would need special handling
                continue
            case .togetherWithMedicine(let medicineName):
                if dailyEvent.name.lowercased() != medicineName.lowercased() {
                    return false
                }
            }
        }
        return true
    }
}

// Enum to represent different timing rules for medicines
enum TimingRule: Equatable {
    case emptyStomach
    case withFood
    case specificMeal(String) // e.g., "breakfast", "lunch", "dinner"
    case specificTime(String) // e.g., "08:00", "20:00"
    case timesPerDay(Int)    // e.g., 2 times per day
    case separationFromMedicine(medicineName: String, minutes: Int)
    case togetherWithMedicine(medicineName: String) // e.g., "together with Heferal"
    case custom(description: String)
    
    // Swift can automatically synthesize Equatable for enums with associated values
    // but we'll add it explicitly for clarity
    static func == (lhs: TimingRule, rhs: TimingRule) -> Bool {
        switch (lhs, rhs) {
        case (.emptyStomach, .emptyStomach):
            return true
        case (.withFood, .withFood):
            return true
        case (.specificMeal(let lhsMeal), .specificMeal(let rhsMeal)):
            return lhsMeal == rhsMeal
        case (.specificTime(let lhsTime), .specificTime(let rhsTime)):
            return lhsTime == rhsTime
        case (.timesPerDay(let lhsCount), .timesPerDay(let rhsCount)):
            return lhsCount == rhsCount
        case (.separationFromMedicine(let lhsMedicine, let lhsMinutes), 
              .separationFromMedicine(let rhsMedicine, let rhsMinutes)):
            return lhsMedicine == rhsMedicine && lhsMinutes == rhsMinutes
        case (.togetherWithMedicine(let lhsMedicine), .togetherWithMedicine(let rhsMedicine)):
            return lhsMedicine == rhsMedicine
        case (.custom(let lhsDesc), .custom(let rhsDesc)):
            return lhsDesc == rhsDesc
        default:
            return false
        }
    }
}

// Daily events that influence medicine scheduling
struct DailyEvent {
    enum EventType {
        case wakeUp
        case meal
        case sleep
        case medicineTime
    }
    
    let name: String
    let type: EventType
    let time: String
    var timeSinceLastMeal: Int = Int.max // Minutes since last meal
}

// Represents a scheduled medicine dose
struct ScheduledDose {
    let medicine: Medicine
    let event: DailyEvent
    let quantity: String
    let notes: String
}

// The complete daily schedule
struct DailySchedule {
    let date: Date
    let events: [DailyEvent]
    let scheduledDoses: [ScheduledDose]
    
    func printSchedule() {
        print("Daily Medicine Schedule for \(formatDate(date))")
        print("------------------------------------------")
        
        // Collect all exceptions first for display at the top
        var exceptions: [String] = []
        for dose in scheduledDoses {
            for note in dose.medicine.specialNotes {
                if note.hasPrefix("Exception:") {
                    let formattedNote = "⚠️ \(note.replacingOccurrences(of: "Exception: ", with: ""))"
                    if !exceptions.contains(formattedNote) {
                        exceptions.append(formattedNote)
                    }
                }
            }
        }
        
        // Display exceptions at the top if there are any
        if !exceptions.isEmpty {
            print("⚠️ SPECIAL INSTRUCTIONS FOR TODAY ⚠️")
            for exception in exceptions {
                print(exception)
            }
            print("------------------------------------------")
        }
        
        // Create a combined timeline of events and doses
        var timelineByTime: [String: [(isEvent: Bool, name: String, details: String)]] = [:]
        
        // Add daily events to the timeline
        for event in events {
            if timelineByTime[event.time] == nil {
                timelineByTime[event.time] = []
            }
            
            // Format the event entry with specific meal emojis
            var eventDetails = ""
            switch event.type {
            case .wakeUp:
                eventDetails = "" // Remove "Start of day" text for wake up
            case .meal:
                if event.name.lowercased() == "breakfast" {
                    eventDetails = "🥑"
                } else if event.name.lowercased() == "lunch" {
                    eventDetails = "🍗"
                } else if event.name.lowercased() == "dinner" {
                    eventDetails = "🍝"
                } else {
                    eventDetails = ""
                }
            case .sleep:
                eventDetails = "" // Remove "End of day" text for sleep
            case .medicineTime:
                eventDetails = "Medicine time"
            }
            
            timelineByTime[event.time]?.append((isEvent: true, name: event.name, details: eventDetails))
        }
        
        // Add medicine doses to the timeline
        for dose in scheduledDoses {
            if timelineByTime[dose.event.time] == nil {
                timelineByTime[dose.event.time] = []
            }
            
            // Format the dose entry
            var medicineName = dose.medicine.name
            
            // Remove "200mg" from Utrogestan display name
            if medicineName.contains("Utrogestan") {
                medicineName = "UTROGESTAN"
            } else {
                medicineName = medicineName.uppercased()
            }
            
            // Simplify dose numbers (remove "dose" text)
            var doseDetails = dose.notes.isEmpty ? dose.quantity : "\(dose.quantity) - \(dose.notes)"
            if doseDetails.contains("dose") && doseDetails.contains("of") {
                doseDetails = doseDetails.replacingOccurrences(of: "dose ", with: "")
            }
            
            // Also clean up "Middle dose" to just "Middle"
            doseDetails = doseDetails.replacingOccurrences(of: "Middle dose", with: "Middle")
            
            timelineByTime[dose.event.time]?.append((isEvent: false, name: medicineName, details: doseDetails))
        }
        
        // Sort times and print timeline
        let sortedTimes = timelineByTime.keys.sorted()
        
        for time in sortedTimes {
            print("\(time):")
            
            // Sort to show events first, then medicines
            let sortedEntries = timelineByTime[time]!.sorted { $0.isEvent && !$1.isEvent }
            
            for entry in sortedEntries {
                if entry.isEvent {
                    if entry.name == "Wake Up" {
                        print("  ☀️  \(entry.name)")
                    } else if entry.name == "Sleep" {
                        print("  🛏️  \(entry.name)")
                    } else if entry.name == "Breakfast" {
                        print("  🥑 \(entry.name)")
                        print("")  // Add a newline after Breakfast
                    } else if entry.name == "Lunch" {
                        print("  🍗 \(entry.name)")
                        print("")  // Add a newline after Lunch
                    } else if entry.name == "Dinner" {
                        print("  🍝 \(entry.name)")
                        print("")  // Add a newline after Dinner
                    } else if !entry.details.isEmpty {
                        print("  📅 \(entry.name)")
                    } else {
                        print("  📅 \(entry.name)")
                    }
                } else {
                    // Use only uppercase for medicine names, without asterisks or emoji
                    print("  💊 \(entry.name): \(entry.details)")
                }
            }
            print("")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Parsers

class MedicineParser {
    // Structure to hold parsed exceptions with dose specificity
    struct MedicineException {
        let medicineName: String
        let doseNumber: Int?
        let instruction: String
        let rawText: String
    }
    
    static func parseMedicineList(from filePath: String) -> [Medicine] {
        var medicines: [Medicine] = []
        var exceptions: [MedicineException] = [] // Store parsed exceptions
        var currentSection = "RULES" // Default section
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("//") } // Skip comments
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check for section headers
                if trimmedLine.hasPrefix("# ") {
                    currentSection = trimmedLine.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    continue
                }
                
                // Process line based on current section
                if currentSection == "RULES" {
                    if let medicine = parseMedicineLine(line) {
                        medicines.append(medicine)
                    }
                } else if currentSection == "EXCEPTIONS" {
                    if let exception = parseExceptionLine(line) {
                        exceptions.append(exception)
                    }
                }
            }
            
            // Now apply exceptions to the medicines
            for i in 0..<medicines.count {
                let medicineName = medicines[i].name
                
                // Find exceptions that apply to this medicine
                let medicineExceptions = exceptions.filter { $0.medicineName == medicineName }
                
                if !medicineExceptions.isEmpty {
                    var updatedNotes = medicines[i].specialNotes
                    
                    // Add exceptions as special notes
                    for exception in medicineExceptions {
                        let doseSpecificText = exception.doseNumber != nil ? 
                            "Exception: For dose \(exception.doseNumber!), \(exception.instruction)" :
                            "Exception: \(exception.instruction)"
                        
                        updatedNotes.append(doseSpecificText)
                    }
                    
                    // Update the medicine with exceptions
                    medicines[i] = Medicine(
                        name: medicines[i].name,
                        dosageInstructions: medicines[i].dosageInstructions,
                        timingRules: medicines[i].timingRules,
                        specialNotes: updatedNotes
                    )
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
        let medicineText = line.dropFirst().trimmingCharacters(in: .whitespaces)
        
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
    
    private static func parseExceptionLine(_ line: String) -> MedicineException? {
        // Exception format: "- MedicineName: instruction"
        // or dose-specific format: "- MedicineName: dose N, instruction"
        guard line.hasPrefix("-") else { return nil }
        
        // Remove the leading dash and trim whitespace
        let exceptionText = line.dropFirst().trimmingCharacters(in: .whitespaces)
        
        // Split by colon to get name and instructions
        guard let colonIndex = exceptionText.firstIndex(of: ":") else { return nil }
        
        let medicineName = String(exceptionText[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let instructionText = String(exceptionText[exceptionText.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        
        // Check if this is a dose-specific exception (e.g., "dose 3, with the dinner")
        let dosePattern = "dose (\\d+),\\s*(.*)"
        if let regex = try? NSRegularExpression(pattern: dosePattern, options: []),
           let match = regex.firstMatch(in: instructionText, options: [], range: NSRange(instructionText.startIndex..., in: instructionText)) {
            
            if let numberRange = Range(match.range(at: 1), in: instructionText),
               let instructionRange = Range(match.range(at: 2), in: instructionText) {
                
                let doseNumber = Int(String(instructionText[numberRange]))
                let specificInstruction = String(instructionText[instructionRange]).trimmingCharacters(in: .whitespaces)
                
                return MedicineException(
                    medicineName: medicineName,
                    doseNumber: doseNumber,
                    instruction: specificInstruction,
                    rawText: line
                )
            }
        }
        
        // Regular exception (applies to all doses)
        return MedicineException(
            medicineName: medicineName,
            doseNumber: nil,
            instruction: instructionText,
            rawText: line
        )
    }
    
    private static func parseRulesAndNotes(from instructions: String) -> ([TimingRule], [String]) {
        var rules: [TimingRule] = []
        var notes: [String] = []
        
        // Parse per-day dosage using regex to handle any number of doses
        // Pattern to match "Nx per day" or simply "Nx" where N is any number
        let dosePattern1 = "(\\d+)x per day"
        let dosePattern2 = "(\\d+)x"
        
        // First try the "Nx per day" pattern
        if let range = instructions.range(of: dosePattern1, options: .regularExpression),
           let numberRange = instructions[range].range(of: "\\d+", options: .regularExpression) {
            let doseNumber = String(instructions[numberRange])
            if let dosesPerDay = Int(doseNumber) {
                rules.append(.timesPerDay(dosesPerDay))
            }
        }
        // If not found, try the simpler "Nx" pattern
        else if let range = instructions.range(of: dosePattern2, options: .regularExpression),
                let numberRange = instructions[range].range(of: "\\d+", options: .regularExpression) {
            let doseNumber = String(instructions[numberRange])
            if let dosesPerDay = Int(doseNumber) {
                rules.append(.timesPerDay(dosesPerDay))
            }
        }
        
        // Parse timing relative to food
        if instructions.contains("on empty stomach") {
            rules.append(.emptyStomach)
        }
        if instructions.contains("after breakfast") || instructions.contains("recommended after breakfast") {
            rules.append(.specificMeal("Breakfast"))
            notes.append("Take after breakfast")
        }
        if instructions.contains("with the dinner") {
            rules.append(.specificMeal("Dinner"))
        }
        
        // Parse timing relative to other medicines
        if instructions.contains("before taking the food and any other medicines") || 
           instructions.contains("before any other medicines") {
            rules.append(.custom(description: "Take before any other medicines"))
            notes.append("Must be taken before any other medicines")
        }
        
        // Parse "together with" instructions
        if instructions.contains("together with") {
            if instructions.contains("together with Heferal") {
                rules.append(.togetherWithMedicine(medicineName: "Heferal"))
                notes.append("Take together with Heferal")
            } else if instructions.contains("together with C vitamin") || instructions.contains("with C vitamin") {
                rules.append(.togetherWithMedicine(medicineName: "Vitamin C"))
                notes.append("Take together with Vitamin C")
            }
            
            // Generic pattern match for "together with" instructions
            let pattern = "together with ([\\w\\s]+)"
            if let range = instructions.range(of: pattern, options: .regularExpression) {
                let matchedText = String(instructions[range])
                let components = matchedText.components(separatedBy: "together with ")
                if components.count > 1 {
                    let medicineName = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    // Skip if we've already handled specific cases
                    if medicineName != "Heferal" && medicineName != "C vitamin" && !medicineName.contains("vitamin") {
                        rules.append(.togetherWithMedicine(medicineName: medicineName))
                        notes.append("Take together with \(medicineName)")
                    }
                }
            }
        }
        
        // Parse separation from other medicines - improved to catch more patterns
        if instructions.contains("apart from") {
            // Specifically look for Nifelat and Utrogestan separation
            if instructions.contains("must be taken at least 1-2h apart from Utrogestan") {
                rules.append(.separationFromMedicine(medicineName: "Utrogestan", minutes: 90)) // Using average of 1-2h = 90min
                notes.append("Must be taken at least 1-2 hours apart from Utrogestan")
            }
            
            // Generic pattern match for other separations
            if let range = instructions.range(of: "must be taken at least (\\d+)-(\\d+)h apart from ([\\w]+)", options: .regularExpression) {
                let matchedText = String(instructions[range])
                
                // Try to extract the actual hour ranges and medicine name
                let components = matchedText.components(separatedBy: " ")
                if components.count >= 7 {
                    let hourRangeText = components[4]
                    let medicineName = components[6]
                    
                    // Parse the hour range (e.g., "1-2h")
                    let hourRangeComponents = hourRangeText.components(separatedBy: "-")
                    if hourRangeComponents.count == 2, 
                       let minHours = Int(hourRangeComponents[0]),
                       let maxHours = Int(hourRangeComponents[1].replacingOccurrences(of: "h", with: "")) {
                        
                        // Average of the range
                        let avgHours = (minHours + maxHours) / 2
                        let minutes = avgHours * 60
                        
                        // Don't add a duplicate rule if already added by the specific case
                        if medicineName != "Utrogestan" || !rules.contains(where: { 
                            if case .separationFromMedicine(let name, _) = $0, name == "Utrogestan" {
                                return true
                            }
                            return false
                        }) {
                            rules.append(.separationFromMedicine(medicineName: medicineName, minutes: minutes))
                            notes.append("Must be taken at least \(minHours)-\(maxHours) hours apart from \(medicineName)")
                        }
                    }
                }
            }
        }
        
        // Parse special notes
        if instructions.contains("NOT with milk NOR calcium") {
            notes.append("Do not take with milk or calcium")
        }
        
        // Add any complex instructions as custom rules
        if instructions.contains("4 days = 50mg + 3 days = 75mg") {
            rules.append(.custom(description: "4 days 50mg + 3 days 75mg rotation"))
        }
        
        return (rules, notes)
    }
}

// MARK: - Scheduler

class MedicineScheduler {
    private let medicines: [Medicine]
    private var dailyEvents: [DailyEvent] = []
    private var scheduledMedicinesByTime: [String: [Medicine]] = [:]
    private var scheduledDoses: [ScheduledDose] = [] // Keep track of all scheduled doses
    private var exceptions: [MedicineParser.MedicineException] = []
    
    init(medicines: [Medicine]) {
        self.medicines = medicines
    }
    
    func setDailyEvents(wakeUpTime: String, breakfastTime: String, lunchTime: String, dinnerTime: String, sleepTime: String) {
        dailyEvents = [
            DailyEvent(name: "Wake Up", type: .wakeUp, time: wakeUpTime),
            DailyEvent(name: "Breakfast", type: .meal, time: breakfastTime),
            DailyEvent(name: "Lunch", type: .meal, time: lunchTime),
            DailyEvent(name: "Dinner", type: .meal, time: dinnerTime),
            DailyEvent(name: "Sleep", type: .sleep, time: sleepTime)
        ]
        
        // Sort events by time
        dailyEvents.sort { $0.time < $1.time }
    }
    
    func generateSchedule() -> DailySchedule {
        var finalScheduledDoses: [ScheduledDose] = []
        scheduledMedicinesByTime = [:]
        scheduledDoses = [] // Reset tracked doses
        var eutiroxTime: String? = nil
        
        // Extract exceptions from medicine notes for later use
        extractExceptions()
        
        // First, handle Eutirox separately since it must be taken before all other medicines
        if let eutirox = medicines.first(where: { $0.name == "Eutirox" }) {
            // Schedule Eutirox first, before any other medicine
            scheduleSpecificMedicine(eutirox, into: &finalScheduledDoses)
            
            // Record the time Eutirox is scheduled
            if let eutiroxDose = finalScheduledDoses.first(where: { $0.medicine.name == "Eutirox" }) {
                eutiroxTime = eutiroxDose.event.time
            }
        }
        
        // Ensure the wakeup time is after Eutirox for all other medicines
        var adjustedDailyEvents = dailyEvents
        if let eutiroxTime = eutiroxTime,
           let wakeUpEvent = dailyEvents.first(where: { $0.type == .wakeUp }) {
            // Create a new wake up event that's after Eutirox
            let eutiroxComponents = eutiroxTime.split(separator: ":").map { Int($0) ?? 0 }
            let eutiroxMinutes = eutiroxComponents[0] * 60 + eutiroxComponents[1]
            
            // Add 10 minutes to ensure it's after Eutirox
            let newWakeUpMinutes = eutiroxMinutes + 10
            let newWakeUpHour = newWakeUpMinutes / 60
            let newWakeUpMinute = newWakeUpMinutes % 60
            
            let newWakeUpTime = String(format: "%02d:%02d", newWakeUpHour, newWakeUpMinute)
            
            // Create a new wake up event that comes after Eutirox
            let newWakeUpEvent = DailyEvent(
                name: wakeUpEvent.name,
                type: wakeUpEvent.type,
                time: newWakeUpTime,
                timeSinceLastMeal: wakeUpEvent.timeSinceLastMeal
            )
            
            // Replace the old wake up event with the new one
            adjustedDailyEvents.removeAll { $0.type == .wakeUp }
            adjustedDailyEvents.append(newWakeUpEvent)
            
            // Sort events by time again
            adjustedDailyEvents.sort { $0.time < $1.time }
        }
        
        // Use the adjusted daily events for the rest of the scheduling
        let originalDailyEvents = dailyEvents
        dailyEvents = adjustedDailyEvents
        
        // Then separate medicines with separation constraints from those without
        let medicinesWithSeparation = medicines.filter { medicine in
            medicine.name != "Eutirox" && medicine.timingRules.contains { rule in
                if case .separationFromMedicine(_, _) = rule { return true }
                return false
            }
        }
        
        let medicinesWithoutSeparation = medicines.filter { medicine in
            medicine.name != "Eutirox" && !medicinesWithSeparation.contains { $0.name == medicine.name }
        }
        
        // Schedule medicines without separation constraints first
        scheduleMultipleMedicines(medicinesWithoutSeparation, into: &finalScheduledDoses)
        
        // Then schedule medicines with separation constraints
        scheduleMultipleMedicines(medicinesWithSeparation, into: &finalScheduledDoses)
        
        // SPECIAL HANDLING: Detect and fix specific Nifelat/Utrogestan conflict
        fixNifelatUtrogestanConflict(&finalScheduledDoses)
        
        // Apply dose-specific exceptions
        applyDoseSpecificExceptions(&finalScheduledDoses)
        
        // Restore original daily events
        dailyEvents = originalDailyEvents
        
        return DailySchedule(
            date: Date(),
            events: dailyEvents,
            scheduledDoses: finalScheduledDoses
        )
    }
    
    private func scheduleSpecificMedicine(_ medicine: Medicine, into scheduledDoses: inout [ScheduledDose]) {
        let dosesPerDay = medicine.timingRules.compactMap { rule -> Int? in
            if case .timesPerDay(let count) = rule {
                return count
            }
            return nil
        }.first ?? 1 // Default to once per day if not specified
        
        // Find suitable events for this medicine based on its rules
        let suitableEvents = findCandidateEvents(for: medicine, dosesPerDay: dosesPerDay)
        
        // Keep track of which medicines are scheduled at which times
        for event in suitableEvents {
            // Determine quantity based on medicine-specific rules
            let quantity = determineQuantity(for: medicine, at: event, dosesPerDay: dosesPerDay)
            
            // Add this medicine to the schedule
            let dose = ScheduledDose(
                medicine: medicine,
                event: event,
                quantity: quantity,
                notes: getNotes(for: medicine, at: event)
            )
            
            scheduledDoses.append(dose)
            self.scheduledDoses.append(dose) // Add to the class property as well
            
            // Keep track of what medicines are scheduled at what times
            if scheduledMedicinesByTime[event.time] == nil {
                scheduledMedicinesByTime[event.time] = []
            }
            scheduledMedicinesByTime[event.time]?.append(medicine)
        }
    }
    
    private func scheduleMultipleMedicines(_ medicinesToSchedule: [Medicine], into scheduledDoses: inout [ScheduledDose]) {
        // Schedule medicines in order of constraints (most constrained first)
        let sortedMedicines = medicinesToSchedule.sorted { med1, med2 in
            return med1.timingRules.count > med2.timingRules.count
        }
        
        for medicine in sortedMedicines {
            let dosesPerDay = medicine.timingRules.compactMap { rule -> Int? in
                if case .timesPerDay(let count) = rule {
                    return count
                }
                return nil
            }.first ?? 1 // Default to once per day if not specified
            
            // Find suitable events for this medicine based on its rules
            let suitableEvents = findCandidateEvents(for: medicine, dosesPerDay: dosesPerDay)
            
            // Keep track of which medicines are scheduled at which times
            for event in suitableEvents {
                // Determine quantity based on medicine-specific rules
                let quantity = determineQuantity(for: medicine, at: event, dosesPerDay: dosesPerDay)
                
                // Add this medicine to the schedule
                let dose = ScheduledDose(
                    medicine: medicine,
                    event: event,
                    quantity: quantity,
                    notes: getNotes(for: medicine, at: event)
                )
                
                scheduledDoses.append(dose)
                self.scheduledDoses.append(dose) // Add to the class property as well
                
                // Keep track of what medicines are scheduled at what times
                if scheduledMedicinesByTime[event.time] == nil {
                    scheduledMedicinesByTime[event.time] = []
                }
                scheduledMedicinesByTime[event.time]?.append(medicine)
            }
        }
    }
    
    private func findCandidateEvents(for medicine: Medicine, dosesPerDay: Int) -> [DailyEvent] {
        var candidates: [DailyEvent] = []
        
        // Special case for Eutirox - must be taken 30-60 minutes before breakfast
        // AND before any other medicine
        if medicine.name == "Eutirox" {
            if let breakfast = dailyEvents.first(where: { $0.name == "Breakfast" }),
               let wakeUp = dailyEvents.first(where: { $0.type == .wakeUp }) {
                
                // Move Eutirox closer to wake-up time
                // First calculate breakfast time in minutes
                let breakfastComponents = breakfast.time.split(separator: ":").map { Int($0) ?? 0 }
                let breakfastMinutes = breakfastComponents[0] * 60 + breakfastComponents[1]
                
                // Calculate wake-up time in minutes
                let wakeUpComponents = wakeUp.time.split(separator: ":").map { Int($0) ?? 0 }
                let wakeUpMinutes = wakeUpComponents[0] * 60 + wakeUpComponents[1]
                
                // Schedule Eutirox just 30 minutes after wake-up
                // But ensure it's still at least 30 minutes before breakfast
                let eutiroxMinutes = wakeUpMinutes + 30
                
                // Make sure Eutirox is at least 30 minutes before breakfast
                if (breakfastMinutes - eutiroxMinutes) < 30 {
                    // Too close to breakfast, move it back to ensure 30 min separation
                    let adjustedEutiroxMinutes = breakfastMinutes - 30
                    let eutiroxHour = adjustedEutiroxMinutes / 60
                    let eutiroxMinute = adjustedEutiroxMinutes % 60
                    
                    let timeString = String(format: "%02d:%02d", eutiroxHour, eutiroxMinute)
                    let eutiroxEvent = DailyEvent(
                        name: "First Medicine of Day (for Eutirox)",
                        type: .medicineTime,
                        time: timeString,
                        timeSinceLastMeal: 480 // Assuming 8 hours since dinner
                    )
                    
                    candidates.append(eutiroxEvent)
                } else {
                    // We have enough separation, use 30 minutes after wakeup
                    let eutiroxHour = eutiroxMinutes / 60
                    let eutiroxMinute = eutiroxMinutes % 60
                    
                    let timeString = String(format: "%02d:%02d", eutiroxHour, eutiroxMinute)
                    let eutiroxEvent = DailyEvent(
                        name: "First Medicine of Day (for Eutirox)",
                        type: .medicineTime,
                        time: timeString,
                        timeSinceLastMeal: 480 // Assuming 8 hours since dinner
                    )
                    
                    candidates.append(eutiroxEvent)
                }
                
                return candidates
            }
        }
        
        // Special case for Heferal - must be taken on empty stomach with vitamin C
        if medicine.name == "Heferal" {
            // Create two events for Heferal, evenly spaced throughout the day, on empty stomach
            if let breakfast = dailyEvents.first(where: { $0.name == "Breakfast" }),
               let dinner = dailyEvents.first(where: { $0.name == "Dinner" }) {
                
                // Check if Eutirox is already scheduled
                var morningTime = ""
                
                if let eutiroxEntry = scheduledMedicinesByTime.first(where: { $0.value.contains(where: { $0.name == "Eutirox" }) }) {
                    // Eutirox is scheduled, ensure Heferal comes after it
                    let eutiroxComponents = eutiroxEntry.key.split(separator: ":").map { Int($0) ?? 0 }
                    let eutiroxMinutes = eutiroxComponents[0] * 60 + eutiroxComponents[1]
                    
                    // Calculate 1 hour before breakfast
                    let breakfastComponents = breakfast.time.split(separator: ":").map { Int($0) ?? 0 }
                    let breakfastMinutes = breakfastComponents[0] * 60 + breakfastComponents[1]
                    let idealMorningMinutes = breakfastMinutes - 60
                    
                    // Take the later of: 1 hour before breakfast or 15 minutes after Eutirox
                    let adjustedMorningMinutes = max(idealMorningMinutes, eutiroxMinutes + 15)
                    let morningHour = adjustedMorningMinutes / 60
                    let morningMinute = adjustedMorningMinutes % 60
                    
                    morningTime = String(format: "%02d:%02d", morningHour, morningMinute)
                } else {
                    // Eutirox not scheduled yet, use regular timing (1 hour before breakfast)
                    let morningComponents = breakfast.time.split(separator: ":").map { Int($0) ?? 0 }
                    var morningHour = morningComponents[0]
                    var morningMinute = morningComponents[1] - 60 // 1 hour before breakfast
                    
                    if morningMinute < 0 {
                        morningMinute += 60
                        morningHour -= 1
                        if morningHour < 0 {
                            morningHour += 24
                        }
                    }
                    
                    morningTime = String(format: "%02d:%02d", morningHour, morningMinute)
                }
                
                let morningEvent = DailyEvent(
                    name: "Before Breakfast (for Heferal)",
                    type: .medicineTime,
                    time: morningTime,
                    timeSinceLastMeal: 480 // Assuming 8 hours since dinner
                )
                
                // 2. Evening dose: 2 hours after dinner
                let eveningComponents = dinner.time.split(separator: ":").map { Int($0) ?? 0 }
                var eveningHour = eveningComponents[0] + 2 // 2 hours after dinner
                let eveningMinute = eveningComponents[1]
                
                if eveningHour >= 24 {
                    eveningHour -= 24
                }
                
                let eveningTime = String(format: "%02d:%02d", eveningHour, eveningMinute)
                let eveningEvent = DailyEvent(
                    name: "After Dinner (for Heferal)",
                    type: .medicineTime,
                    time: eveningTime,
                    timeSinceLastMeal: 120 // 2 hours after dinner
                )
                
                candidates.append(morningEvent)
                candidates.append(eveningEvent)
                return candidates // Return immediately as this is a specific requirement
            }
        }
        
        // Special case for Utrogestan - when taken multiple times per day, 
        // include a dose right before bedtime
        if medicine.name == "Utrogestan 200mg" && dosesPerDay > 1 {
            if let breakfast = dailyEvents.first(where: { $0.name == "Breakfast" }),
               let sleepEvent = dailyEvents.first(where: { $0.type == .sleep }) {
                
                // Calculate time 2 hours after breakfast for first dose
                let breakfastComponents = breakfast.time.split(separator: ":").map { Int($0) ?? 0 }
                var afterBreakfastHour = breakfastComponents[0] + 2
                let afterBreakfastMinute = breakfastComponents[1]
                
                if afterBreakfastHour >= 24 {
                    afterBreakfastHour -= 24
                }
                
                let afterBreakfastTime = String(format: "%02d:%02d", afterBreakfastHour, afterBreakfastMinute)
                let afterBreakfastEvent = DailyEvent(
                    name: "After Breakfast (for Utrogestan)",
                    type: .medicineTime,
                    time: afterBreakfastTime
                )
                
                // Add first dose 2 hours after breakfast instead of with breakfast
                candidates.append(afterBreakfastEvent)
                
                // For the last dose, use 30 minutes before sleep
                let sleepComponents = sleepEvent.time.split(separator: ":").map { Int($0) ?? 0 }
                var beforeSleepHour = sleepComponents[0]
                var beforeSleepMinute = sleepComponents[1] - 30
                
                if beforeSleepMinute < 0 {
                    beforeSleepMinute += 60
                    beforeSleepHour -= 1
                    if beforeSleepHour < 0 {
                        beforeSleepHour += 24
                    }
                }
                
                let beforeSleepTime = String(format: "%02d:%02d", beforeSleepHour, beforeSleepMinute)
                let beforeSleepEvent = DailyEvent(
                    name: "Before Sleep (for Utrogestan)",
                    type: .medicineTime,
                    time: beforeSleepTime
                )
                
                candidates.append(beforeSleepEvent)
                
                // If more than 2 doses per day, add middle doses evenly spaced
                if dosesPerDay > 2 {
                    // Calculate first dose time in minutes since midnight
                    let firstDoseComponents = afterBreakfastTime.split(separator: ":").map { Int($0) ?? 0 }
                    let firstDoseMinutes = firstDoseComponents[0] * 60 + firstDoseComponents[1]
                    
                    // Calculate last dose time in minutes since midnight
                    let lastDoseMinutes = beforeSleepHour * 60 + beforeSleepMinute
                    
                    // Calculate the total span, handling cases where last dose is before first dose (crosses midnight)
                    let totalMinutes = lastDoseMinutes > firstDoseMinutes ? 
                        lastDoseMinutes - firstDoseMinutes : (24 * 60 - firstDoseMinutes) + lastDoseMinutes
                    
                    // For n doses per day, we need n-2 middle doses (first and last are already set)
                    let middleDoses = dosesPerDay - 2
                    
                    // Add the middle doses at evenly spaced intervals
                    for i in 1...middleDoses {
                        // Calculate the middle dose time to be proportionally spaced
                        let middleDoseMinutes = (firstDoseMinutes + (totalMinutes * i / (middleDoses + 1))) % (24 * 60)
                        
                        let middleDoseHour = middleDoseMinutes / 60
                        let middleDoseMinute = middleDoseMinutes % 60
                        
                        let middleDoseTime = String(format: "%02d:%02d", middleDoseHour, middleDoseMinute)
                        let middleDoseEvent = DailyEvent(
                            name: middleDoses == 1 ? "Middle Dose (for Utrogestan)" : "Dose \(i+1) (for Utrogestan)",
                            type: .medicineTime,
                            time: middleDoseTime
                        )
                        
                        candidates.append(middleDoseEvent)
                    }
                }
                
                // Sort by time to ensure proper sequencing
                candidates.sort { $0.time < $1.time }
                
                return candidates
            }
        }
        
        // Special case for Nifelat - take with breakfast
        if medicine.name == "Nifelat" {
            if let breakfast = dailyEvents.first(where: { $0.name == "Breakfast" }) {
                if dosesPerDay == 1 {
                    // If just one dose, take with breakfast
                    candidates.append(breakfast)
                    return candidates
                } else if dosesPerDay >= 2 {
                    // First dose with breakfast
                    candidates.append(breakfast)
                    
                    // For multiple doses, evenly distribute throughout the day
                    // Find sleep time to calculate the active day duration
                    guard let sleepEvent = dailyEvents.first(where: { $0.type == .sleep }) else {
                        return candidates
                    }
                    
                    // Convert times to minutes since midnight
                    let breakfastComponents = breakfast.time.split(separator: ":").map { Int($0) ?? 0 }
                    let breakfastMinutes = breakfastComponents[0] * 60 + breakfastComponents[1]
                    
                    let sleepComponents = sleepEvent.time.split(separator: ":").map { Int($0) ?? 0 }
                    let sleepMinutes = sleepComponents[0] * 60 + sleepComponents[1]
                    
                    // Calculate active day duration (breakfast to sleep)
                    let activeDayMinutes = sleepMinutes > breakfastMinutes ? 
                        sleepMinutes - breakfastMinutes : 
                        (24 * 60 - breakfastMinutes) + sleepMinutes
                    
                    // Divide the active day into equal parts based on doses per day
                    let interval = activeDayMinutes / dosesPerDay
                    
                    // Create events for each additional dose
                    for i in 1..<dosesPerDay {
                        let doseMinutes = (breakfastMinutes + i * interval) % (24 * 60)
                        let doseHour = doseMinutes / 60
                        let doseMinute = doseMinutes % 60
                        
                        let doseTime = String(format: "%02d:%02d", doseHour, doseMinute)
                        
                        // Name the dose based on time of day
                        let doseName: String
                        if i == dosesPerDay - 1 {
                            doseName = "Evening Dose (for Nifelat)"
                        } else if i == 1 && dosesPerDay == 3 {
                            doseName = "Midday Dose (for Nifelat)"
                        } else {
                            doseName = "Dose \(i+1) (for Nifelat)"
                        }
                        
                        let doseEvent = DailyEvent(
                            name: doseName,
                            type: .medicineTime,
                            time: doseTime
                        )
                        
                        candidates.append(doseEvent)
                    }
                    
                    // Sort by time to ensure proper sequencing
                    candidates.sort { $0.time < $1.time }
                    return candidates
                }
            }
        }
        
        // Special case for Aleract and Inofolic combi - prefer with meals
        if (medicine.name == "Aleract" || medicine.name == "Inofolic combi") {
            // These medicines don't require empty stomach, so prefer with meals
            let mealEvents = dailyEvents.filter { $0.type == .meal }
            
            if dosesPerDay > 1 {
                if mealEvents.count >= dosesPerDay {
                    // If we have enough meal events, use them
                    for i in 0..<min(dosesPerDay, mealEvents.count) {
                        candidates.append(mealEvents[i])
                    }
                } else {
                    // Not enough meal events, use meals plus evenly spaced times
                    candidates.append(contentsOf: mealEvents)
                    
                    // Calculate wakeup and sleep times to determine the active day duration
                    let wakeUpEvent = dailyEvents.first(where: { $0.type == .wakeUp }) ?? dailyEvents.first!
                    let sleepEvent = dailyEvents.first(where: { $0.type == .sleep }) ?? dailyEvents.last!
                    
                    // Convert times to minutes since midnight for easier calculations
                    let wakeUpComponents = wakeUpEvent.time.split(separator: ":").map { Int($0) ?? 0 }
                    let sleepComponents = sleepEvent.time.split(separator: ":").map { Int($0) ?? 0 }
                    
                    let wakeUpMinutes = wakeUpComponents[0] * 60 + wakeUpComponents[1]
                    let sleepMinutes = sleepComponents[0] * 60 + sleepComponents[1]
                    
                    // Calculate active day duration, handling case where sleep is past midnight
                    let activeDayMinutes = sleepMinutes > wakeUpMinutes ? sleepMinutes - wakeUpMinutes : (24 * 60 - wakeUpMinutes) + sleepMinutes
                    
                    // How many more times do we need to add?
                    let remainingDoses = dosesPerDay - candidates.count
                    let interval = activeDayMinutes / (remainingDoses + 1) // +1 to space them properly
                    
                    // Skip breakfast time since we'll add it manually
                    let existingTimes = candidates.map { $0.time }
                    
                    // Add remaining doses at evenly spaced intervals
                    for i in 1...remainingDoses {
                        // Calculate target time in minutes from wakeup, offset to avoid meal times
                        let targetMinutesFromWakeup = (i * interval) + 30 // offset by 30 minutes
                        
                        // Convert to absolute minutes since midnight
                        let targetMinutes = (wakeUpMinutes + targetMinutesFromWakeup) % (24 * 60)
                        
                        // Convert back to hour:minute format
                        let hour = targetMinutes / 60
                        let minute = targetMinutes % 60
                        
                        let timeString = String(format: "%02d:%02d", hour, minute)
                        
                        // Skip if time already exists
                        if existingTimes.contains(timeString) {
                            continue
                        }
                        
                        // Create a new medicine event
                        let newEvent = DailyEvent(
                            name: "Medicine Time",
                            type: .medicineTime,
                            time: timeString
                        )
                        candidates.append(newEvent)
                    }
                }
            } else {
                // For single dose per day, use breakfast
                if let breakfast = mealEvents.first(where: { $0.name == "Breakfast" }) {
                    candidates.append(breakfast)
                } else if !mealEvents.isEmpty {
                    // Or any other meal if breakfast not available
                    candidates.append(mealEvents.first!)
                } else {
                    // If no meals, use mid-morning
                    let wakeUpEvent = dailyEvents.first(where: { $0.type == .wakeUp }) ?? dailyEvents.first!
                    let wakeUpComponents = wakeUpEvent.time.split(separator: ":").map { Int($0) ?? 0 }
                    let wakeUpMinutes = wakeUpComponents[0] * 60 + wakeUpComponents[1]
                    
                    // 2 hours after wakeup
                    let midMorningMinutes = wakeUpMinutes + 120
                    let hour = (midMorningMinutes / 60) % 24
                    let minute = midMorningMinutes % 60
                    
                    let timeString = String(format: "%02d:%02d", hour, minute)
                    let midMorningEvent = DailyEvent(
                        name: "Morning Medicine Time",
                        type: .medicineTime,
                        time: timeString
                    )
                    candidates.append(midMorningEvent)
                }
            }
            
            // Sort by time to ensure proper sequencing
            candidates.sort { $0.time < $1.time }
            
            return candidates
        }
        
        // Special case for Vitamin C - always schedule together with Heferal
        if medicine.name == "Vitamin C" {
            // Find the Heferal medicine events first
            let hefevalEvents = scheduledDoses
                .filter { $0.medicine.name == "Heferal" }
                .map { $0.event }
                .sorted { $0.time < $1.time }
            
            if !hefevalEvents.isEmpty {
                // If Heferal is already scheduled, use the same events
                candidates.append(contentsOf: hefevalEvents)
                return candidates
            } else {
                // If Heferal isn't scheduled yet, find where it would be scheduled
                if let heferal = medicines.first(where: { $0.name == "Heferal" }) {
                    let hefevalDosesPerDay = heferal.timingRules.compactMap { rule -> Int? in
                        if case .timesPerDay(let count) = rule {
                            return count
                        }
                        return nil
                    }.first ?? 1 // Default to once per day if not specified
                    
                    candidates = findCandidateEvents(for: heferal, dosesPerDay: hefevalDosesPerDay)
                    return candidates
                }
            }
        }
        
        // Check for specific timing rules
        let hasSpecificTiming = medicine.timingRules.contains { rule in
            if case .specificMeal(_) = rule { return true }
            if case .specificTime(_) = rule { return true }
            return false
        }
        
        if hasSpecificTiming {
            // Handle medicines with specific timing requirements
            for event in dailyEvents {
                // For specific meals, case-insensitive comparison
                if medicine.canBeTakenAt(dailyEvent: event, takenMedicines: []) {
                    candidates.append(event)
                }
            }
        } else {
            // Distribute medicines evenly throughout the active day
            
            // Calculate wakeup and sleep times to determine the active day duration
            let wakeUpEvent = dailyEvents.first(where: { $0.type == .wakeUp }) ?? dailyEvents.first!
            let sleepEvent = dailyEvents.first(where: { $0.type == .sleep }) ?? dailyEvents.last!
            
            // Convert times to minutes since midnight for easier calculations
            let wakeUpComponents = wakeUpEvent.time.split(separator: ":").map { Int($0) ?? 0 }
            let sleepComponents = sleepEvent.time.split(separator: ":").map { Int($0) ?? 0 }
            
            let wakeUpMinutes = wakeUpComponents[0] * 60 + wakeUpComponents[1]
            let sleepMinutes = sleepComponents[0] * 60 + sleepComponents[1]
            
            // Calculate active day duration, handling case where sleep is past midnight
            let activeDayMinutes = sleepMinutes > wakeUpMinutes ? sleepMinutes - wakeUpMinutes : (24 * 60 - wakeUpMinutes) + sleepMinutes
            
            if dosesPerDay > 1 {
                // Calculate evenly spaced time intervals
                let interval = activeDayMinutes / dosesPerDay
                
                for i in 0..<dosesPerDay {
                    // Calculate target time in minutes from wakeup
                    let targetMinutesFromWakeup = i * interval
                    
                    // Convert to absolute minutes since midnight
                    let targetMinutes = (wakeUpMinutes + targetMinutesFromWakeup) % (24 * 60)
                    
                    // Convert back to hour:minute format
                    let hour = targetMinutes / 60
                    let minute = targetMinutes % 60
                    
                    let timeString = String(format: "%02d:%02d", hour, minute)
                    
                    // Check if this time aligns with an existing event (like a meal)
                    if let existingEvent = findClosestEvent(to: timeString, preferMeals: true, maxMinutesDiff: 30) {
                        candidates.append(existingEvent)
                    } else {
                        // Create a new medicine event with appropriate naming
                        let eventName: String
                        if dosesPerDay <= 3 {
                            if i == 0 {
                                eventName = "Morning Dose"
                            } else if i == dosesPerDay - 1 {
                                eventName = "Evening Dose"
                            } else if i == 1 && dosesPerDay == 3 {
                                eventName = "Midday Dose"
                            } else {
                                eventName = "Dose \(i+1)"
                            }
                        } else {
                            // For higher number of doses, just use numeric naming
                            eventName = "Dose \(i+1) of \(dosesPerDay)"
                        }
                        
                        let newEvent = DailyEvent(
                            name: eventName,
                            type: .medicineTime,
                            time: timeString
                        )
                        candidates.append(newEvent)
                    }
                }
                
                // If we couldn't generate enough events, fall back to using meals
                if candidates.count < dosesPerDay {
                    let mealEvents = dailyEvents.filter { $0.type == .meal }
                    for meal in mealEvents {
                        if !candidates.contains(where: { $0.time == meal.time }) {
                            candidates.append(meal)
                            if candidates.count >= dosesPerDay {
                                break
                            }
                        }
                    }
                }
                
                // Sort by time to ensure proper sequencing
                candidates.sort { $0.time < $1.time }
                
            } else if dosesPerDay == 1 {
                // If only one dose per day, prefer a meal time if not otherwise specified
                let mealEvents = dailyEvents.filter { $0.type == .meal }
                
                if let breakfast = mealEvents.first(where: { $0.name.lowercased() == "breakfast" }) {
                    candidates.append(breakfast)
                } else if let firstMeal = mealEvents.first {
                    candidates.append(firstMeal)
                } else {
                    // If no meal events, use mid-morning
                    let midMorningMinutes = wakeUpMinutes + (activeDayMinutes / 4)
                    let hour = (midMorningMinutes / 60) % 24
                    let minute = midMorningMinutes % 60
                    
                    let timeString = String(format: "%02d:%02d", hour, minute)
                    let midMorningEvent = DailyEvent(
                        name: "Morning Medicine Time",
                        type: .medicineTime,
                        time: timeString
                    )
                    candidates.append(midMorningEvent)
                }
            }
        }
        
        // Create special medicine events if needed (e.g., for empty stomach)
        if candidates.isEmpty && medicine.timingRules.contains(.emptyStomach) && medicine.name != "Eutirox" {
            // For empty stomach medicines, schedule 30 minutes before breakfast
            if let breakfast = dailyEvents.first(where: { $0.name == "Breakfast" }) {
                // Create a new event 30 minutes before breakfast
                let timeComponents = breakfast.time.split(separator: ":").map { Int($0) ?? 0 }
                var hour = timeComponents[0]
                var minute = timeComponents[1] - 30
                
                if minute < 0 {
                    minute += 60
                    hour -= 1
                    if hour < 0 {
                        hour += 24
                    }
                }
                
                let timeString = String(format: "%02d:%02d", hour, minute)
                let emptyStomachEvent = DailyEvent(
                    name: "Before Breakfast",
                    type: .medicineTime,
                    time: timeString,
                    timeSinceLastMeal: 480 // Assuming 8 hours since dinner
                )
                
                candidates.append(emptyStomachEvent)
            }
        }
        
        return candidates
    }
    
    // Helper method to find the closest event to a target time
    private func findClosestEvent(to targetTime: String, preferMeals: Bool, maxMinutesDiff: Int) -> DailyEvent? {
        let targetComponents = targetTime.split(separator: ":").map { Int($0) ?? 0 }
        let targetMinutes = targetComponents[0] * 60 + targetComponents[1]
        
        var closestEvent: DailyEvent? = nil
        var smallestDiff = Int.max
        
        // First try meal events if preferred
        if preferMeals {
            let mealEvents = dailyEvents.filter { $0.type == .meal }
            
            for event in mealEvents {
                let eventComponents = event.time.split(separator: ":").map { Int($0) ?? 0 }
                let eventMinutes = eventComponents[0] * 60 + eventComponents[1]
                
                let diff = abs(targetMinutes - eventMinutes)
                let wrappedDiff = min(diff, 24*60 - diff) // Handle around-midnight cases
                
                if wrappedDiff < smallestDiff && wrappedDiff <= maxMinutesDiff {
                    smallestDiff = wrappedDiff
                    closestEvent = event
                }
            }
            
            if closestEvent != nil {
                return closestEvent
            }
        }
        
        // If no meal event is close enough or meals not preferred, check all events
        for event in dailyEvents {
            let eventComponents = event.time.split(separator: ":").map { Int($0) ?? 0 }
            let eventMinutes = eventComponents[0] * 60 + eventComponents[1]
            
            let diff = abs(targetMinutes - eventMinutes)
            let wrappedDiff = min(diff, 24*60 - diff) // Handle around-midnight cases
            
            if wrappedDiff < smallestDiff && wrappedDiff <= maxMinutesDiff {
                smallestDiff = wrappedDiff
                closestEvent = event
            }
        }
        
        return closestEvent
    }
    
    private func determineQuantity(for medicine: Medicine, at event: DailyEvent, dosesPerDay: Int) -> String {
        // Special case for Eutirox with rotating schedule
        if medicine.name == "Eutirox" {
            // In a real app, would keep track of the day in the rotation
            return "50mg (or 75mg depending on rotation day)"
        }
        
        // Extract dosage information from instructions if available
        if let dosageMatch = medicine.dosageInstructions.range(of: "\\d+mg", options: .regularExpression) {
            let dosageText = String(medicine.dosageInstructions[dosageMatch])
            
            // If there are multiple doses per day, include which dose this is
            if dosesPerDay > 1 {
                // Determine which dose number this is based on time of day
                let doseNumber = determineDoseNumber(for: medicine, at: event, totalDoses: dosesPerDay)
                return "\(dosageText) (dose \(doseNumber) of \(dosesPerDay))"
            }
            
            return dosageText
        }
        
        // Default quantity with dose numbering for multiple doses
        if dosesPerDay > 1 {
            let doseNumber = determineDoseNumber(for: medicine, at: event, totalDoses: dosesPerDay)
            return "dose \(doseNumber) of \(dosesPerDay)"
        }
        
        // Default to "1 dose" if no specific quantity is found and only one dose per day
        return "1 dose"
    }
    
    // Helper method to determine which dose number this is based on time of day
    private func determineDoseNumber(for medicine: Medicine, at event: DailyEvent, totalDoses: Int) -> Int {
        // Get all scheduled events for this medicine
        // This won't be available for the first dose, so we need a fallback
        let medicineEvents = findCandidateEvents(for: medicine, dosesPerDay: totalDoses)
            .sorted { $0.time < $1.time }
        
        // If we have pre-determined events, use those for ordering
        if !medicineEvents.isEmpty {
            if let index = medicineEvents.firstIndex(where: { $0.time == event.time }) {
                return index + 1 // 1-based numbering
            }
        }
        
        // If we couldn't determine from candidate events,
        // estimate based on time of day relative to wake up and sleep
        let wakeUpEvent = dailyEvents.first(where: { $0.type == .wakeUp }) ?? dailyEvents.first!
        let sleepEvent = dailyEvents.first(where: { $0.type == .sleep }) ?? dailyEvents.last!
        
        let wakeUpComponents = wakeUpEvent.time.split(separator: ":").map { Int($0) ?? 0 }
        let sleepComponents = sleepEvent.time.split(separator: ":").map { Int($0) ?? 0 }
        let eventComponents = event.time.split(separator: ":").map { Int($0) ?? 0 }
        
        let wakeUpMinutes = wakeUpComponents[0] * 60 + wakeUpComponents[1]
        let sleepMinutes = sleepComponents[0] * 60 + sleepComponents[1]
        let eventMinutes = eventComponents[0] * 60 + eventComponents[1]
        
        // Calculate active day duration
        let activeDayMinutes = sleepMinutes > wakeUpMinutes ? 
            sleepMinutes - wakeUpMinutes : (24 * 60 - wakeUpMinutes) + sleepMinutes
        
        // Calculate how far into the day this event is (as a percentage)
        let minutesSinceWakeUp = eventMinutes >= wakeUpMinutes ? 
            eventMinutes - wakeUpMinutes : (eventMinutes + 24 * 60) - wakeUpMinutes
        
        let percentOfDay = Double(minutesSinceWakeUp) / Double(activeDayMinutes)
        
        // Use percentage to determine which dose this is
        // First dose is at 0% of day, last dose is at 100% of day
        let doseIndex = Int(floor(percentOfDay * Double(totalDoses)))
        
        // If we're at the very end of the day, ensure we don't exceed total doses
        return min(doseIndex + 1, totalDoses)
    }
    
    private func getNotes(for medicine: Medicine, at event: DailyEvent) -> String {
        var relevantNotes: [String] = []
        
        // Include special notes based on context, excluding exceptions
        for note in medicine.specialNotes {
            if !note.hasPrefix("Exception:") {
                relevantNotes.append(note)
            }
        }
        
        // Additional contextual notes based on the event
        if event.type == .meal {
            if medicine.timingRules.contains(.withFood) {
                relevantNotes.append("Take with food")
            }
        } else if medicine.name == "Eutirox" && event.name.contains("First Medicine") {
            relevantNotes.append("Rotating schedule: 50mg for 4 days, then 75mg for 3 days; MUST BE TAKEN FIRST! 30-60 minutes before breakfast and any other medicines on empty stomach")
        } else if medicine.name == "Heferal" {
            // Only add this note once - remove any duplicates from special notes
            if !relevantNotes.contains("Do not take with milk or calcium") {
                relevantNotes.append("Do not take with milk or calcium")
            }
            relevantNotes.append("Take together with Vitamin C")
            
            if event.name.contains("Before Breakfast") {
                relevantNotes.append("Take 1 hour before breakfast on empty stomach")
            } else if event.name.contains("After Dinner") {
                relevantNotes.append("Take 2 hours after dinner on empty stomach")
            }
        } else if medicine.name == "Vitamin C" {
            relevantNotes.append("Take together with Heferal")
        } else if medicine.name == "Utrogestan 200mg" && event.name.contains("Before Sleep") {
            relevantNotes.append("Take 30 minutes before sleep for better sleep quality")
        } else if medicine.name == "Utrogestan 200mg" && event.name.contains("After Breakfast") {
            relevantNotes.append("Take 2 hours after breakfast")
        } else if medicine.name == "Utrogestan 200mg" && event.name.contains("Middle Dose") {
            relevantNotes.append("Middle dose - evenly spaced between morning and evening doses")
        } else if medicine.name == "Nifelat" && event.name == "Breakfast" {
            relevantNotes.append("Take with breakfast, before the first Utrogestan dose")
        }
        
        // Remove duplicate notes
        var uniqueNotes: [String] = []
        for note in relevantNotes {
            if !uniqueNotes.contains(note) {
                uniqueNotes.append(note)
            }
        }
        
        return uniqueNotes.joined(separator: "; ")
    }
    
    // Special handling for the Nifelat/Utrogestan conflict
    private func fixNifelatUtrogestanConflict(_ scheduledDoses: inout [ScheduledDose]) {
        // Group doses by time
        var dosesByTime: [String: [ScheduledDose]] = [:]
        for dose in scheduledDoses {
            if dosesByTime[dose.event.time] == nil {
                dosesByTime[dose.event.time] = []
            }
            dosesByTime[dose.event.time]?.append(dose)
        }
        
        // Track if Nifelat dose 3 is at dinner (special case we want to preserve)
        var nifelatDose3AtDinner = false
        var dinnerTime = ""
        
        // Find dinner time and check if Nifelat dose 3 is there
        if let dinner = dailyEvents.first(where: { $0.name == "Dinner" }) {
            dinnerTime = dinner.time
            debugPrint("Dinner time is \(dinnerTime)")
            
            if let dosesAtDinner = dosesByTime[dinnerTime] {
                debugPrint("Medicines at dinner: \(dosesAtDinner.map { $0.medicine.name }.joined(separator: ", "))")
                
                nifelatDose3AtDinner = dosesAtDinner.contains { dose in
                    let isNifelatDose3 = dose.medicine.name == "Nifelat" && 
                           (dose.quantity.contains("dose 3 of") ||
                           dose.notes.contains("Special rule: with the dinner") ||
                           dose.notes.contains("Special rule: with dinner"))
                    if isNifelatDose3 {
                        debugPrint("Found Nifelat dose 3 at dinner")
                    }
                    return isNifelatDose3
                }
            }
        }
        
        // Check each time slot for conflicts
        for (time, doses) in dosesByTime {
            let hasUtrogestan = doses.contains { $0.medicine.name == "Utrogestan 200mg" }
            let hasNifelat = doses.contains { $0.medicine.name == "Nifelat" }
            let isBreakfastTime = doses.contains { $0.event.name == "Breakfast" }
            let isDinnerTime = time == dinnerTime
            
            if isDinnerTime {
                debugPrint("Checking for conflicts at dinner time: hasUtrogestan=\(hasUtrogestan), hasNifelat=\(hasNifelat), nifelatDose3AtDinner=\(nifelatDose3AtDinner)")
            }
            
            // Special case: If this is dinner and Nifelat dose 3 is scheduled here by exception
            if isDinnerTime && nifelatDose3AtDinner && hasUtrogestan {
                // Instead of moving Nifelat, move Utrogestan in this case
                debugPrint("Found conflict at dinner - keeping Nifelat dose 3 with dinner and moving Utrogestan")
                
                // Find the required separation time from the rules
                let nifelatMedicine = medicines.first(where: { $0.name == "Nifelat" })
                var separationMinutes = 60 // Default to 1 hour if not specified
                
                if let nifelat = nifelatMedicine {
                    debugPrint("Looking for separation rules in Nifelat timing rules")
                    for rule in nifelat.timingRules {
                        debugPrint("Examining rule: \(rule)")
                        if case .separationFromMedicine(let medicineName, let minutes) = rule, 
                           medicineName == "Utrogestan" || medicineName == "Utrogestan 200mg" {
                            separationMinutes = minutes
                            debugPrint("Found separation rule: \(medicineName) - \(minutes) minutes")
                            break
                        }
                    }
                }
                
                // Remove Utrogestan from this time slot in the final list
                scheduledDoses.removeAll { dose in
                    return dose.event.time == time && dose.medicine.name == "Utrogestan 200mg"
                }
                
                // Also remove from our internal tracking
                self.scheduledDoses.removeAll { dose in
                    return dose.event.time == time && dose.medicine.name == "Utrogestan 200mg"
                }
                
                // Create a new time using the required separation time after dinner for Utrogestan
                let timeComponents = time.split(separator: ":").map { Int($0) ?? 0 }
                var newHour = timeComponents[0]
                var newMinute = timeComponents[1]
                
                // Add the required separation minutes
                newMinute += separationMinutes
                while newMinute >= 60 {
                    newMinute -= 60
                    newHour += 1
                }
                
                if newHour >= 24 {
                    newHour -= 24
                }
                
                let newTime = String(format: "%02d:%02d", newHour, newMinute)
                
                // Find the Utrogestan medicine
                if let utrogestanMedicine = medicines.first(where: { $0.name == "Utrogestan 200mg" }) {
                    // Get the removed Utrogestan dose to preserve its quantity
                    let utrogestanDose = doses.first { $0.medicine.name == "Utrogestan 200mg" }
                    let quantity = utrogestanDose?.quantity ?? "1 dose"
                    
                    // Format separation time for display
                    let separationTimeText = separationMinutes == 60 ? "1 hour" : 
                                             separationMinutes < 60 ? "\(separationMinutes) minutes" :
                                             "\(separationMinutes / 60) hours \(separationMinutes % 60) minutes"
                    
                    // Create a new event
                    let newEvent = DailyEvent(
                        name: "After Dinner (for Utrogestan)",
                        type: .medicineTime,
                        time: newTime
                    )
                    
                    // Create a new dose
                    let newDose = ScheduledDose(
                        medicine: utrogestanMedicine,
                        event: newEvent,
                        quantity: quantity,
                        notes: "Moved \(separationTimeText) after dinner to maintain required separation from Nifelat dose 3"
                    )
                    
                    // Add the new dose to both the final schedule and internal tracking
                    scheduledDoses.append(newDose)
                    self.scheduledDoses.append(newDose)
                    
                    debugPrint("Moved Utrogestan to \(newTime) to respect Nifelat dose 3 with dinner exception (\(separationTimeText) separation)")
                }
                
            } else if hasUtrogestan && hasNifelat && !isBreakfastTime {
                // Regular conflict handling - move Nifelat when it's not the special case
                debugPrint("Found conflict between Nifelat and Utrogestan at \(time)")
                
                // Remove Nifelat from this time slot in the final list
                scheduledDoses.removeAll { dose in
                    return dose.event.time == time && dose.medicine.name == "Nifelat"
                }
                
                // Also remove from our internal tracking
                self.scheduledDoses.removeAll { dose in
                    return dose.event.time == time && dose.medicine.name == "Nifelat"
                }
                
                // Create a new time 2 hours later for Nifelat
                let timeComponents = time.split(separator: ":").map { Int($0) ?? 0 }
                var newHour = timeComponents[0] + 2
                let newMinute = timeComponents[1]
                
                if newHour >= 24 {
                    newHour -= 24
                }
                
                let newTime = String(format: "%02d:%02d", newHour, newMinute)
                
                // Find the Nifelat medicine
                if let nifelatMedicine = medicines.first(where: { $0.name == "Nifelat" }) {
                    // Determine how many doses per day for Nifelat
                    let dosesPerDay = nifelatMedicine.timingRules.compactMap { rule -> Int? in
                        if case .timesPerDay(let count) = rule {
                            return count
                        }
                        return nil
                    }.first ?? 1
                    
                    // Create a new event
                    let newEvent = DailyEvent(
                        name: "After Utrogestan (2h separation)",
                        type: .medicineTime,
                        time: newTime
                    )
                    
                    // Create a new dose with proper numbering
                    let quantity = determineQuantity(for: nifelatMedicine, at: newEvent, dosesPerDay: dosesPerDay)
                    let newDose = ScheduledDose(
                        medicine: nifelatMedicine,
                        event: newEvent,
                        quantity: quantity,
                        notes: "Must be taken at least 1-2 hours apart from Utrogestan"
                    )
                    
                    // Add the new dose to both the final schedule and internal tracking
                    scheduledDoses.append(newDose)
                    self.scheduledDoses.append(newDose)
                    
                    debugPrint("Moved Nifelat to \(newTime) to avoid conflict with Utrogestan")
                }
            }
        }
    }
    
    // Extract exceptions from medicine notes
    private func extractExceptions() {
        exceptions = []
        
        for medicine in medicines {
            for note in medicine.specialNotes {
                if note.hasPrefix("Exception:") {
                    let exceptionText = note.replacingOccurrences(of: "Exception: ", with: "")
                    
                    // Try to parse dose-specific exceptions
                    var doseNumber: Int? = nil
                    var instruction = exceptionText
                    
                    // Pattern to match "dose X," where X is a number
                    let dosePattern = "dose (\\d+),"
                    if let regex = try? NSRegularExpression(pattern: dosePattern, options: []),
                       let match = regex.firstMatch(in: exceptionText, options: [], range: NSRange(exceptionText.startIndex..., in: exceptionText)) {
                        
                        if let numberRange = Range(match.range(at: 1), in: exceptionText) {
                            doseNumber = Int(String(exceptionText[numberRange]))
                            
                            // Extract the instruction part after the dose specification
                            if let commaRange = exceptionText.range(of: ",", options: [], range: exceptionText.startIndex..<exceptionText.endIndex, locale: nil) {
                                instruction = String(exceptionText[exceptionText.index(after: commaRange.upperBound)...]).trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                    
                    let exception = MedicineParser.MedicineException(
                        medicineName: medicine.name,
                        doseNumber: doseNumber,
                        instruction: instruction,
                        rawText: exceptionText
                    )
                    
                    exceptions.append(exception)
                }
            }
        }
    }
    
    // Apply dose-specific exceptions to the scheduled doses
    private func applyDoseSpecificExceptions(_ scheduledDoses: inout [ScheduledDose]) {
        // Create a dictionary to track which doses have already been adjusted
        var adjustedDoses: [String: Set<Int>] = [:]
        
        // Process all exceptions - don't special case just Nifelat
        for exception in exceptions {
            // Skip exceptions without dose numbers (they're handled elsewhere)
            guard let doseNumber = exception.doseNumber else { continue }
            
            // Find all doses for this medicine
            let medicineDoses = scheduledDoses.filter { 
                $0.medicine.name == exception.medicineName 
            }.sorted { $0.event.time < $1.event.time }
            
            // Skip if we don't have enough doses
            if medicineDoses.count < doseNumber { continue }
            
            // Track which doses of this medicine have been adjusted
            if adjustedDoses[exception.medicineName] == nil {
                adjustedDoses[exception.medicineName] = []
            }
            
            // Skip if this specific dose has already been adjusted
            if adjustedDoses[exception.medicineName]?.contains(doseNumber) == true {
                continue
            }
            
            debugPrint("Processing exception for \(exception.medicineName) dose \(doseNumber): \(exception.instruction)")
            
            // Get the specific dose we need to modify
            let targetDose = medicineDoses[doseNumber - 1] // doseNumber is 1-based
            
            // Find the corresponding medicine
            guard let medicine = medicines.first(where: { $0.name == exception.medicineName }) else { continue }
            
            // Special handling for Utrogestan at dinner when Nifelat is also there
            if exception.medicineName == "Utrogestan 200mg" && 
               (exception.instruction.contains("with dinner") || 
                exception.instruction.contains("with the dinner")) {
                // Check if Nifelat is also scheduled at dinner
                if let dinner = dailyEvents.first(where: { $0.name == "Dinner" }) {
                    let nifelatAtDinner = scheduledDoses.contains { dose in
                        return dose.medicine.name == "Nifelat" && 
                               dose.event.time == dinner.time
                    }
                    
                    if nifelatAtDinner {
                        debugPrint("Skipping Utrogestan at dinner exception - conflict with Nifelat")
                        continue // Skip - this will be handled by fixNifelatUtrogestanConflict
                    }
                }
            }
            
            // Remove the original dose from the schedule
            scheduledDoses.removeAll { 
                $0.medicine.name == targetDose.medicine.name && 
                $0.event.time == targetDose.event.time 
            }
            
            // Find the appropriate event based on the exception
            if let eventFromException = findEventFromException(exception.instruction) {
                // Create a new dose at the specified event time
                let quantity = targetDose.quantity
                let newDose = ScheduledDose(
                    medicine: medicine,
                    event: eventFromException,
                    quantity: quantity,
                    notes: "Special rule: \(exception.instruction)"
                )
                scheduledDoses.append(newDose)
                
                // Mark this dose as adjusted
                adjustedDoses[exception.medicineName]?.insert(doseNumber)
                
                debugPrint("Rescheduled \(exception.medicineName) dose \(doseNumber) to \(eventFromException.time) based on exception")
            } else {
                // For exceptions we don't understand, just add the original dose back with a note
                let newDose = ScheduledDose(
                    medicine: targetDose.medicine,
                    event: targetDose.event,
                    quantity: targetDose.quantity,
                    notes: targetDose.notes + "; Special rule: \(exception.instruction)"
                )
                scheduledDoses.append(newDose)
                
                // Mark this dose as adjusted
                adjustedDoses[exception.medicineName]?.insert(doseNumber)
                
                debugPrint("Couldn't understand exception for \(exception.medicineName) dose \(doseNumber), keeping original time")
            }
        }
        
        // After applying all exceptions, call fixNifelatUtrogestanConflict again to ensure
        // any remaining conflicts are properly handled
        fixNifelatUtrogestanConflict(&scheduledDoses)
        
        // Resort the schedule by time
        scheduledDoses.sort { $0.event.time < $1.event.time }
    }
    
    // Helper method to find an event based on exception instructions
    private func findEventFromException(_ instruction: String) -> DailyEvent? {
        // Check for common meal patterns
        if instruction.contains("with dinner") || instruction.contains("with the dinner") {
            return dailyEvents.first { $0.name == "Dinner" }
        } else if instruction.contains("with breakfast") || instruction.contains("with the breakfast") {
            return dailyEvents.first { $0.name == "Breakfast" }
        } else if instruction.contains("with lunch") || instruction.contains("with the lunch") {
            return dailyEvents.first { $0.name == "Lunch" }
        } else if instruction.contains("before sleep") || instruction.contains("before bed") {
            // Find sleep event and create one 30 minutes before
            if let sleepEvent = dailyEvents.first(where: { $0.type == .sleep }) {
                let sleepComponents = sleepEvent.time.split(separator: ":").map { Int($0) ?? 0 }
                var hour = sleepComponents[0]
                var minute = sleepComponents[1] - 30
                
                if minute < 0 {
                    minute += 60
                    hour -= 1
                    if hour < 0 {
                        hour += 24
                    }
                }
                
                let timeString = String(format: "%02d:%02d", hour, minute)
                return DailyEvent(
                    name: "Before Sleep",
                    type: .medicineTime,
                    time: timeString
                )
            }
        }
        
        // If no specific match, return nil and let caller handle it
        return nil
    }
}

// MARK: - Main Program

// Define paths and options
let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
print("Current directory: \(FileManager.default.currentDirectoryPath)")

// Parse command-line arguments
var debugMode = false
var inputFilePath: String?

// Process all arguments
for (index, arg) in CommandLine.arguments.enumerated() {
    // Skip the first argument (program name)
    if index == 0 { continue }
    
    // Check for debug flag
    if arg == "-d" || arg == "--debug" {
        debugMode = true
    } 
    // Consider non-flag arguments as the input file path
    else if !arg.hasPrefix("-") && inputFilePath == nil {
        inputFilePath = arg
    }
}

// Determine file path based on arguments
let filePath: String
if let userFilePath = inputFilePath {
    filePath = userFilePath
    print("Using specified file: \(filePath)")
} else {
    // Use the default file path
    filePath = currentDirectoryURL.appendingPathComponent("listaLekova.md").path
    print("Using default file: \(filePath)")
}

print("Attempting to read file from: \(filePath)")

print("Terapija - Medicine Schedule Generator")
print("=====================================")
print("Reading medicine list from: \(filePath)")

// Helper function for debug printing
func debugPrint(_ message: String) {
    if debugMode {
        print("DEBUG: \(message)")
    }
}

// Parse medicine list from file
let medicines = MedicineParser.parseMedicineList(from: filePath)
print("Found \(medicines.count) medicines in the list")

// Create scheduler
let scheduler = MedicineScheduler(medicines: medicines)

// Set daily events with default times
// These could be customized based on user input
scheduler.setDailyEvents(
    wakeUpTime:     "07:00",
    breakfastTime:  "09:00",
    lunchTime:      "14:00",
    dinnerTime:     "17:00",
    sleepTime:      "23:59"
)

// Generate the daily schedule
let schedule = scheduler.generateSchedule()

// Print the schedule
schedule.printSchedule()



