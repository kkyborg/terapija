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
                if dailyEvent.type != .meal || dailyEvent.name != meal {
                    return false
                }
            case .specificTime(let time):
                // Simple time string comparison for now
                if dailyEvent.time != time {
                    return false
                }
            case .timesPerDay(let count):
                // This would be handled by the scheduler
                continue
            case .separationFromMedicine(let medicineName, let minutes):
                for takenMedicine in takenMedicines {
                    if takenMedicine == medicineName {
                        // Would need more complex time comparison in a real app
                        return false
                    }
                }
            case .custom(let description):
                // Custom rules would need special handling
                continue
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
        
        // Group doses by time
        var dosesByTime: [String: [ScheduledDose]] = [:]
        
        for dose in scheduledDoses {
            if dosesByTime[dose.event.time] == nil {
                dosesByTime[dose.event.time] = []
            }
            dosesByTime[dose.event.time]?.append(dose)
        }
        
        // Sort times and print schedule
        let sortedTimes = dosesByTime.keys.sorted()
        
        for time in sortedTimes {
            print("\(time):")
            for dose in dosesByTime[time]! {
                print("  - \(dose.medicine.name): \(dose.quantity)")
                if !dose.notes.isEmpty {
                    print("    Note: \(dose.notes)")
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
    
    private static func parseRulesAndNotes(from instructions: String) -> ([TimingRule], [String]) {
        var rules: [TimingRule] = []
        var notes: [String] = []
        
        // Parse per-day dosage
        if instructions.contains("1x per day") {
            rules.append(.timesPerDay(1))
        } else if instructions.contains("2x per day") {
            rules.append(.timesPerDay(2))
        } else if instructions.contains("3x per day") {
            rules.append(.timesPerDay(3))
        } else if instructions.contains("2x") {
            // Handle short form of "2x" without "per day"
            rules.append(.timesPerDay(2))
        }
        
        // Parse timing relative to food
        if instructions.contains("on empty stomach") {
            rules.append(.emptyStomach)
        }
        if instructions.contains("after breakfast") {
            rules.append(.specificMeal("breakfast"))
        }
        if instructions.contains("with the dinner") {
            rules.append(.specificMeal("dinner"))
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
                       var maxHours = Int(hourRangeComponents[1].replacingOccurrences(of: "h", with: "")) {
                        
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
        if instructions.contains("with C vitamin or citruses") {
            notes.append("Take with vitamin C or citrus")
        }
        
        // Add any complex instructions as custom rules
        if instructions.contains("4 days = 50mg + 3 days = 75mg") {
            rules.append(.custom(description: "4 days 50mg + 3 days 75mg rotation"))
            notes.append("Rotating schedule: 50mg for 4 days, then 75mg for 3 days")
        }
        
        return (rules, notes)
    }
}

// MARK: - Scheduler

class MedicineScheduler {
    private let medicines: [Medicine]
    private var dailyEvents: [DailyEvent] = []
    private var scheduledMedicinesByTime: [String: [Medicine]] = [:]
    
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
        var scheduledDoses: [ScheduledDose] = []
        scheduledMedicinesByTime = [:]
        
        // Add medicine events between daily events as needed
        // First, sort medicines by constraints (more constrained medicines first)
        let sortedMedicines = medicines.sorted { med1, med2 in
            let constraints1 = med1.timingRules.count
            let constraints2 = med2.timingRules.count
            
            // Sort by number of constraints, but prioritize separation constraints
            let hasSeparation1 = med1.timingRules.contains { rule in
                if case .separationFromMedicine(_, _) = rule { return true }
                return false
            }
            
            let hasSeparation2 = med2.timingRules.contains { rule in
                if case .separationFromMedicine(_, _) = rule { return true }
                return false
            }
            
            if hasSeparation1 && !hasSeparation2 {
                return false // med1 should come after
            } else if !hasSeparation1 && hasSeparation2 {
                return true // med2 should come after
            }
            
            return constraints1 > constraints2
        }
        
        // Schedule medicines in order of constraints
        for medicine in sortedMedicines {
            let dosesPerDay = medicine.timingRules.compactMap { rule -> Int? in
                if case .timesPerDay(let count) = rule {
                    return count
                }
                return nil
            }.first ?? 1 // Default to once per day if not specified
            
            // Find suitable events for this medicine based on its rules
            let suitableEvents = findSuitableEventsFor(medicine: medicine, dosesPerDay: dosesPerDay)
            
            // Keep track of which medicines are scheduled at which times
            for event in suitableEvents {
                // Determine quantity based on medicine-specific rules
                let quantity = determineQuantity(for: medicine)
                
                // Add this medicine to the schedule
                let dose = ScheduledDose(
                    medicine: medicine,
                    event: event,
                    quantity: quantity,
                    notes: getNotes(for: medicine, at: event)
                )
                
                scheduledDoses.append(dose)
                
                // Keep track of what medicines are scheduled at what times
                if scheduledMedicinesByTime[event.time] == nil {
                    scheduledMedicinesByTime[event.time] = []
                }
                scheduledMedicinesByTime[event.time]?.append(medicine)
            }
        }
        
        return DailySchedule(
            date: Date(),
            events: dailyEvents,
            scheduledDoses: scheduledDoses
        )
    }
    
    private func findSuitableEventsFor(medicine: Medicine, dosesPerDay: Int) -> [DailyEvent] {
        var suitableEvents: [DailyEvent] = []
        var candidateEvents: [DailyEvent] = []
        
        // Check for specific timing rules
        let hasSpecificTiming = medicine.timingRules.contains { rule in
            if case .specificMeal(_) = rule { return true }
            if case .specificTime(_) = rule { return true }
            return false
        }
        
        // First gather all possible candidate events
        if hasSpecificTiming {
            // Handle medicines with specific timing requirements
            for event in dailyEvents {
                if medicine.canBeTakenAt(dailyEvent: event, takenMedicines: []) {
                    candidateEvents.append(event)
                }
            }
        } else {
            // For medicines without specific timing, distribute evenly throughout the day
            let mealEvents = dailyEvents.filter { $0.type == .meal }
            
            if dosesPerDay == 1 {
                // If once per day, prefer breakfast unless there are specific rules
                if let breakfast = mealEvents.first(where: { $0.name == "Breakfast" }) {
                    candidateEvents.append(breakfast)
                } else if let firstMeal = mealEvents.first {
                    candidateEvents.append(firstMeal)
                }
            } else if dosesPerDay == 2 {
                // If twice per day, try to space them out (breakfast and dinner)
                if let breakfast = mealEvents.first(where: { $0.name == "Breakfast" }),
                   let dinner = mealEvents.first(where: { $0.name == "Dinner" }) {
                    candidateEvents.append(breakfast)
                    candidateEvents.append(dinner)
                } else if mealEvents.count >= 2 {
                    candidateEvents.append(mealEvents.first!)
                    candidateEvents.append(mealEvents.last!)
                }
            } else if dosesPerDay == 3 {
                // If three times per day, try to use all meals
                for meal in mealEvents {
                    candidateEvents.append(meal)
                    if candidateEvents.count >= dosesPerDay {
                        break
                    }
                }
            }
        }
        
        // Create special medicine events if needed (e.g., for empty stomach)
        if candidateEvents.isEmpty && medicine.timingRules.contains(.emptyStomach) {
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
                
                candidateEvents.append(emptyStomachEvent)
            }
        }
        
        // Now filter candidate events based on separation constraints
        let separationConstraints = medicine.timingRules.compactMap { rule -> (String, Int)? in
            if case .separationFromMedicine(let medicineName, let minutes) = rule {
                return (medicineName, minutes)
            }
            return nil
        }
        
        if !separationConstraints.isEmpty {
            // For each candidate event, check if it conflicts with already scheduled medicines
            for event in candidateEvents {
                var isValid = true
                
                for (medicineName, separationMinutes) in separationConstraints {
                    // Check if the medicine to be separated from is scheduled at this time
                    if let medicinesAtThisTime = scheduledMedicinesByTime[event.time], 
                       medicinesAtThisTime.contains(where: { $0.name == medicineName }) {
                        isValid = false
                        break
                    }
                    
                    // Check nearby times for separation constraints
                    let eventTimeComponents = event.time.split(separator: ":").map { Int($0) ?? 0 }
                    let eventTimeMinutes = eventTimeComponents[0] * 60 + eventTimeComponents[1]
                    
                    for (otherTime, medicinesAtTime) in scheduledMedicinesByTime {
                        if medicinesAtTime.contains(where: { $0.name == medicineName }) {
                            let otherTimeComponents = otherTime.split(separator: ":").map { Int($0) ?? 0 }
                            let otherTimeMinutes = otherTimeComponents[0] * 60 + otherTimeComponents[1]
                            
                            let timeDifference = abs(eventTimeMinutes - otherTimeMinutes)
                            if timeDifference < separationMinutes {
                                isValid = false
                                break
                            }
                        }
                    }
                    
                    if !isValid {
                        break
                    }
                }
                
                if isValid {
                    suitableEvents.append(event)
                    
                    // Limit to the required number of doses
                    if suitableEvents.count >= dosesPerDay {
                        break
                    }
                }
            }
        } else {
            // No separation constraints, all candidates are suitable
            suitableEvents = Array(candidateEvents.prefix(dosesPerDay))
        }
        
        // If we couldn't find suitable events due to separation constraints but need to schedule something
        if suitableEvents.isEmpty && !candidateEvents.isEmpty {
            // Create alternative times that satisfy the separation constraints
            for constraint in separationConstraints {
                let medicineName = constraint.0
                let separationMinutes = constraint.1
                
                // Find times when the other medicine is scheduled
                var medicineScheduledTimes: [String] = []
                for (time, medicines) in scheduledMedicinesByTime {
                    if medicines.contains(where: { $0.name == medicineName }) {
                        medicineScheduledTimes.append(time)
                    }
                }
                
                // Create events at least separationMinutes away from those times
                for scheduledTime in medicineScheduledTimes {
                    let timeComponents = scheduledTime.split(separator: ":").map { Int($0) ?? 0 }
                    let scheduledMinutes = timeComponents[0] * 60 + timeComponents[1]
                    
                    // Try to schedule after separation time
                    let afterMinutes = scheduledMinutes + separationMinutes
                    var afterHour = afterMinutes / 60
                    let afterMin = afterMinutes % 60
                    
                    // Ensure we're within a day
                    if afterHour >= 24 {
                        afterHour -= 24
                    }
                    
                    let afterTimeString = String(format: "%02d:%02d", afterHour, afterMin)
                    
                    // Create a new event
                    let afterEvent = DailyEvent(
                        name: "After \(medicineName)",
                        type: .medicineTime,
                        time: afterTimeString
                    )
                    
                    // Check if there's already something scheduled at this time
                    if scheduledMedicinesByTime[afterTimeString] == nil {
                        suitableEvents.append(afterEvent)
                        
                        if suitableEvents.count >= dosesPerDay {
                            break
                        }
                    }
                }
                
                if suitableEvents.count >= dosesPerDay {
                    break
                }
            }
        }
        
        // If still no suitable events, just use the original candidates
        // This could happen if there are conflicting constraints
        if suitableEvents.isEmpty {
            suitableEvents = Array(candidateEvents.prefix(dosesPerDay))
            
            // If we need to take this medicine twice a day but have conflicts,
            // create a custom schedule for medicines with separation constraints
            if dosesPerDay > 1 && !separationConstraints.isEmpty {
                // Try to create a morning and evening dose with enough separation
                if let breakfastEvent = dailyEvents.first(where: { $0.name == "Breakfast" }),
                   let dinnerEvent = dailyEvents.first(where: { $0.name == "Dinner" }) {
                    suitableEvents = [breakfastEvent, dinnerEvent]
                }
            }
        }
        
        return suitableEvents
    }
    
    private func determineQuantity(for medicine: Medicine) -> String {
        // Special case for Eutirox with rotating schedule
        if medicine.name == "Eutirox" {
            // In a real app, would keep track of the day in the rotation
            return "50mg (or 75mg depending on rotation day)"
        }
        
        // Extract dosage information from instructions if available
        if let dosageMatch = medicine.dosageInstructions.range(of: "\\d+mg", options: .regularExpression) {
            return String(medicine.dosageInstructions[dosageMatch])
        }
        
        // Default to "1 dose" if no specific quantity is found
        return "1 dose"
    }
    
    private func getNotes(for medicine: Medicine, at event: DailyEvent) -> String {
        var relevantNotes: [String] = []
        
        // Include special notes based on context
        for note in medicine.specialNotes {
            relevantNotes.append(note)
        }
        
        // Additional contextual notes based on the event
        if event.type == .meal {
            if medicine.timingRules.contains(.withFood) {
                relevantNotes.append("Take with food")
            }
        }
        
        return relevantNotes.joined(separator: "; ")
    }
}

// MARK: - Main Program

// Define paths
let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let filePath = currentDirectoryURL.appendingPathComponent("listaLekova.md").path

print("Medicine Schedule Generator")
print("==========================")
print("Reading medicine list from: \(filePath)")

// Parse medicine list from file
let medicines = MedicineParser.parseMedicineList(from: filePath)
print("Found \(medicines.count) medicines in the list")

// Create scheduler
let scheduler = MedicineScheduler(medicines: medicines)

// Set daily events with default times
// These could be customized based on user input
scheduler.setDailyEvents(
    wakeUpTime: "07:00",
    breakfastTime: "08:00",
    lunchTime: "13:00",
    dinnerTime: "19:00",
    sleepTime: "23:00"
)

// Generate the daily schedule
let schedule = scheduler.generateSchedule()

// Print the schedule
print("\nYour Daily Medicine Schedule:")
schedule.printSchedule()

