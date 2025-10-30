# Sample Translations - Preview

Here are real examples from the Excel file showing how strings are organized:

---

## Example 1: Authentication Strings

| English Text | Screen/Context | Notes |
|--------------|----------------|-------|
| Welcome Back! | Login Screen | Text Widget, Likely button label |
| Sign In | Login Screen | Text Widget, Likely button label - keep concise |
| Phone Number | Login Screen | Form Input |
| Enter your phone number | Login Screen | Form Input |
| Email Address | Login Screen | Form Input |
| Enter your email | Login Screen | Form Input |
| Password | Login Screen | Form Input |
| Enter your password | Login Screen | Form Input |
| Confirm Password | Login Screen | Form Input |
| Re-enter your password | Login Screen | Form Input |

---

## Example 2: Error Messages

| English Text | Screen/Context | Notes |
|--------------|----------------|-------|
| Please enter your email address | App Constants | String Literal |
| Please enter a valid email address | App Constants | String Literal, Error message |
| Password must be at least 6 characters | App Constants | String Literal, Error message |
| Login successful | App Constants | String Literal, Success message |
| Account created successfully | App Constants | String Literal, Success message |
| Password reset email sent | App Constants | String Literal, Success message |

---

## Example 3: Race Management (with Placeholders)

| English Text | Screen/Context | Notes |
|--------------|----------------|-------|
| ${item.rank} | Race Winner Screens | Contains variable placeholder - DO NOT TRANSLATE ${item.rank} |
| #${participant.rank} | Race Winner Screens | Contains variable placeholder - KEEP # and ${participant.rank} |
| Steps: ${sortedParticipants[0].steps} | Race Winner Screens | Contains variable placeholder - KEEP ${...} |
| Calories: ${sortedParticipants[0].calories} | Race Winner Screens | Contains variable placeholder - KEEP ${...} |

**Translation Example:**
```
English: "Steps: ${sortedParticipants[0].steps}"
Spanish: "Pasos: ${sortedParticipants[0].steps}"  ✅ Correct
Spanish: "Pasos: ${sortedParticipants[0].pasos}"  ❌ Wrong - don't translate the variable
```

---

## Example 4: Social Features

| English Text | Screen/Context | Notes |
|--------------|----------------|-------|
| Friends | Friends List Screen | Text Widget, Likely button label - keep concise |
| Friend Requests | Friends List Screen | Text Widget |
| Search Users | User Search Screen | Text Widget |
| Send Friend Request | User Search Screen | Button label - keep concise |
| Accept | Friend Requests Screen | Button label - keep concise |
| Decline | Friend Requests Screen | Button label - keep concise |
| Chat | Chat Screen | Text Widget, Likely button label - keep concise |
| Type a message... | Chat Screen | Form Input, Hint text |

---

## Example 5: Dialogs & Popups

| English Text | Screen/Context | Notes |
|--------------|----------------|-------|
| Allow Health Data Access | Health Permission Dialog | Dialog title |
| StepzSync needs access to your health data to track your steps and activity | Health Permission Dialog | Dialog, explanation |
| Sync Health Data? | Health Sync Dialog | Dialog, Question |
| Your step count will be synced with HealthKit | Health Sync Dialog | Dialog description |
| Sync Now | Health Sync Dialog | Button label - keep concise |
| Cancel | Health Sync Dialog | Button label - keep concise |

---

## Example 6: Race Features

| English Text | Screen/Context | Notes |
|--------------|----------------|-------|
| Create Race | Race Management Screen | Button label - keep concise |
| Race Name | Create Race Screen | Form Input |
| Enter race name | Create Race Screen | Form Input, Hint text |
| Start Time | Create Race Screen | Form Input |
| Duration | Create Race Screen | Form Input |
| Invite Friends | Race Invites Screen | Button label - keep concise |
| Race Started! | Race Screen | Success message |
| You Won! | Race Winner Screen | Success message |

---

## How to Translate These

### Step 1: Understand Context
Look at the **Screen/Context** column to know where the string appears

### Step 2: Read Notes
The **Notes** column tells you:
- Type of string (Button, Dialog, Error, etc.)
- If it contains placeholders (DO NOT TRANSLATE THESE)
- Special instructions (keep concise, character limits, etc.)

### Step 3: Translate
Add your translation in a new column (D, E, F, etc.)

### Example Translation Table

| English Text | Screen/Context | Notes | Spanish (es) |
|--------------|----------------|-------|--------------|
| Welcome Back! | Login Screen | Text Widget | ¡Bienvenido de nuevo! |
| Sign In | Login Screen | Button label | Iniciar Sesión |
| Email Address | Login Screen | Form Input | Correo Electrónico |
| Enter your email | Login Screen | Hint text | Ingresa tu correo |
| Password must be at least 6 characters | App Constants | Error message | La contraseña debe tener al menos 6 caracteres |

---

## Common Patterns You'll See

### 1. Button Labels (Keep Short!)
- Sign In, Sign Out, Cancel, Save, Delete, Edit, etc.
- **Tip:** Keep under 15-20 characters if possible

### 2. Form Inputs
- Labels: "Email Address", "Phone Number", "Password"
- Hints: "Enter your email", "Type a message..."
- **Tip:** Hints can be slightly longer than labels

### 3. Error Messages
- "Please enter...", "Invalid...", "Must be at least..."
- **Tip:** Keep them clear and helpful

### 4. Success Messages
- "Login successful", "Race created!", "Friend added"
- **Tip:** Maintain the positive tone

### 5. Questions
- "Delete this race?", "Are you sure?", "Enable notifications?"
- **Tip:** Keep question format in your language

---

## Placeholder Examples (CRITICAL)

### DO NOT TRANSLATE THESE PARTS:

```
❌ Wrong:
"${user.name} sent you a message"  →  "${usuario.nombre} te envió un mensaje"

✅ Correct:
"${user.name} sent you a message"  →  "${user.name} te envió un mensaje"
```

### Common Placeholder Patterns:
- `${variable}` - Dart string interpolation
- `{count}`, `{name}`, `{value}` - Named placeholders
- `%s`, `%d`, `%f` - Format specifiers
- `$variable` - Simple Dart variables

**ALWAYS keep these EXACTLY as they are!**

---

## Quality Tips

✅ **Do:**
- Translate the meaning, not word-for-word
- Keep the same tone (formal, casual, friendly)
- Consider cultural context
- Maintain consistent terminology
- Check that translations fit in UI (especially buttons)

❌ **Don't:**
- Translate placeholders/variables
- Make button labels too long
- Change the meaning significantly
- Use inconsistent terms for the same concept
- Skip reading the Notes column

---

## Real-World Translation Example

### Before (English)
```
┌─────────────────────────────────────┐
│  Welcome Back!                      │
│                                     │
│  Email Address                      │
│  [Enter your email            ]     │
│                                     │
│  Password                           │
│  [Enter your password         ]     │
│                                     │
│         [Sign In]                   │
└─────────────────────────────────────┘
```

### After (Spanish)
```
┌─────────────────────────────────────┐
│  ¡Bienvenido de nuevo!              │
│                                     │
│  Correo Electrónico                 │
│  [Ingresa tu correo           ]     │
│                                     │
│  Contraseña                         │
│  [Ingresa tu contraseña       ]     │
│                                     │
│         [Iniciar Sesión]            │
└─────────────────────────────────────┘
```

Notice:
- "Sign In" button stays short → "Iniciar Sesión"
- Hints remain clear
- Labels are concise
- Overall structure maintained

---

## Summary

The Excel file contains **3,734 strings** like these examples, organized into **12 category sheets** for easy navigation.

Each string has:
1. **English Text** - What to translate
2. **Screen/Context** - Where it appears
3. **Notes** - How to translate it

**You're ready to start translating!**

Open `StepzSync_Translation_Master.xlsx` and begin with high-priority sheets (Authentication, Race Management, etc.)
