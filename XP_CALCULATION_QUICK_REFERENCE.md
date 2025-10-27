# 🎯 XP Calculation - Quick Reference Card

## 🎁 Instant XP Rewards (NEW!)

**Earn XP from various activities in the app!**

### Race Activities

| Action | XP Earned | Notes |
|--------|-----------|-------|
| **Create a Race** | **+15 XP** | Awarded when you create any race |
| **Join a Race** | **+10 XP** | Only for NEW joins (not updates) |
| **First Race Ever** | **+50 XP** | One-time bonus for joining your first race |
| **Race Milestone (25%)** | **+5 XP** | When you reach 25% completion |
| **Race Milestone (50%)** | **+5 XP** | When you reach 50% completion |
| **Race Milestone (75%)** | **+5 XP** | When you reach 75% completion |
| **First Win Ever** | **+100 XP** | One-time bonus for winning your first race |

### Social Activities

| Action | XP Earned | Notes |
|--------|-----------|-------|
| **Add a Friend** | **+20 XP** | Both users receive XP when request accepted |

### Profile & Onboarding

| Action | XP Earned | Notes |
|--------|-----------|-------|
| **Complete Profile** | **+30 XP** | One-time bonus for completing your profile |

---

## Race Completion Formula

```
Total XP = Participation XP + Placement XP + Bonus XP
```

---

## 1️⃣ Base XP (Distance-Based)

| Distance | Base XP | Example |
|----------|---------|---------|
| < 5 km | `50 × (distance ÷ 5)` | 2.5 km → 25 XP |
| 5-10 km | **50 XP** | 7 km → 50 XP |
| 10-15 km | **100 XP** | 12 km → 100 XP |
| 15-20 km | **200 XP** | 18 km → 200 XP |
| > 20 km | `200 × (distance ÷ 15)` | 30 km → 400 XP |

---

## 2️⃣ Participation XP

```
Participation XP = Base XP × Distance Multiplier
Distance Multiplier = distance ÷ 5
```

### Quick Examples

| Distance | Base XP | Multiplier | Participation XP |
|----------|---------|------------|------------------|
| 5 km | 50 | 1.0 | **50 XP** |
| 7 km | 50 | 1.4 | **70 XP** |
| 10 km | 100 | 2.0 | **200 XP** |
| 12 km | 100 | 2.4 | **240 XP** |
| 15 km | 200 | 3.0 | **600 XP** |
| 20 km | 200 | 4.0 | **800 XP** |

---

## 3️⃣ Placement XP

| Position | Placement XP |
|----------|--------------|
| 🥇 **1st Place** | **500 XP** |
| 🥈 **2nd Place** | **300 XP** |
| 🥉 **3rd Place** | **200 XP** |
| 4th+ | **0 XP** |

---

## 4️⃣ Bonus XP

| Achievement | Bonus XP |
|-------------|----------|
| ⚡ **Fastest Speed** | **100 XP** |

*Only awarded to the participant with the highest average speed in the race*

---

## 🧮 Complete Examples

### Example 1: 10 km Race - 1st Place (Fastest)
```
Base XP:           100 (10-15 km bracket)
Participation XP:  100 × 2.0 = 200 XP
Placement XP:      500 XP (1st place)
Bonus XP:          100 XP (fastest speed)
─────────────────────────────────────
Total XP:          800 XP
```

### Example 2: 10 km Race - 2nd Place
```
Base XP:           100 (10-15 km bracket)
Participation XP:  100 × 2.0 = 200 XP
Placement XP:      300 XP (2nd place)
Bonus XP:          0 XP (not fastest)
─────────────────────────────────────
Total XP:          500 XP
```

### Example 3: 10 km Race - 4th Place
```
Base XP:           100 (10-15 km bracket)
Participation XP:  100 × 2.0 = 200 XP
Placement XP:      0 XP (4th place)
Bonus XP:          0 XP (not fastest)
─────────────────────────────────────
Total XP:          200 XP
```

### Example 4: 5 km Race - 1st Place
```
Base XP:           50 (5-10 km bracket)
Participation XP:  50 × 1.0 = 50 XP
Placement XP:      500 XP (1st place)
Bonus XP:          100 XP (fastest speed)
─────────────────────────────────────
Total XP:          650 XP
```

### Example 5: 15 km Race - 3rd Place
```
Base XP:           200 (15-20 km bracket)
Participation XP:  200 × 3.0 = 600 XP
Placement XP:      200 XP (3rd place)
Bonus XP:          0 XP (not fastest)
─────────────────────────────────────
Total XP:          800 XP
```

---

## 📊 Level Calculation

```
Level = floor(Total XP ÷ 1000) + 1
```

| Total XP | Level |
|----------|-------|
| 0 - 999 | **Level 1** |
| 1,000 - 1,999 | **Level 2** |
| 2,000 - 2,999 | **Level 3** |
| 3,000 - 3,999 | **Level 4** |
| 5,000 - 5,999 | **Level 6** |
| 10,000 - 10,999 | **Level 11** |

### Progress to Next Level

```
XP in current level = Total XP % 1000
XP to next level = 1000 - (Total XP % 1000)
Progress % = (Total XP % 1000) ÷ 1000 × 100
```

**Example:** User with 2,450 XP
```
Current level:      3 (2,450 ÷ 1,000 = 2.45, floor + 1 = 3)
XP in level:        450 (2,450 % 1,000)
XP to level 4:      550 (1,000 - 450)
Progress:           45% (450 ÷ 1,000 × 100)
```

---

## 🎯 Quick Calculator

### To Calculate Participation XP:
1. Find Base XP from distance bracket
2. Calculate multiplier: `distance ÷ 5`
3. Multiply: `Base XP × multiplier`

### To Calculate Total XP:
1. Participation XP (from above)
2. Add Placement XP (500/300/200/0)
3. Add Bonus XP (100 if fastest, else 0)

### To Calculate Level:
```dart
level = (totalXP / 1000).floor() + 1
```

---

## 💡 Key Points

### Quick XP Opportunities
- **🏁 Create a race** → 15 XP
- **🎁 Join any race** → 10 XP
- **🏆 First race ever** → 50 XP (one-time)
- **🎯 Race milestones** → 5 XP each (25%, 50%, 75%)
- **👥 Add a friend** → 20 XP (both users)
- **📝 Complete profile** → 30 XP (one-time)

### Race Completion
- **Everyone gets Participation XP** for completing the race
- **Only top 3 get Placement XP** (500/300/200)
- **Only fastest gets Bonus XP** (100)
- **First win ever** → +100 XP (one-time)

### Maximum XP Example (First Race, Create + Win)
```
Create Race:           15 XP
Join Race:             10 XP
First Race Bonus:      50 XP
Milestones (3x5):      15 XP
Race Completion:      200 XP (participation)
1st Place:            500 XP (placement)
Fastest Speed:        100 XP (bonus)
First Win Bonus:      100 XP
────────────────────────────
Total:                990 XP
```

---

## 📍 Implementation Location

**Join XP Award:**
- File: `lib/services/xp_service.dart`
- Method: `awardJoinRaceXP(userId, raceId, raceTitle)`
- Trigger: `lib/services/firebase_service.dart` → `addParticipantToRace()`
- Awarded: Immediately when user joins a race

**Race Completion XP Calculation:**
- File: `lib/services/xp_service.dart`
- Method: `calculateRaceXP()`

**Formula Methods:**
```dart
int calculateBaseXP(double distance)
double calculateDistanceMultiplier(double distance)
int calculateParticipationXP(double distance)
int calculatePlacementXP(int rank)
int calculateBonusXP({required double avgSpeed, ...})
```

**Completion XP Award Trigger:**
- File: `lib/services/firebase_service.dart`
- Method: `finishRace(raceId)`
- Calls: `xpService.awardXPToParticipants(raceId)`

---

**For detailed information, see:** `LEADERBOARD_XP_SYSTEM_GUIDE.md`
