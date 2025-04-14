import Foundation

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
enum TimingRule {
    case emptyStomach
    case withFood
    case specificMeal(String) // e.g., "breakfast", "lunch", "dinner"
    case specificTime(String) // e.g., "08:00", "20:00"
    case timesPerDay(Int)    // e.g., 2 times per day
    case separationFromMedicine(medicineName: String, minutes: Int)
    case custom(description: String)
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