# Medicine Schedule Generator

A Swift command-line application that generates a daily schedule for taking medicines based on specific rules, dosages, and timing requirements.

## Features

- Reads a list of medicines from a file (`listaLekova.md`)
- Parses medicine-specific rules and requirements
- Takes into account daily events (wake up, meals, sleep)
- Creates an optimized schedule that respects medicine-specific requirements
- Handles special cases like:
  - Medicines that need to be taken on an empty stomach
  - Medicines that must be taken with food
  - Medicines that need to be separated from other medicines
  - Medicines with specific timing or meal requirements
  - Specific dosage instructions and rotations

## How to Use

1. Ensure your list of medicines is in the `listaLekova.md` file in the current directory
2. Run the application:

```bash
swift run terapija
```

3. The application will read the medicine list, generate a schedule based on default daily events, and display the results.

## Medicine List Format

The medicine list file (`listaLekova.md`) should contain entries in the following format:

```
- MedicineName: dosage instructions and special rules
```

For example:
```
- Eutirox: 4 days = 50mg + 3 days = 75mg (take it on empty stomach, in the morning, 30-60 minutes before taking the food)
- Aleract: 2x per day
```

## Customization

You can modify the daily event times by updating the `setDailyEvents` parameters in `main.swift`. The default times are:

- Wake up: 07:00
- Breakfast: 08:00
- Lunch: 13:00
- Dinner: 19:00
- Sleep: 23:00

## Requirements

- Swift 5.0+
- macOS, Linux, or any platform supporting Swift 