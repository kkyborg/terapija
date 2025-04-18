import Foundation

// MARK: - Test Suite for Medicine Scheduler

class MedicineTests {
    // Main function to run all tests
    static func runAllTests() {
        print("🧪 Running Medicine Scheduler Tests")
        print("==================================")
        
        // Create a test scheduler
        let medicines = loadTestMedicines()
        let scheduler = MedicineScheduler(medicines: medicines)
        
        // Set up daily events
        scheduler.setDailyEvents(
            wakeUpTime: "07:00",
            breakfastTime: "09:00",
            lunchTime: "14:00",
            dinnerTime: "17:00",
            sleepTime: "23:59"
        )
        
        // Generate a schedule
        let schedule = scheduler.generateSchedule()
        
        // Run tests
        testEutiroxRequirements(schedule)
        testGlukophageWithDinner(schedule)
        testMultipleDoseSpacing(schedule)
        testUtrogestanNifelatSeparation(schedule)
        testHeferalWithVitaminC(schedule)
        testMealBasedRequirements(schedule)
        testExceptionHandling(schedule)
        
        print("\n✅ All tests completed!")
    }
    
    // MARK: - Test Helper Methods
    
    // Load a set of test medicines
    static func loadTestMedicines() -> [Medicine] {
        // Basic medicines for testing
        return MedicineParser.parseMedicineList(from: "\(FileManager.default.currentDirectoryPath)/listaLekova.md")
    }
    
    // Find scheduled doses for a specific medicine
    static func findDoses(for medicineName: String, in schedule: DailySchedule) -> [ScheduledDose] {
        return schedule.scheduledDoses.filter { $0.medicine.name == medicineName }
    }
    
    // Convert time string to minutes past midnight for easier comparison
    static func timeToMinutes(_ time: String) -> Int {
        let components = time.split(separator: ":")
        if components.count >= 2, 
           let hours = Int(components[0]),
           let minutes = Int(components[1]) {
            return hours * 60 + minutes
        }
        return 0
    }
    
    // Calculate minutes between two time strings, handling wraparound at midnight
    static func minutesBetween(time1: String, time2: String) -> Int {
        let minutes1 = timeToMinutes(time1)
        let minutes2 = timeToMinutes(time2)
        
        if minutes2 >= minutes1 {
            return minutes2 - minutes1
        } else {
            // Handle wraparound at midnight
            return (24 * 60 - minutes1) + minutes2
        }
    }
    
    // Check if a time is within a specified range of another time
    static func isTime(_ time: String, within minutes: Int, of referenceTime: String) -> Bool {
        return minutesBetween(time1: time, time2: referenceTime) <= minutes
    }
    
    // Find all meal events
    static func findMeals(in schedule: DailySchedule) -> [DailyEvent] {
        return schedule.events.filter { event in
            event.name == "Breakfast" || event.name == "Lunch" || event.name == "Dinner"
        }
    }
    
    // MARK: - Individual Tests
    
    // Test that Eutirox is taken before breakfast and all other medicines
    static func testEutiroxRequirements(_ schedule: DailySchedule) {
        print("\n🧪 Testing Eutirox Requirements...")
        
        let eutiroxDoses = findDoses(for: "Eutirox", in: schedule)
        guard let eutiroxDose = eutiroxDoses.first else {
            print("❌ FAILED: Eutirox not found in schedule")
            return
        }
        
        // Find breakfast
        guard let breakfast = schedule.events.first(where: { $0.name == "Breakfast" }) else {
            print("❌ FAILED: Breakfast not found in schedule")
            return
        }
        
        // Check if Eutirox is taken before breakfast
        let eutiroxTime = eutiroxDose.event.time
        let breakfastTime = breakfast.time
        
        if timeToMinutes(eutiroxTime) >= timeToMinutes(breakfastTime) {
            print("❌ FAILED: Eutirox (\(eutiroxTime)) is not scheduled before breakfast (\(breakfastTime))")
        } else {
            // Check if it's 30-60 minutes before breakfast
            let minutesBeforeBreakfast = minutesBetween(time1: eutiroxTime, time2: breakfastTime)
            if minutesBeforeBreakfast < 30 || minutesBeforeBreakfast > 60 {
                print("⚠️ WARNING: Eutirox is scheduled \(minutesBeforeBreakfast) minutes before breakfast (recommended: 30-60 minutes)")
            } else {
                print("✅ PASSED: Eutirox is scheduled \(minutesBeforeBreakfast) minutes before breakfast")
            }
        }
        
        // Check if Eutirox is the first medicine of the day
        let allMedicines = schedule.scheduledDoses
        let firstMedicine = allMedicines.min { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }
        
        if firstMedicine?.medicine.name != "Eutirox" {
            print("❌ FAILED: Eutirox is not the first medicine of the day")
        } else {
            print("✅ PASSED: Eutirox is the first medicine of the day")
        }
    }
    
    // Test that Glukophage is taken with dinner
    static func testGlukophageWithDinner(_ schedule: DailySchedule) {
        print("\n🧪 Testing Glukophage With Dinner Requirement...")
        
        let glukophageDoses = findDoses(for: "Glukophage 1000xr", in: schedule)
        guard let glukophageDose = glukophageDoses.first else {
            print("❌ FAILED: Glukophage not found in schedule")
            return
        }
        
        // Find dinner
        guard let dinner = schedule.events.first(where: { $0.name == "Dinner" }) else {
            print("❌ FAILED: Dinner not found in schedule")
            return
        }
        
        // Check if Glukophage is taken with dinner
        if glukophageDose.event.time != dinner.time {
            print("❌ FAILED: Glukophage (\(glukophageDose.event.time)) is not scheduled at dinner time (\(dinner.time))")
        } else {
            print("✅ PASSED: Glukophage is scheduled with dinner")
        }
    }
    
    // Test that multiple doses of the same medicine are spaced appropriately
    static func testMultipleDoseSpacing(_ schedule: DailySchedule) {
        print("\n🧪 Testing Multiple Dose Spacing...")
        
        // Medicines with multiple doses
        let medicinesWithMultipleDoses = ["Nifelat", "Utrogestan 200mg", "Aleract", "Inofolic combi", "Heferal", "Vitamin C"]
        
        for medicineName in medicinesWithMultipleDoses {
            let doses = findDoses(for: medicineName, in: schedule)
            if doses.count <= 1 {
                print("⚠️ WARNING: Expected multiple doses for \(medicineName), found \(doses.count)")
                continue
            }
            
            // Sort doses by time
            let sortedDoses = doses.sorted { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }
            
            // Check spacing between doses
            var minSpacingMinutes = Int.max
            for i in 1..<sortedDoses.count {
                let prevDoseTime = sortedDoses[i-1].event.time
                let currentDoseTime = sortedDoses[i].event.time
                
                let spacingMinutes = minutesBetween(time1: prevDoseTime, time2: currentDoseTime)
                minSpacingMinutes = min(minSpacingMinutes, spacingMinutes)
            }
            
            // Minimum spacing should be at least 2 hours (120 minutes) for optimal distribution
            // except for special cases (handled by exceptions)
            if minSpacingMinutes < 120 {
                // Check if this is due to an exception
                let hasException = sortedDoses.contains { $0.notes.contains("⚠️:") }
                
                if hasException {
                    print("✅ PASSED: \(medicineName) doses have reduced spacing due to exceptions")
                } else {
                    print("⚠️ WARNING: \(medicineName) doses have minimum spacing of \(minSpacingMinutes) minutes (recommended: 120+ minutes)")
                }
            } else {
                print("✅ PASSED: \(medicineName) doses have good spacing (minimum \(minSpacingMinutes) minutes)")
            }
        }
    }
    
    // Test that Utrogestan and Nifelat are separated by at least 90 minutes
    static func testUtrogestanNifelatSeparation(_ schedule: DailySchedule) {
        print("\n🧪 Testing Utrogestan-Nifelat Separation...")
        
        let utrogestanDoses = findDoses(for: "Utrogestan 200mg", in: schedule)
        let nifelatDoses = findDoses(for: "Nifelat", in: schedule)
        
        if utrogestanDoses.isEmpty || nifelatDoses.isEmpty {
            print("⚠️ WARNING: Could not find both Utrogestan and Nifelat in schedule")
            return
        }
        
        // Check spacing between each Utrogestan and Nifelat dose
        var violations = 0
        
        for utrogestanDose in utrogestanDoses {
            let utrogestanTime = utrogestanDose.event.time
            
            for nifelatDose in nifelatDoses {
                let nifelatTime = nifelatDose.event.time
                
                let spacing = minutesBetween(time1: utrogestanTime, time2: nifelatTime)
                let reverseSpacing = minutesBetween(time1: nifelatTime, time2: utrogestanTime)
                let minSpacing = min(spacing, reverseSpacing)
                
                if minSpacing < 90 {
                    print("❌ FAILED: Utrogestan (\(utrogestanTime)) and Nifelat (\(nifelatTime)) are only \(minSpacing) minutes apart (required: 90+ minutes)")
                    violations += 1
                }
            }
        }
        
        if violations == 0 {
            print("✅ PASSED: All Utrogestan and Nifelat doses are properly separated")
        }
    }
    
    // Test that Heferal is always taken with Vitamin C
    static func testHeferalWithVitaminC(_ schedule: DailySchedule) {
        print("\n🧪 Testing Heferal With Vitamin C Requirement...")
        
        let hefevalDoses = findDoses(for: "Heferal", in: schedule)
        let vitaminCDoses = findDoses(for: "Vitamin C", in: schedule)
        
        if hefevalDoses.count != vitaminCDoses.count {
            print("❌ FAILED: Number of Heferal doses (\(hefevalDoses.count)) does not match Vitamin C doses (\(vitaminCDoses.count))")
            return
        }
        
        // Sort doses by time
        let sortedHefevalDoses = hefevalDoses.sorted { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }
        let sortedVitaminCDoses = vitaminCDoses.sorted { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }
        
        // Check that all doses are at the same times
        for i in 0..<sortedHefevalDoses.count {
            let hefevalTime = sortedHefevalDoses[i].event.time
            let vitaminCTime = sortedVitaminCDoses[i].event.time
            
            if hefevalTime != vitaminCTime {
                print("❌ FAILED: Heferal dose \(i+1) (\(hefevalTime)) is not at the same time as Vitamin C dose \(i+1) (\(vitaminCTime))")
            }
        }
        
        print("✅ PASSED: All Heferal doses are scheduled with Vitamin C")
    }
    
    // Test meal-based requirements
    static func testMealBasedRequirements(_ schedule: DailySchedule) {
        print("\n🧪 Testing Meal-Based Requirements...")
        
        // Test Heferal requirements (1h before breakfast, 2h after dinner)
        let hefevalDoses = findDoses(for: "Heferal", in: schedule)
        guard let breakfast = schedule.events.first(where: { $0.name == "Breakfast" }) else {
            print("⚠️ WARNING: Breakfast not found in schedule")
            return
        }
        guard let dinner = schedule.events.first(where: { $0.name == "Dinner" }) else {
            print("⚠️ WARNING: Dinner not found in schedule")
            return
        }
        
        if hefevalDoses.count >= 2 {
            // First dose should be 1h before breakfast
            let firstDose = hefevalDoses.min { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }!
            let minutesBeforeBreakfast = minutesBetween(time1: firstDose.event.time, time2: breakfast.time)
            
            if abs(minutesBeforeBreakfast - 60) > 15 {
                print("⚠️ WARNING: First Heferal dose is \(minutesBeforeBreakfast) minutes before breakfast (should be around 60)")
            } else {
                print("✅ PASSED: First Heferal dose is properly scheduled before breakfast")
            }
            
            // Last dose should be 2h after dinner
            let lastDose = hefevalDoses.max { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }!
            let minutesAfterDinner = minutesBetween(time1: dinner.time, time2: lastDose.event.time)
            
            if abs(minutesAfterDinner - 120) > 15 {
                print("⚠️ WARNING: Last Heferal dose is \(minutesAfterDinner) minutes after dinner (should be around 120)")
            } else {
                print("✅ PASSED: Last Heferal dose is properly scheduled after dinner")
            }
        }
        
        // Test Pronison - after breakfast
        let pronisonDoses = findDoses(for: "Pronison 5mg", in: schedule)
        if let pronisonDose = pronisonDoses.first {
            if pronisonDose.event.time == breakfast.time {
                print("✅ PASSED: Pronison is scheduled with breakfast")
            } else {
                print("⚠️ WARNING: Pronison (\(pronisonDose.event.time)) is not scheduled with breakfast (\(breakfast.time))")
            }
        }
    }
    
    // Test exception handling
    static func testExceptionHandling(_ schedule: DailySchedule) {
        print("\n🧪 Testing Exception Handling...")
        
        // Check if there are any exceptions applied
        let dosesWithExceptions = schedule.scheduledDoses.filter { $0.notes.contains("⚠️:") }
        
        if dosesWithExceptions.isEmpty {
            print("ℹ️ INFO: No exceptions found in the schedule")
            return
        }
        
        // For each exception, check if it's properly applied
        for dose in dosesWithExceptions {
            print("✅ APPLIED: Exception for \(dose.medicine.name): \(dose.notes)")
            
            // If it's a "with dinner" exception, check if it's actually at dinner time
            if dose.notes.contains("with the dinner") || dose.notes.contains("with dinner") {
                guard let dinner = schedule.events.first(where: { $0.name == "Dinner" }) else {
                    print("⚠️ WARNING: Dinner not found in schedule")
                    continue
                }
                
                if dose.event.time != dinner.time {
                    print("❌ FAILED: Dose with dinner exception (\(dose.event.time)) is not at dinner time (\(dinner.time))")
                }
            }
        }
    }
}

// Main function to run the tests
func runTests() {
    MedicineTests.runAllTests()
} 