# Student Notes

Student Notes is a Flutter-based notes application that uses SQLite for local storage and Firebase Firestore for cloud synchronization.

## Features

* Create notes
* View notes
* Edit notes
* Delete notes
* Created and updated timestamps
* SQLite local persistence
* Firebase Firestore integration
* Local-to-cloud synchronization
* Cloud-to-local synchronization
* Loading states
* Error handling
* Empty state

## Tech Stack

* Flutter
* Dart
* SQLite
* sqflite
* Firebase Core
* Cloud Firestore

## Architecture

```text
                         Student Notes
                              |
                              v
                         Flutter UI
                              |
                 +------------+------------+
                 |                         |
                 v                         v
          DatabaseHelper            FirestoreService
                 |                         |
                 v                         v
              SQLite                  Firestore
                 |                         |
                 +------------+------------+
                              |
                              v
                          Note Model
```

## Project Structure

```text
student_notes/
|
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── note.dart
│   ├── services/
│   │   ├── database_helper.dart
│   │   └── firebase_service.dart
│   └── firebase_options.dart
|
├── test/
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

## Data Model

Each note contains:

```text
id
title
content
createdAt
updatedAt
```

## SQLite

SQLite is used for local persistence.

The local database contains a `notes` table:

```text
notes
├── id
├── title
├── content
├── createdAt
└── updatedAt
```

`DatabaseHelper` handles database operations:

* Create
* Read
* Update
* Delete

## Firebase Firestore

Firestore is used as the cloud database.

The cloud structure is:

```text
notes
├── document
│   ├── id
│   ├── title
│   ├── content
│   ├── createdAt
│   └── updatedAt
│
└── document
    ├── id
    ├── title
    ├── content
    ├── createdAt
    └── updatedAt
```

`FirestoreService` handles communication with Firebase Firestore.

## Synchronization

The application synchronizes data between SQLite and Firestore.

```text
SQLite
  |
  | Upload
  v
Firestore
  |
  | Download
  v
SQLite
  |
  v
Flutter UI
```

The `updatedAt` field is used to determine which version of a note is newer.

The current synchronization strategy uses a latest-update-wins approach.

## Firebase Configuration

Firebase configuration is generated using FlutterFire.

The project uses:

```text
lib/firebase_options.dart
```

To configure Firebase:

```bash
firebase login
```

```bash
flutterfire configure
```

## Requirements

* Flutter SDK
* Dart SDK
* Xcode for iOS development
* Android Studio and Android SDK for Android development
* Firebase project

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/student_notes.git
```

Navigate to the project:

```bash
cd student_notes
```

Install dependencies:

```bash
flutter pub get
```

Configure Firebase:

```bash
flutterfire configure
```

Run the application:

```bash
flutter run
```

## Development Commands

Check Flutter installation:

```bash
flutter doctor
```

Check connected devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

Install project dependencies:

```bash
flutter pub get
```

Clean generated build files:

```bash
flutter clean
```

## Scope

The current version focuses on:

* Flutter UI
* Local SQLite storage
* CRUD operations
* Firebase Firestore
* Data synchronization
* Basic loading and error handling

Authentication and advanced conflict-resolution mechanisms are not included.

## Future Improvements

* Firebase Authentication
* User-specific notes
* Search
* Categories and tags
* Pinning notes
* Dark mode
* Improved offline synchronization
* Advanced conflict resolution
* Automated testing
* CI/CD
