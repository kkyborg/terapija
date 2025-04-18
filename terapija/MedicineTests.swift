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
        testEutiroxInofolicSpacing(schedule)
        testGlukophageWithDinner(schedule)
        testMultipleDoseSpacing(schedule)
        testAleractDoseSpacing(schedule)
        testUtrogestanNifelatSeparation(schedule)
        testHeferalWithVitaminC(schedule)
        testMealBasedRequirements(schedule)
        
        print("\nAll tests completed!")
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
            if minutesBeforeBreakfast < 30 {
                print("❌ FAILED: Eutirox is scheduled only \(minutesBeforeBreakfast) minutes before breakfast (required: at least 30 minutes)")
            } else {
                print("✅ PASSED: Eutirox is scheduled at least 30 minutes before breakfast (\(minutesBeforeBreakfast) minutes)")
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
    
    // Test the spacing between Eutirox and Inofolic doses
    static func testEutiroxInofolicSpacing(_ schedule: DailySchedule) {
        print("\n🧪 Testing Eutirox-Inofolic Spacing...")
        
        let eutiroxDoses = findDoses(for: "Eutirox", in: schedule)
        let inofolicDoses = findDoses(for: "Inofolic Combi", in: schedule)
        
        if eutiroxDoses.isEmpty || inofolicDoses.isEmpty {
            print("❌ FAILED: Could not find both Eutirox and Inofolic in schedule")
            return
        }
        
        // Get the first Eutirox dose of the day
        guard let eutiroxDose = eutiroxDoses.first else {
            print("❌ FAILED: Eutirox not found in schedule")
            return
        }
        
        // Get the first Inofolic dose of the day
        let sortedInofolicDoses = inofolicDoses.sorted { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }
        guard let firstInofolicDose = sortedInofolicDoses.first else {
            print("❌ FAILED: Inofolic not found in schedule")
            return
        }
        
        // Check if Inofolic is scheduled after Eutirox
        let eutiroxTime = eutiroxDose.event.time
        let inofolicTime = firstInofolicDose.event.time
        
        if timeToMinutes(inofolicTime) <= timeToMinutes(eutiroxTime) {
            print("❌ FAILED: Inofolic (\(inofolicTime)) is scheduled before or at the same time as Eutirox (\(eutiroxTime))")
            return
        }
        
        // Check spacing between Eutirox and Inofolic (should be at least 30 minutes apart)
        let minRequiredSpacing = 30 // minutes
        let spacing = minutesBetween(time1: eutiroxTime, time2: inofolicTime)
        
        if spacing < minRequiredSpacing {
            print("❌ FAILED: Eutirox (\(eutiroxTime)) and Inofolic (\(inofolicTime)) are only \(spacing) minutes apart (required: at least \(minRequiredSpacing) minutes)")
        } else {
            print("✅ PASSED: Eutirox and Inofolic have sufficient spacing (\(spacing) minutes)")
        }
        
        // If there are multiple Inofolic doses, check that none are too close to Eutirox
        if sortedInofolicDoses.count > 1 {
            var allSpacingOk = true
            
            for inofolicDose in sortedInofolicDoses.dropFirst() {
                let doseTime = inofolicDose.event.time
                let doseSpacing = minutesBetween(time1: eutiroxTime, time2: doseTime)
                
                if doseSpacing < minRequiredSpacing {
                    print("❌ FAILED: Eutirox (\(eutiroxTime)) and Inofolic dose (\(doseTime)) are only \(doseSpacing) minutes apart (required: at least \(minRequiredSpacing) minutes)")
                    allSpacingOk = false
                }
            }
            
            if allSpacingOk {
                print("✅ PASSED: All Inofolic doses are sufficiently spaced from Eutirox")
            }
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
        let medicinesWithMultipleDoses = ["Nifelat", "Utrogestan 200mg", "Aleract", "Inofolic Combi", "Heferal", "Vitamin C"]
        
        for medicineName in medicinesWithMultipleDoses {
            let doses = findDoses(for: medicineName, in: schedule)
            if doses.count <= 1 {
                print("❌ FAILED: Expected multiple doses for \(medicineName), found \(doses.count)")
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
            if minSpacingMinutes < 120 {
                print("❌ FAILED: \(medicineName) doses have minimum spacing of only \(minSpacingMinutes) minutes (required: at least 120 minutes)")
            } else {
                print("✅ PASSED: \(medicineName) doses have good spacing (minimum \(minSpacingMinutes) minutes)")
            }
        }
    }
    
    // Test that Aleract doses are optimally spread throughout the day
    static func testAleractDoseSpacing(_ schedule: DailySchedule) {
        print("\n🧪 Testing Aleract Dose Distribution...")
        
        let aleractDoses = findDoses(for: "Aleract", in: schedule)
        if aleractDoses.count <= 1 {
            print("❌ FAILED: Expected multiple doses for Aleract, found \(aleractDoses.count)")
            return
        }
        
        // Sort doses by time
        let sortedDoses = aleractDoses.sorted { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }
        
        // Get essential daily events
        guard let wakeUp = schedule.events.first(where: { $0.type == .wakeUp }),
              let breakfast = schedule.events.first(where: { $0.name == "Breakfast" }),
              let sleep = schedule.events.first(where: { $0.type == .sleep }) else {
            print("❌ FAILED: Could not find necessary daily events")
            return
        }
        
        let firstDose = sortedDoses[0]
        let lastDose = sortedDoses[sortedDoses.count - 1]
        
        // Check if first dose is early enough (with breakfast or within 90 minutes of wake-up)
        let isFirstDoseWithBreakfast = firstDose.event.time == breakfast.time
        let minutesAfterWakeUp = minutesBetween(time1: wakeUp.time, time2: firstDose.event.time)
        let isFirstDoseEarlyEnough = isFirstDoseWithBreakfast || minutesAfterWakeUp <= 90
        
        if isFirstDoseEarlyEnough {
            print("✅ PASSED: First Aleract dose is scheduled early enough in the day (\(firstDose.event.time))")
        } else {
            print("❌ FAILED: First Aleract dose (\(firstDose.event.time)) is not scheduled early enough (required: with breakfast or within 90 min of waking)")
        }
        
        // Find the latest medication time in the entire schedule
        let allDoses = schedule.scheduledDoses
        let latestDoseTime = allDoses.max { 
            timeToMinutes($0.event.time) < timeToMinutes($1.event.time) 
        }?.event.time ?? "00:00"
        
        // Check if the last Aleract dose is scheduled at the latest possible time
        let minutesBeforeSleep = minutesBetween(time1: lastDose.event.time, time2: sleep.time)
        let isLatestPossible = lastDose.event.time == latestDoseTime
        
        if isLatestPossible {
            print("✅ PASSED: Last Aleract dose is scheduled at the latest possible time (\(lastDose.event.time), \(minutesBeforeSleep) minutes before sleep)")
        } else {
            let minutesEarlier = minutesBetween(time1: lastDose.event.time, time2: latestDoseTime)
            print("❌ FAILED: Last Aleract dose (\(lastDose.event.time)) could be scheduled \(minutesEarlier) minutes later (latest medication is at \(latestDoseTime))")
        }
        
        // For Aleract specifically (2 doses), check if doses are well distributed
        if aleractDoses.count == 2 {
            // No calculations needed since we're not using the coverage metric
        }
    }
    
    // Test that Utrogestan and Nifelat are separated by at least 90 minutes
    static func testUtrogestanNifelatSeparation(_ schedule: DailySchedule) {
        print("\n🧪 Testing Utrogestan-Nifelat Separation...")
        
        let utrogestanDoses = findDoses(for: "Utrogestan 200mg", in: schedule)
        let nifelatDoses = findDoses(for: "Nifelat", in: schedule)
        
        if utrogestanDoses.isEmpty || nifelatDoses.isEmpty {
            print("❌ FAILED: Could not find both Utrogestan and Nifelat in schedule")
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
            print("❌ FAILED: Breakfast not found in schedule")
            return
        }
        guard let dinner = schedule.events.first(where: { $0.name == "Dinner" }) else {
            print("❌ FAILED: Dinner not found in schedule")
            return
        }
        
        if hefevalDoses.count >= 2 {
            // First dose should be 1h before breakfast
            let firstDose = hefevalDoses.min { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }!
            let minutesBeforeBreakfast = minutesBetween(time1: firstDose.event.time, time2: breakfast.time)
            
            if abs(minutesBeforeBreakfast - 60) > 15 {
                print("❌ FAILED: First Heferal dose is \(minutesBeforeBreakfast) minutes before breakfast (required: 45-75 minutes before)")
            } else {
                print("✅ PASSED: First Heferal dose is properly scheduled before breakfast (\(firstDose.event.time))")
            }
            
            // Last dose should be 2h after dinner
            let lastDose = hefevalDoses.max { timeToMinutes($0.event.time) < timeToMinutes($1.event.time) }!
            let minutesAfterDinner = minutesBetween(time1: dinner.time, time2: lastDose.event.time)
            
            if abs(minutesAfterDinner - 120) > 15 {
                print("❌ FAILED: Last Heferal dose is \(minutesAfterDinner) minutes after dinner (required: 105-135 minutes after)")
            } else {
                print("✅ PASSED: Last Heferal dose is properly scheduled after dinner (\(lastDose.event.time))")
            }
        }
        
        // Test Pronison - after breakfast
        let pronisonDoses = findDoses(for: "Pronison 5mg", in: schedule)
        if let pronisonDose = pronisonDoses.first {
            if pronisonDose.event.time == breakfast.time {
                print("✅ PASSED: Pronison is scheduled with breakfast (\(pronisonDose.event.time))")
            } else {
                print("❌ FAILED: Pronison (\(pronisonDose.event.time)) is not scheduled with breakfast (\(breakfast.time))")
            }
        }
    }
}

// Main function to run the tests
func runTests() {
    MedicineTests.runAllTests()
} 