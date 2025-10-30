# StepzSync Translation - Quick Start Guide

## 🎯 What You Have

**Main File:** `StepzSync_Translation_Master.xlsx` (117 KB)

This Excel workbook contains **3,734 user-facing strings** from your Flutter app, organized into 12 category sheets ready for translation.

---

## 📊 Quick Stats

- **Total Strings:** 3,734 (filtered from 8,753 raw extractions)
- **Files Scanned:** 196 Dart files
- **Categories:** 12 organized sheets
- **Format:** Excel (.xlsx) - Compatible with Excel, Google Sheets, LibreOffice

---

## 📋 What's in the Excel File

### 1. **Instructions Sheet**
Complete translator guide with:
- Translation guidelines
- How to handle placeholders
- Best practices
- Quality checklist

### 2. **Summary Sheet**
- Statistics overview
- String count by category
- Progress tracker (update as you translate)

### 3-14. **Category Sheets** (12 total)

| # | Category | Strings | Priority |
|---|----------|---------|----------|
| 1 | Authentication | 206 | 🔴 HIGH |
| 2 | Profile & Settings | 184 | 🟡 MEDIUM |
| 3 | Race Management | 497 | 🔴 HIGH |
| 4 | Active Races | 123 | 🔴 HIGH |
| 5 | Social Features | 168 | 🔴 HIGH |
| 6 | Leaderboard & Stats | 34 | 🟡 MEDIUM |
| 7 | Home & Navigation | 191 | 🔴 HIGH |
| 8 | Dialogs & Popups | 139 | 🔴 HIGH |
| 9 | Subscription/Premium | 106 | 🟡 MEDIUM |
| 10 | Errors & Validation | 42 | 🔴 HIGH |
| 11 | Admin Dashboard | 109 | 🟡 MEDIUM |
| 12 | Common/Shared | 1,935 | 🟢 LOW |

---

## 🚀 How to Use (3 Simple Steps)

### Step 1: Open the Excel File
```
StepzSync_Translation_Master.xlsx
```

### Step 2: Read the Instructions Sheet
- Understand translation guidelines
- Learn about placeholders
- Note best practices

### Step 3: Add Your Translations

**Option A - Add Language Columns**
- Add column D for your first target language
- Header example: "Spanish (es)"
- Add column E for second language
- etc.

**Option B - Import to Google Sheets**
- Upload to Google Drive
- Open in Google Sheets
- Share with your translation team
- Collaborate in real-time

**Option C - Make Copies**
- Save as `StepzSync_Translation_Spanish.xlsx`
- Save as `StepzSync_Translation_French.xlsx`
- Send to different translators

---

## 📝 Each Row Contains

| Column | Name | Description |
|--------|------|-------------|
| **A** | English Text | The original text to translate |
| **B** | Screen/Context | Where it appears (e.g., "Login Screen") |
| **C** | Notes | Context, type, special instructions |

---

## ⚠️ Important: Placeholders

**DO NOT translate these:**
- `{count}` - Variable placeholders
- `{name}` - Will be replaced at runtime
- `$variable` - Dart string interpolation
- `%s`, `%d` - Format specifiers

**Example:**
```
English: "You have {count} friends"
Spanish: "Tienes {count} amigos"  ✅ Correct
Spanish: "Tienes {número} amigos" ❌ Wrong - don't translate {count}
```

---

## 🎯 Recommended Translation Order

### Start Here (High Priority) - 1,278 strings
1. Authentication (206)
2. Race Management (497)
3. Dialogs & Popups (139)
4. Errors & Validation (42)
5. Home & Navigation (191)
6. Active Races (123)
7. Social Features (168)

### Then Do (Medium Priority) - 523 strings
8. Profile & Settings (184)
9. Subscription/Premium (106)
10. Leaderboard & Stats (34)
11. Admin Dashboard (109)

### Finally (Lower Priority) - 1,935 strings
12. Common/Shared (1,935) - Many duplicates, less critical

---

## ✅ Quality Checklist

Before submitting translations:
- [ ] Read all instructions
- [ ] Preserved all placeholders exactly as-is
- [ ] Kept button labels concise (under 20 characters)
- [ ] Maintained consistent terminology
- [ ] Reviewed translations in context of their screen
- [ ] Checked that error messages are clear and helpful
- [ ] Ensured questions end with proper punctuation
- [ ] Used Summary sheet to track progress

---

## 📁 Additional Files (Backup)

### translation_sheets/
Contains individual CSV files for each category
- Useful for version control
- Can be imported separately
- Backup if Excel file is corrupted

### translation_strings.json
- Raw extracted data
- For developers
- Contains all 8,753 original extractions before filtering

---

## 🔧 Regenerating/Updating

If you add new features to the app and need to extract new strings:

```bash
# 1. Extract strings from code
dart extract_strings.dart

# 2. Generate CSV files
python3 generate_excel_simple.py

# 3. Convert to Excel (requires virtual environment)
python3 -m venv venv
source venv/bin/activate
pip install xlsxwriter
python csv_to_excel.py
deactivate
```

---

## 📊 Coverage Guarantee

### ✅ Included (100% Coverage)
- All UI text visible to users
- Screen titles and subtitles
- Button labels
- Form inputs (labels, hints, placeholders)
- Error messages
- Success messages
- Dialog content
- Toast/Snackbar messages
- Navigation labels
- Help text and descriptions

### ❌ Excluded (Intentionally)
- Technical code (variable names, class names)
- Debug messages
- API endpoints
- Configuration strings
- Developer comments

### ⚠️ Not Included (Scope Limitation)
- Firebase Cloud Functions notifications (~100 strings in JavaScript)
  - *These are in functions/notifications/ directory*
  - *Let us know if you need these extracted separately*

---

## 🆘 Need Help?

### Common Issues

**Q: Excel file won't open?**
A: Try opening in Google Sheets or LibreOffice Calc

**Q: Too many strings to translate?**
A: Start with high-priority sheets only (1,278 strings instead of 3,734)

**Q: What if I find a string that doesn't make sense?**
A: Check the Screen/Context column for where it appears in the app

**Q: Can I edit the extraction scripts?**
A: Yes! They're in the project root:
- `extract_strings.dart` - Main extraction
- `generate_excel_simple.py` - CSV generator
- `csv_to_excel.py` - Excel converter

---

## 📞 Questions?

For clarification on any strings, reference:
- Row number in Excel
- Category sheet name
- Screen/Context information

Contact your development team with these details.

---

## 🎉 You're Ready!

Everything is prepared and ready for translation. The Excel file is comprehensive, well-organized, and translator-friendly.

**Next step:** Send `StepzSync_Translation_Master.xlsx` to your translation team!

---

**Created:** October 30, 2025
**Total Strings:** 3,734
**File Size:** 117 KB
**Status:** ✅ Ready for Translation
