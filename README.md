# Quotation Master 📑

A modern, full-featured **Quotation and Billing Management Application** built with **Flutter**, **Firebase**, and **Google Cloud APIs**. Designed for businesses, contractors, and fabricators to seamlessly generate itemized quotations, calculate area- and unit-based pricing, track inventory, manage employees, and export professional PDFs and Excel spreadsheets.

---

## 🌟 Key Features

### 📄 Quotation & Bill Management
- **Flexible Measurement Calculations**: Supports area-based formulas ($Width \times Height \times Rate \times Quantity$) across multiple units (`ft`, `cm`, `mm`, `inch`, `meter`) as well as unit-based items (`pcs`, `kg`, `liter`, etc.).
- **Rich Specifications**: Attach specifications, profile systems, glass types, finishes, accessories, and custom notes per item.
- **Visual Documentation**: Attach and preview images directly on quotation items (with automatic image compression to prevent memory overhead).
- **Template Customization**: Reusable quotation templates with customizable company headers, terms, and conditions.

### 🖨️ PDF & Excel Exporting
- **Professional PDF Generation**: Generate branded, printable PDF quotes and final invoices with company branding, item breakdown, and attached images using `pdf` and `printing`.
- **Excel Spreadsheet Export**: Export full quotation spreadsheets with formulas and clean tabular formatting using `syncfusion_flutter_xlsio`.
- **Instant Sharing**: Share generated documents directly via WhatsApp, email, or other apps using `share_plus`.

### ☁️ Cloud & Synchronization
- **Firebase Backend**: Real-time data storage with Cloud Firestore and user authentication via Firebase Auth and Google Sign-In.
- **Google Drive Backup**: One-click Google Drive synchronization for secure cloud backups of quotations and project media.
- **Local Notifications**: Automated reminders and status alerts powered by `flutter_local_notifications`.

### 📦 Inventory & Materials
- **Global Materials Directory**: Maintain a master list of raw materials, specs, hardware, and accessories.
- **Inventory Tracking**: Monitor stock, unit rates, and pricing changes in real time.

### 👥 Team & Employee Management
- **Employee Directory**: Track employee records, roles, and profiles.
- **User Permissions**: Manage team access with dedicated user detail screens and authentication controls.

### 📊 Budget & Financial Overview
- Dedicated budget screen to analyze project costs, track payments, and review profit margins.

---

## 🛠️ Tech Stack & Dependencies

| Category | Technology / Package |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev) (SDK `^3.8.1`) / Dart |
| **State Management** | [Provider](https://pub.dev/packages/provider) |
| **Backend & Auth** | [Firebase Core](https://pub.dev/packages/firebase_core), [Cloud Firestore](https://pub.dev/packages/cloud_firestore), [Firebase Auth](https://pub.dev/packages/firebase_auth), [Google Sign In](https://pub.dev/packages/google_sign_in) |
| **Cloud Services** | [Google APIs](https://pub.dev/packages/googleapis) (Drive API integration) |
| **Document Generation** | [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing), [syncfusion_flutter_xlsio](https://pub.dev/packages/syncfusion_flutter_xlsio) |
| **UI & Styling** | [Google Fonts (Poppins)](https://pub.dev/packages/google_fonts), [Animate Do](https://pub.dev/packages/animate_do) |
| **Media & File Handling**| [image_picker](https://pub.dev/packages/image_picker), [file_picker](https://pub.dev/packages/file_picker), [image](https://pub.dev/packages/image), [path_provider](https://pub.dev/packages/path_provider) |
| **Utilities & Notifications**| [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications), [share_plus](https://pub.dev/packages/share_plus), [intl](https://pub.dev/packages/intl), [uuid](https://pub.dev/packages/uuid) |

---

## 📁 Project Structure

```text
lib/
├── controllers/          # Business logic and state management
│   ├── auth_controller.dart
│   ├── inventory_controller.dart
│   └── quotation_controller.dart
├── models/               # Data structures and entities
│   ├── company_settings.dart
│   ├── employee_model.dart
│   ├── material_model.dart
│   └── quotation_model.dart
├── services/             # Background services (Notifications, etc.)
│   └── notification_service.dart
├── utils/                # Helper utilities (PDF, Excel, Drive, Media)
│   ├── drive_helper.dart
│   ├── excel_helper.dart
│   ├── file_helper.dart
│   ├── media_sync_helper.dart
│   └── pdf_helper.dart
├── views/                # Presentation UI layer
│   ├── auth/             # Login and authentication screens
│   ├── dashboard/        # Main navigation and overview
│   ├── employee/         # Employee directory & details
│   ├── inventory/        # Stock and inventory views
│   ├── material/         # Global material catalogue
│   ├── profile/          # User profile screen
│   ├── quotation/        # Quotation editor, list & budget screens
│   ├── settings/         # Company branding, templates & user management
│   └── splash/           # Splash screen
├── firebase_options.dart # Generated Firebase configuration
└── main.dart             # App entry point & dependency injection
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.8.1` or newer)
- [Dart SDK](https://dart.dev/get-dart)
- A configured [Firebase Project](https://console.firebase.google.com/)
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd quotation
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**:
   Ensure `lib/firebase_options.dart` and native configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) are linked with your Firebase project:
   ```bash
   flutterfire configure
   ```

4. **Run the Application**:
   ```bash
   flutter run
   ```

---

## ⚙️ Configuration & Permissions

- **Android**: Ensure camera, storage/read permissions, and notification permissions are configured in `android/app/src/main/AndroidManifest.xml`.
- **Google Drive API**: Ensure the Google Drive API is enabled in your Google Cloud Console for the OAuth client linked with your Google Sign-In SHA-1 fingerprint.

---

## 📄 License

This project is proprietary and confidential. All rights reserved.
