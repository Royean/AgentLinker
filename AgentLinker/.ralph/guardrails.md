# AgentLinker Guardrails & Learnings

## Development Learnings

### Keychain Security
- Use `Security` framework for secure credential storage on macOS
- Always store tokens with `kSecAttrAccessibleWhenUnlocked` for security
- Handle `errSecDuplicateItem` when updating existing keychain entries
- Clear all credentials on logout using `SecItemDelete`

### SwiftUI Best Practices
- Use `@AppStorage` for simple preference persistence (wraps UserDefaults)
- Use `@FocusState` for form field focus management
- Use `NavigationSplitView` for macOS sidebar navigation
- Implement `preferredColorScheme` for appearance mode switching
- Use `sheet` for modal dialogs, `alert` for confirmations

### Network Layer
- Implement retry logic with exponential backoff for transient failures
- Use `URLSessionConfiguration.waitsForConnectivity = true` for offline support
- Check network status before making requests using `NWPathMonitor`
- Distinguish between retryable and non-retryable errors
- Always decode API responses with proper error handling

### Error Handling
- Create custom error types conforming to `LocalizedError` for user-friendly messages
- Use `APIError` enum to categorize different error scenarios
- Display user-friendly error messages in the UI
- Log detailed errors for debugging

### State Management
- Use `ObservableObject` with `@Published` for shared state
- Keep UI state separate from business logic
- Use `Task` and `await MainActor.run` for thread-safe UI updates
- Clean up timers and subscriptions in `deinit`

### Code Organization
- Separate concerns: Models, Views, Services
- Use protocol-oriented programming where appropriate
- Keep views focused on UI logic only
- Services handle business logic and API calls

## API Integration Notes

### Authentication Flow
```swift
// Production API call example:
let response: AuthResponse = try await apiClient.post(
    endpoint: "/auth/login",
    body: LoginRequest(email: email, password: password)
)
// Save token to keychain and set in APIClient
try keychainManager.saveToken(response.token)
apiClient.setAuthToken(response.token)
```

### Device Operations
```swift
// Load devices
let response: DevicesResponse = try await apiClient.get(endpoint: "/devices")

// Connect to device
let device: DeviceResponse = try await apiClient.post(
    endpoint: "/devices/\(deviceId)/connect"
)

// Update device
let request = DeviceRequest(name: newName, type: type, os: os, ipAddress: ip)
let updated: DeviceResponse = try await apiClient.put(
    endpoint: "/devices/\(deviceId)",
    body: request
)
```

## Build & Run

### Requirements
- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Commands
```bash
# Build
swift build

# Run tests
swift test

# Generate Xcode project (optional)
swift package generate-xcodeproj
```

## Known Limitations

1. **Mock Implementations**: Current auth and device operations use mock data. Replace with real API calls in production.

2. **Network Monitor**: Uses simplified mock implementation. Replace with `NWPathMonitor` from Network framework for production.

3. **Password Reset**: Currently shows success message without actual email sending. Implement with real email service.

4. **Delete Account**: Currently just logs out. Implement actual account deletion API call.

5. **Appearance Mode**: Settings change requires app restart for full effect on macOS.

## Security Considerations

1. Never log sensitive data (tokens, passwords)
2. Always use HTTPS for API calls
3. Validate all user inputs
4. Implement token refresh mechanism for long sessions
5. Clear keychain on logout and account deletion
6. Consider adding biometric authentication for sensitive operations

## Testing Recommendations

1. **Unit Tests**: Test KeychainManager, APIClient, and business logic
2. **UI Tests**: Test login flow, device management, and settings
3. **Integration Tests**: Test API integration with mock server
4. **Accessibility Tests**: Ensure VoiceOver compatibility
5. **Performance Tests**: Test with large device lists (100+ devices)

## Future Enhancements

- [ ] Add biometric authentication (Touch ID)
- [ ] Implement push notifications for device status changes
- [ ] Add device groups/categories
- [ ] Implement offline mode with local data sync
- [ ] Add export/import device configuration
- [ ] Support for multiple user accounts
- [ ] Add activity logs and audit trail
- [ ] Implement two-factor authentication

---

*Last updated: 2026-03-20*
*Version: 1.0.0*
