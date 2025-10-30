#!/usr/bin/env python3
"""
Generate Excel translation workbook from extracted strings using only standard library
"""

import json
import csv
from collections import defaultdict
from datetime import datetime

def load_strings_data():
    """Load the extracted strings from JSON file"""
    with open('translation_strings.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data

def clean_and_deduplicate_strings(strings_data):
    """Clean strings and remove obvious duplicates while preserving context"""
    seen = {}
    cleaned = []

    for string_obj in strings_data:
        text = string_obj['text']
        screen = string_obj['screenContext']
        category = string_obj['category']

        # Skip very technical strings that slipped through
        if _is_technical_string(text):
            continue

        # Create a key for deduplication
        key = (text.lower().strip(), category)

        if key not in seen:
            seen[key] = string_obj
            cleaned.append(string_obj)
        else:
            # If same text in different screens, combine the contexts
            existing = seen[key]
            if screen not in existing['screenContext']:
                existing['screenContext'] += f'; {screen}'

    return cleaned

def _is_technical_string(text):
    """Filter out technical/non-user-facing strings"""
    technical_keywords = [
        'widget', 'controller', 'service', 'model', 'provider',
        'firebase', 'firestore', 'collection', 'document',
        '.dart', '.json', 'toString', 'override', 'async',
        'await', 'class', 'extends', 'implements', 'void',
        'String', 'int', 'bool', 'double', 'List', 'Map',
        'setState', 'initState', 'dispose', 'build',
        'BuildContext', 'StatefulWidget', 'StatelessWidget',
    ]

    lower_text = text.lower()

    # Check for technical keywords
    for keyword in technical_keywords:
        if keyword.lower() in lower_text:
            return True

    # Check for camelCase (likely variable names)
    if len(text) > 3 and any(c.isupper() for c in text[1:]) and not any(c.isspace() for c in text):
        return True

    # Check for snake_case with multiple underscores
    if text.count('_') > 1:
        return True

    # Very short technical strings
    if len(text) < 3 and not text.isalpha():
        return True

    # All uppercase short strings (constants)
    if text.isupper() and len(text) < 10:
        return True

    return False

def organize_by_sheets(strings_data):
    """Organize strings into sheets by category"""
    sheets_data = {}

    category_order = [
        'Authentication',
        'Profile & Settings',
        'Race Management',
        'Active Races',
        'Social Features',
        'Leaderboard & Stats',
        'Home & Navigation',
        'Dialogs & Popups',
        'Subscription/Premium',
        'Errors & Validation',
        'Admin Dashboard',
        'Common/Shared',
    ]

    for category in category_order:
        sheets_data[category] = []

    for string_obj in strings_data:
        category = string_obj['category']
        sheets_data[category].append({
            'English Text': string_obj['text'],
            'Screen/Context': string_obj['screenContext'],
            'Notes': string_obj['notes'],
        })

    return sheets_data

def create_csv_files(sheets_data, metadata):
    """Create CSV files for each category (Excel can open these)"""
    import os

    # Create output directory
    output_dir = 'translation_sheets'
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Create instructions file
    create_instructions_file(output_dir, metadata)

    # Create summary file
    create_summary_file(output_dir, sheets_data, metadata)

    # Create category CSV files
    file_count = 0
    for category, strings in sheets_data.items():
        if strings:  # Only create file if it has data
            filename = f'{output_dir}/{file_count:02d}_{category.replace("/", "-").replace(" ", "_")}.csv'
            with open(filename, 'w', encoding='utf-8-sig', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['English Text', 'Screen/Context', 'Notes'])
                writer.writeheader()
                writer.writerows(strings)
            file_count += 1
            print(f'   ✓ Created: {category} ({len(strings)} strings)')

    return output_dir

def create_instructions_file(output_dir, metadata):
    """Create instructions file for translators"""
    filename = f'{output_dir}/00_INSTRUCTIONS.txt'

    instructions = f"""
╔═══════════════════════════════════════════════════════════════════╗
║          StepzSync Translation Guide                              ║
╚═══════════════════════════════════════════════════════════════════╝

PROJECT INFORMATION:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  App Name:         StepzSync
  Type:             Fitness Tracking & Racing App
  Platform:         Flutter (iOS & Android)
  Extracted Date:   {metadata['extractedAt'][:10]}
  Total Strings:    {metadata['totalStrings']}

HOW TO USE THESE FILES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Each CSV file represents a different section of the app
  • Files are numbered (01_, 02_, etc.) for easy organization
  • Each CSV has three columns:
    - Column A: English Text (the original text to translate)
    - Column B: Screen/Context (where this text appears)
    - Column C: Notes (additional context)

TRANSLATION GUIDELINES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Keep the same tone and style as the English text
  2. For button labels, keep translations concise
  3. Pay attention to placeholders (marked in Notes)
  4. Placeholders like {{count}}, {{name}}, $variable should NOT be translated
  5. Maintain similar text length for UI elements
  6. Error messages should be clear and helpful
  7. Questions should end with appropriate punctuation

SPECIAL CONSIDERATIONS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • Health & Fitness terms should use standard translations
  • Race terminology should be consistent throughout
  • Premium/Subscription text should be clear about benefits
  • Permission requests should explain why clearly

ADDING YOUR TRANSLATION:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Option 1: Add a new column (D, E, etc.) for each target language
  Option 2: Create a copy of files for each language
  Option 3: Import into Excel/Google Sheets for easier editing

  Recommended: Open all CSV files in Excel, then save as .xlsx workbook

QUALITY ASSURANCE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Review translations in context of their screen
  ✓ Check that button labels fit on buttons
  ✓ Ensure error messages make sense
  ✓ Test that placeholders are preserved correctly
  ✓ Verify consistency across similar screens

QUESTIONS OR ISSUES?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Contact the development team for clarification on any strings.

"""

    with open(filename, 'w', encoding='utf-8') as f:
        f.write(instructions)

def create_summary_file(output_dir, sheets_data, metadata):
    """Create summary CSV file"""
    filename = f'{output_dir}/01_SUMMARY.csv'

    rows = [
        ['StepzSync Translation Summary', ''],
        ['', ''],
        ['Extraction Date:', metadata['extractedAt'][:10]],
        ['Total Strings Found:', metadata['totalStrings']],
        ['Files Processed:', metadata['filesProcessed']],
        ['', ''],
        ['Strings by Category:', 'Count'],
    ]

    # Add category counts
    for category, strings in sheets_data.items():
        if strings:
            rows.append([category, len(strings)])

    rows.extend([
        ['', ''],
        ['Translation Progress Tracker:', ''],
        ['(Update this as you complete translation)', ''],
        ['', ''],
        ['Category', 'Total Strings', 'Translated', 'Progress %'],
    ])

    # Add progress tracking rows
    for category, strings in sheets_data.items():
        if strings:
            rows.append([category, len(strings), 0, '0%'])

    with open(filename, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

def main():
    print('📊 Generating Translation Files...\n')

    # Load data
    print('📖 Loading extracted strings...')
    data = load_strings_data()

    print(f'   Found {len(data["strings"])} strings from {data["metadata"]["filesProcessed"]} files')

    # Clean and deduplicate
    print('🧹 Cleaning and filtering strings...')
    cleaned_strings = clean_and_deduplicate_strings(data['strings'])
    print(f'   After filtering: {len(cleaned_strings)} user-facing strings')

    # Organize into sheets
    print('\n📑 Organizing into categories...')
    sheets_data = organize_by_sheets(cleaned_strings)

    # Update metadata with cleaned count
    data['metadata']['totalStrings'] = len(cleaned_strings)

    # Print category summary
    print('\n📈 Strings per category:')
    total_in_sheets = 0
    for category, strings in sheets_data.items():
        if strings:
            print(f'   {category}: {len(strings)} strings')
            total_in_sheets += len(strings)

    # Create CSV files
    print('\n📝 Creating CSV files...')
    output_dir = create_csv_files(sheets_data, data['metadata'])

    print(f'\n✅ Translation files created successfully!')
    print(f'📁 Output directory: {output_dir}/')
    print(f'📊 Total translatable strings: {len(cleaned_strings)}')
    print(f'📋 Number of category files: {len([s for s in sheets_data.values() if s])}')
    print(f'\n💡 Tip: You can open all CSV files in Excel and save as a single .xlsx workbook')
    print(f'💡 Or use: Import all CSVs into Google Sheets for collaborative translation')

if __name__ == '__main__':
    main()
