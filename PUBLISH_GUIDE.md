# 📱 Know Your Expenses — Google Play Publishing Guide

---

## 🔐 Part 1: Understanding App Signing (Read This First)

When you publish an Android app, Google requires you to **digitally sign** it.
Think of it like putting a **wax seal** on an envelope — it proves the app came from **you** and nobody tampered with it.

To sign the app you need:

| Term | What it actually is |
|---|---|
| **Keystore file** (`.jks`) | A file that acts like your digital ID card — it holds your signing keys |
| **Store Password** | The password that locks/protects the entire keystore file |
| **Key Alias** | A name/label you give to one specific key inside the keystore |
| **Key Password** | The password that locks that specific key inside the keystore |

> 💡 Think of it like a **safe (keystore)** with a **safe password (storePassword)**, and inside the safe there are **named envelopes (alias)** each with their own **lock (keyPassword)**.

---

## 🪄 Part 2: Create Your Keystore File (Step by Step)

You do NOT have a `key.jks` file yet — **you need to create it once**.
After you create it, **never delete it** — you'll need it for every future update.

---

### Step 1 — Open your Terminal

On Mac: Press `Cmd + Space` → type `Terminal` → press Enter

---

### Step 2 — Run this exact command

Copy and paste this into Terminal and press Enter:

```bash
keytool -genkey -v \
  -keystore ~/knowyourexpenses_key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias knowyourexpenses
```

**What each part means:**

| Part | Meaning |
|---|---|
| `-keystore ~/knowyourexpenses_key.jks` | Creates the file at your home folder with this name |
| `-keyalg RSA` | Uses RSA encryption (standard, don't change) |
| `-keysize 2048` | Key strength (2048 is secure, don't change) |
| `-validity 10000` | Valid for ~27 years (more than enough) |
| `-alias knowyourexpenses` | The label/name of the key inside the file |

---

### Step 3 — Answer the questions Terminal asks

Terminal will ask you several questions **one by one**.
Here is exactly what to type for each:

```
Enter keystore password:
```
→ **Type a strong password** (example: `KYE@2026secure!`)
→ **Write it down immediately — if you lose this, you CANNOT recover it**
→ This becomes your **storePassword**

```
Re-enter new password:
```
→ Type the same password again

```
What is your first and last name?
```
→ Type your full name (example: `Aryan Shah`)

```
What is the name of your organizational unit?
```
→ Type: `Dev` (or just press Enter to skip)

```
What is the name of your organization?
```
→ Type: `Know Your Expenses`

```
What is the name of your City or Locality?
```
→ Type your city (example: `Surat`)

```
What is the name of your State or Province?
```
→ Type your state (example: `Gujarat`)

```
What is the two-letter country code for this unit?
```
→ Type: `IN`

```
Is CN=Aryan Shah, OU=Dev, O=Know Your Expenses, L=Surat, ST=Gujarat, C=IN correct?
```
→ Type: `yes` and press Enter

```
Enter key password for <knowyourexpenses>
  (RETURN if same as keystore password):
```
→ Press **Enter** (this makes your keyPassword the same as storePassword — simpler)

---

### Step 4 — Verify the file was created

Run this in Terminal:

```bash
ls ~/knowyourexpenses_key.jks
```

You should see:
```
/Users/YourName/knowyourexpenses_key.jks
```

✅ Your keystore file is created!

---

### Step 5 — Find the exact file path

Run this to get your exact path:

```bash
echo ~/knowyourexpenses_key.jks
```

It will print something like:
```
/Users/aryan/knowyourexpenses_key.jks
```

**Copy this path — you'll need it below.**

---

## ⚙️ Part 3: Fill in the Signing Config

Now open this file in your project:

```
android/app/build.gradle.kts
```

Replace the existing `buildTypes` block with this:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = "knowyourexpenses"
        keyPassword = "KYE@2026secure!"
        storeFile = file("/Users/aryan/knowyourexpenses_key.jks")
        storePassword = "KYE@2026secure!"
    }
}

android {
    // ... rest of your android block

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
        }
    }
}
```

**Replace the values with YOUR actual values:**

| Field in code | What to put |
|---|---|
| `keyAlias` | `knowyourexpenses` — this is exactly what you typed after `-alias` in the keytool command |
| `keyPassword` | The password you typed when Terminal asked "Enter key password" — if you pressed Enter to skip, it's the same as storePassword |
| `storeFile` | The full path printed by `echo ~/knowyourexpenses_key.jks` |
| `storePassword` | The very first password you typed when Terminal asked "Enter keystore password" |

---

## 🔒 Part 4: Keep These Safe (Very Important)

**Write these down and store them somewhere safe (not just on your laptop):**

```
Keystore file path : /Users/aryan/knowyourexpenses_key.jks
Key Alias          : knowyourexpenses
Store Password     : [the password you chose]
Key Password       : [same as store password if you pressed Enter]
```

> ⚠️ **WARNING:** If you lose the keystore file or forget the passwords,
> you will NEVER be able to update your app on Play Store.
> Google does not have a recovery option.
> **Back up the `.jks` file to Google Drive or iCloud.**

---

## 📦 Part 5: Build the Signed App Bundle

After filling in the `build.gradle.kts`, run:

```bash
flutter build appbundle --release
```

Your signed file will be at:
```
build/app/outputs/bundle/release/app-release.aab
```

This `.aab` file is what you upload to Google Play Console.

---

## ✅ Summary Cheat Sheet

```
STEP 1: Run keytool command in Terminal
        → Creates knowyourexpenses_key.jks file

STEP 2: Remember 4 things:
        keyAlias     = knowyourexpenses       (you chose this)
        keyPassword  = [your password]        (typed at "Enter key password")
        storeFile    = /Users/aryan/...jks    (path to the .jks file)
        storePassword= [your password]        (typed at "Enter keystore password")

STEP 3: Paste those 4 values into build.gradle.kts

STEP 4: Run: flutter build appbundle --release

STEP 5: Upload app-release.aab to Google Play Console
```

---

## ❓ Common Questions

**Q: I already ran keytool but I forgot my password. What do I do?**
A: There is no way to recover it. Delete the `.jks` file and run the keytool command again to create a new one. (Only okay to do BEFORE you publish — after publishing you cannot change the keystore.)

**Q: Can I use a simple password like `123456`?**
A: Technically yes, but strongly not recommended. Use something with letters, numbers, and a symbol.

**Q: What if storePassword and keyPassword are different?**
A: It's fine — just make sure you write down both separately. If you pressed Enter when asked for keyPassword, they are the same.

**Q: Where should I back up the `.jks` file?**
A: Google Drive, iCloud, or a USB drive. Do not keep it only on your laptop.

**Q: Can I share my `.jks` file with others?**
A: Only trusted people (like a co-developer). Never post it publicly on GitHub.

---

---

# 🚀 Part 2: Uploading Your App to Google Play Store

---

## 📋 What You Need Before Starting

Make sure you have all of these ready:

```
✅ app-release.aab file (built in Part 1)
✅ Google account
✅ $25 one-time developer fee (paid by card)
✅ App icon image — 512 × 512 px PNG
✅ Feature graphic image — 1024 × 500 px PNG
✅ At least 2 screenshots of the app
✅ Privacy policy URL (explained below)
```

---

## 🌐 Step 1 — Create Your Google Play Developer Account

1. Go to → **https://play.google.com/console**
2. Sign in with your Google account
3. Click **"Get Started"**
4. Fill in your developer name:

```
Developer name: Aryan Shah
(This is shown publicly on Play Store under your app)
```

5. Accept the Developer Distribution Agreement
6. Pay the **$25 registration fee** (one-time, never again)
7. Wait ~24 hours for account approval (usually faster)

---

## 📱 Step 2 — Create Your App

After account is approved:

1. Click **"Create app"** button (top right)
2. Fill in this form:

### App name
```
Know Your Expenses
```

### Default language
```
English (United States)
```

### App or game?
```
● App
```

### Free or paid?
```
● Free
```

3. Check both declaration checkboxes (confirm your app follows policies)
4. Click **"Create app"**

---

## ✍️ Step 3 — Fill in Store Listing

On the left sidebar click **"Store listing"** → **"Main store listing"**

---

### 3A — App Details

**App name** *(max 30 characters)*
```
Know Your Expenses
```

**Short description** *(max 80 characters — shown in search results)*
```
Track expenses, budgets & insights — all in one place.
```

**Full description** *(max 4000 characters — shown on app page)*
```
💰 Know Your Expenses — Smart Personal Finance Tracker

Take full control of your money with Know Your Expenses — a clean, fast, and powerful expense tracking app built for everyone.

Whether you spend on food, travel, shopping, or bills — this app helps you record, categorize, and understand every rupee you spend.

━━━ KEY FEATURES ━━━━━━━━━━━━━━━━━━

📊 Expense Dashboard
Get a clear overview of your total balance, income, and spending the moment you open the app.

➕ Add Transactions Instantly
Log expenses and income in seconds. Pick a category, enter amount, add a note — done.

📈 Financial Insights
Discover where your money goes with monthly bar charts and detailed spending breakdowns.

🥧 Spending Statistics
Interactive pie chart shows your expense split by category. Tap any slice to see exact amounts and percentages.

🗂️ Full Transaction History
See all your transactions in one place. Filter and scroll through your complete spending history.

👤 Personal Profile
Manage your name, email, phone, and profile picture. Update your photo with one tap.

🔒 Secure Google Sign-In
Sign in safely with your Google account. Data stored securely in the cloud and syncs automatically.

☁️ Cloud Backup
Your data lives in Firebase — always backed up, always accessible, even if you change your phone.

━━━ WHO IS IT FOR? ━━━━━━━━━━━━━━━━

• Students tracking pocket money
• Professionals managing salary and bills
• Anyone who wants to stop wondering where their money went

━━━ WHY KNOW YOUR EXPENSES? ━━━━━━━

✅ 100% Free — no subscriptions, no hidden charges
✅ Clean, modern and easy to use
✅ Secure cloud sync across devices
✅ Lightweight and fast
✅ Built with privacy in mind

Download Know Your Expenses today.
Because every rupee counts. 💚
```

---

### 3B — Graphics

Scroll down to the **"Graphics"** section.

#### App icon
- Size required: **512 × 512 px**
- Format: PNG
- Get your icon from: `assets/png/app_icon.png`
- Resize it to 512×512 using this command:

```bash
python3 -c "
from PIL import Image
img = Image.open('assets/png/app_icon.png').resize((512,512), Image.LANCZOS)
img.save('assets/png/app_icon_512.png')
print('Saved as app_icon_512.png')
"
```

Upload `assets/png/app_icon_512.png`

---

#### Feature graphic *(required)*
- Size: **1024 × 500 px**
- This is the banner shown at top of your Play Store page
- Go to **https://www.canva.com**
- Search template: `Google Play Feature Graphic`
- Use colors: Background `#1A5C3A` (dark green), Text white

**Text to put on it:**
```
Line 1 (big):   Know Your Expenses
Line 2 (small): Track • Analyse • Save Smarter
```

Download as PNG and upload here.

---

#### Screenshots *(minimum 2, recommended 5)*
- Size: at least **1080 × 1920 px** (portrait)
- Take screenshots from your phone while running the app

**Recommended screens to screenshot:**
```
Screenshot 1 → Home / Dashboard page
Screenshot 2 → Add Expense screen
Screenshot 3 → Statistics (Pie chart) page
Screenshot 4 → Financial Insights (Bar chart) page
Screenshot 5 → Profile page
```

To take a screenshot while the app is running:
- On your phone: press **Volume Down + Power button**
- Find the screenshot in your Gallery → transfer to laptop → upload

---

## 🏷️ Step 4 — App Categorization

On left sidebar click **"Store listing"** → scroll to **"Store settings"** or look for **"App category"**

| Field | Value to select |
|---|---|
| **App category** | Finance |
| **Tags** | expense tracker, budget planner, money manager |
| **Email address** | Your email (shown publicly for support) |

**Email to enter:**
```
[your personal email — this is shown on Play Store so users can contact you]
```

---

## 🔞 Step 5 — Content Rating

On left sidebar click **"Policy"** → **"App content"** → **"Content rating"**

1. Click **"Start questionnaire"**
2. Select category: **"Utility"**
3. Answer every question:

| Question | Your Answer |
|---|---|
| Violence of any kind? | **No** |
| Sexual content? | **No** |
| Profanity or crude humor? | **No** |
| Controlled substances? | **No** |
| User location shared? | **No** |
| User-generated content visible to others? | **No** |
| Targets children under 13? | **No** |

4. Click **"Save questionnaire"** → **"Calculate rating"**

Your rating will be: ✅ **Everyone (E)**

---

## 🔏 Step 6 — Privacy Policy (Required by Google)

Google will **reject your app** without a privacy policy URL.

### Easiest free option — Use Notion:

1. Go to **https://www.notion.so** → Create free account
2. Click **"+ New page"** → paste this content:

---

**Page title:**
```
Privacy Policy — Know Your Expenses
```

**Page content to paste:**
```
Last updated: March 2026

Know Your Expenses ("the App") is a personal finance tracking application.
This Privacy Policy explains how we handle your information.

INFORMATION WE COLLECT
• Google account name and email (via Google Sign-In)
• Profile photo (if you set one)
• Transaction data you manually enter (amounts, categories, dates, notes)
• Phone number (if provided during sign-up)

HOW WE USE YOUR INFORMATION
• To display your profile and personalize your experience
• To store and sync your transactions across devices
• We do NOT sell or share your personal data with any third parties

DATA STORAGE
Your data is stored securely using Google Firebase (Firestore and Authentication).
Google's privacy policy applies: https://policies.google.com/privacy

DATA DELETION
To delete your account and all associated data, contact us at:
[your email address]

CONTACT US
If you have questions about this Privacy Policy, contact:
[your email address]
```

---

3. Click **"Share"** (top right in Notion) → toggle **"Share to web"** → ON
4. Copy the link (looks like: `https://www.notion.so/Privacy-Policy-abc123...`)
5. Paste that link into the **"Privacy Policy URL"** field in Play Console

---

## 🎯 Step 7 — Target Audience & Ads

On left sidebar: **"Policy"** → **"App content"** → **"Target audience and content"**

| Field | Answer |
|---|---|
| Target age group | **18 and over** |
| Does your app appeal to children? | **No** |
| Does your app contain ads? | **No** |

---

## 📦 Step 8 — Upload Your AAB File

On left sidebar click **"Release"** → **"Testing"** → **"Internal testing"**

> Start with Internal Testing — it lets you test on your own device first before going live.

1. Click **"Create new release"**
2. Under **"App bundles"** click **"Upload"**
3. Find and upload:
```
build/app/outputs/bundle/release/app-release.aab
```
4. In **"What's new in this release?"** paste:

```
v1.0.0 — First Release 🎉

• Track daily expenses and income with ease
• Beautiful pie chart breakdown by category
• Monthly bar chart for financial insights
• Full transaction history
• Secure Google Sign-In with cloud sync
• Manage your personal profile and photo
```

5. Click **"Save"** → **"Review release"** → **"Start rollout to Internal testing"**

---

## 🧪 Step 9 — Test on Your Own Device First

1. On left sidebar: **"Testing"** → **"Internal testing"**
2. Click **"Testers"** tab
3. Click **"Create email list"**
4. Add your own Gmail address
5. Copy the **opt-in link**
6. Open that link on your Android phone → click **"Download it on Google Play"**
7. Install and test the app fully

---

## 🌍 Step 10 — Publish to Production (Go Live)

Once you've tested and everything works:

1. Left sidebar → **"Release"** → **"Production"**
2. Click **"Create new release"**
3. Click **"Add from library"** → select the AAB you already uploaded
4. Paste the same release notes
5. Click **"Save"** → **"Review release"**

Under **"Countries / regions"**:
- Click **"Add countries / regions"**
- Select **"India"** first → you can add more later

6. Click **"Start rollout to Production"**
7. Click **"Rollout"** to confirm

---

## ⏳ Step 11 — Wait for Review

After submitting to production:

```
Review time: 1 to 3 days (sometimes up to 7 for first-time apps)
You will get an email when approved or if changes are needed.
```

You can check status at any time:
- Left sidebar → **"Release"** → **"Production"** → Status will show:
  - 🟡 In review
  - ✅ Published
  - ❌ Rejected (with reason — fix and resubmit)

---

## ✅ Final Checklist Before Submitting to Production

```
□ app-release.aab uploaded successfully
□ App name filled: "Know Your Expenses"
□ Short description filled (under 80 chars)
□ Full description filled
□ App icon uploaded (512 × 512 PNG)
□ Feature graphic uploaded (1024 × 500 PNG)
□ At least 2 screenshots uploaded
□ Category set to: Finance
□ Content rating completed: Everyone (E)
□ Privacy policy URL added (Notion link)
□ Target audience set: 18+, No ads
□ Tested via Internal Testing on real device
□ Release notes written
□ Country set to India (minimum)
□ Clicked "Start rollout to Production"
```

All boxes checked → Your app is submitted! 🎉

---

## 🔄 How to Update the App Later

Every time you make changes and want to release an update:

1. Update version in `pubspec.yaml`:
```yaml
version: 1.0.1+2
#        ↑↑↑↑↑ ↑
#        name  build number (always increase by 1)
```

2. Build a new AAB:
```bash
flutter build appbundle --release
```

3. Go to Play Console → **Production** → **"Create new release"**
4. Upload the new `.aab` file
5. Write what changed in release notes
6. Submit → wait for review

---

## ❓ Common Upload Problems & Fixes

| Problem | Fix |
|---|---|
| "Version code already exists" | Increase the build number in `pubspec.yaml` (e.g. `1.0.0+1` → `1.0.0+2`) then rebuild |
| "APK not signed" | Make sure signingConfig is in `build.gradle.kts` and rebuild |
| "Package name already taken" | Change `applicationId` in `build.gradle.kts` to something unique like `com.aryan.knowyourexpenses` |
| "Privacy policy required" | Add your Notion link to the privacy policy field |
| "Content rating not completed" | Go to Policy → App content → fill the questionnaire |
| AAB upload shows error | Run `flutter clean` then `flutter build appbundle --release` again |
