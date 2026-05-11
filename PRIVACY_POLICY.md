# Privacy Policy — Know Your Expenses

**Effective date:** 2 May 2026  
**App name:** Know Your Expenses  
**Developer:** Aryan Sharma

This Privacy Policy describes how **Know Your Expenses** (“we”, “us”, “the App”) collects, uses, stores, and shares information when you use our mobile application available on Google Play.

By using the App, you agree to this Privacy Policy. If you do not agree, please do not use the App.

---

## 1. Who we are

The App is operated by **Aryan Sharma** as an individual developer.  
**Contact email:** aryansharma31658@gmail.com

For privacy-related requests (including data access or deletion), contact us at the email above.

---

## 2. Information we collect

We collect and process information only as needed to provide the App’s features.

### 2.1 Account and authentication (Firebase & Google)

When you create an account or sign in, we use **Google Firebase Authentication** and, optionally, **Google Sign-In**:

- Email address  
- Display name (if provided by Google or during sign-up)  
- Unique user identifier (UID) assigned by Firebase  
- Profile photo URL (if you sign in with Google or upload a profile image)  
- Phone number (if you provide it during email/password sign-up)

We do **not** receive your Google account password.

### 2.2 Profile and user document (Cloud Firestore)

We store a user profile document in **Google Cloud Firestore**, including fields such as:

- Name  
- Email  
- Phone number (if provided)  
- Profile photo URL (when you set or update a profile picture)  
- Account creation timestamp (where applicable)

### 2.3 Financial data you enter (Cloud Firestore)

To provide expense tracking, we store data **you actively enter**, including:

- **Transactions:** amount, description, category, date, expense/income type, and related display metadata (e.g. icon and colour preferences for categories)  
- **Categories:** custom category names and appearance preferences you create

This data is stored under your user account in Firestore (`users/{yourUserId}/...`) and is used only to show your data inside the App.

### 2.4 Photos (device gallery & Cloudinary)

If you choose to update your profile picture, the App may:

- Access **photos or images you select** via the device’s image picker (with your permission where the operating system requires it)  
- Upload the selected image to **Cloudinary** (our image hosting provider) and store the resulting **image URL** in Firestore so your profile can display the picture

We do not use your gallery for any purpose other than the image you choose to upload for your profile.

### 2.5 Device sensors (motion)

Certain screens may use **device motion sensors** (e.g. accelerometer) for **visual or interactive effects only** (such as tilt or motion-based UI). We do not use this data to identify you, build a profile of you for advertising, or sell it to third parties.

### 2.6 Fonts (Google Fonts)

The App uses the **google_fonts** package, which may load font files from **Google** servers when those fonts are used in the UI. That process may involve standard technical data such as IP address as handled by Google’s infrastructure. See: [Google Fonts privacy FAQ](https://developers.google.com/fonts/faq/privacy).

### 2.7 Analytics and diagnostics (Firebase)

The Android build of the App includes **Google Firebase** components that may collect **limited usage and diagnostic information** (for example, app opens, device type, and crash-related signals) as described in [Google’s Firebase Privacy documentation](https://firebase.google.com/support/privacy). We do not use this to show you ads inside the App.

### 2.8 Information we do not collect

We do **not**:

- Sell your personal data  
- Run third-party advertising networks inside the App  
- Track your precise GPS location for advertising  
- Read your SMS, contacts, or call logs  
- Knowingly collect data from children under 13 (the App is not directed at children)

---

## 3. How we use your information

We use the information above to:

- Create and secure your account  
- Sync your transactions, categories, and profile across devices  
- Display analytics, charts, and summaries **only for you** inside the App  
- Host and display your profile photo (via Cloudinary URL stored in Firestore)

We do **not** use your financial entries for advertising profiling.

---

## 4. Legal bases (where applicable)

If you are in a region that requires a “legal basis” for processing (for example, the EEA or UK), we rely on:

- **Performance of a contract** — to provide the App you asked for  
- **Legitimate interests** — to secure the service, fix bugs, and improve stability  
- **Consent** — where the operating system or law requires it (e.g. camera/gallery access for profile photos)

---

## 5. Service providers (third parties)

Your data is processed using services operated by third parties. Their own terms and privacy policies apply in addition to ours:

| Service | Purpose | Privacy information |
|--------|---------|----------------------|
| **Google Firebase** (Authentication, Firestore, Analytics on Android) | Account login, database storage, limited usage/diagnostics | [Google Privacy Policy](https://policies.google.com/privacy), [Firebase / Google Cloud](https://firebase.google.com/support/privacy) |
| **Google Sign-In** | Optional sign-in with Google | [Google Privacy Policy](https://policies.google.com/privacy) |
| **Cloudinary** | Hosting profile images | [Cloudinary Privacy Policy](https://cloudinary.com/privacy) |

We choose providers that are commonly used for app infrastructure. We do not authorise them to use your personal data for their own marketing unrelated to providing their service to us.

---

## 6. Data retention and deletion

- We keep your data **as long as your account exists** and you use the App.  
- If you delete your account or ask us to delete your data, we will delete or anonymise your personal information **where technically feasible and unless we must retain certain data for legal reasons**.

**How to request deletion:** Email **aryansharma31658@gmail.com** from the address associated with your account, with the subject “Data deletion — Know Your Expenses”. We may ask you to verify ownership of the account.

---

## 7. Security

We use industry-standard practices through Firebase and secure connections (HTTPS) where applicable. No method of transmission or storage is 100% secure; we strive to protect your information but cannot guarantee absolute security.

---

## 8. International transfers

Firebase, Google, and Cloudinary may process and store data on servers located **outside your country** (including the United States and other regions). By using the App, you understand that your information may be transferred to countries with different data protection laws. Where required, we rely on appropriate safeguards described by our providers.

---

## 9. Your rights

Depending on where you live, you may have rights to:

- Access the personal data we hold about you  
- Correct inaccurate data  
- Request deletion  
- Object to or restrict certain processing  
- Lodge a complaint with a data protection authority

To exercise these rights, contact **aryansharma31658@gmail.com**. We will respond within a reasonable time as required by applicable law.

---

## 10. Children’s privacy

The App is **not intended for children under 13** (or the minimum age required in your jurisdiction). We do not knowingly collect personal information from children. If you believe a child has provided us with personal data, contact us and we will take steps to delete it.

---

## 11. Changes to this policy

We may update this Privacy Policy from time to time. We will post the new version in the same location (e.g. your GitHub repository or linked URL) and update the “Effective date” at the top. Continued use of the App after changes means you accept the updated policy.

---

## 12. Contact

**Know Your Expenses** — **Aryan Sharma**  
**Email:** aryansharma31658@gmail.com

---

*This policy reflects the App’s use of Firebase Authentication, Cloud Firestore, Firebase-related analytics/diagnostics on Android, Google Sign-In, Cloudinary, image picker, device motion sensors (for UI only), and Google Fonts as of the effective date above.*
