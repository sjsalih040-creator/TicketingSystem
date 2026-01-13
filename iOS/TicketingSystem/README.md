# iOS Ticketing System

This directory contains the Swift source files for the iOS version of the Ticketing System.

## Getting Started

Since this code was generated on Windows, you will need to perform a few steps on a Mac to run it:

1.  **Transfer Files**: Copy the entire `iOS/TicketingSystem` folder to a Mac.
2.  **Create Xcode Project**:
    *   Open Xcode.
    *   Create a new "App" project.
    *   Name it "TicketingSystem".
    *   Ensure "Interface" is set to "SwiftUI".
3.  **Import Files**:
    *   Delete the default `ContentView.swift` and `TicketingSystemApp.swift` created by Xcode.
    *   Drag and drop the `Models`, `Services`, `ViewModels`, and `Views` folders into the Xcode project navigator.
    *   Drag and drop `TicketingSystemApp.swift` into the project.
4.  **Configuration**:
    *   Open `Services/NetworkManager.swift`.
    *   Update the `baseUrl` property if you are running the backend locally or on a different server.
5.  **Run**: Select a simulator and press Run (Cmd+R).

## Architecture

The app follows the MVVM (Model-View-ViewModel) pattern:

*   **Models**: Data structures (`Ticket`, `UserSession`) that mirror the API responses.
*   **Services**: `NetworkManager` handles all API calls using `URLSession`.
*   **ViewModels**: `LoginViewModel` and `TicketListViewModel` manage state and business logic.
*   **Views**: SwiftUI views (`LoginView`, `TicketListView`) for the user interface.
