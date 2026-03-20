//
//  LoginView.swift
//  AgentLinker
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var name = ""
    @State private var showingForgotPasswordSheet = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, name
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "network")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("AgentLinker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Connect and manage your devices")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
                
                // Form
                VStack(spacing: 16) {
                    if isRegistering {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .email
                            }
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit {
                            handleSubmit()
                        }
                    
                    if let error = authManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                    }
                    
                    if !isRegistering {
                        Button(action: {
                            showingForgotPasswordSheet = true
                        }) {
                            Text("Forgot Password?")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                    }
                    
                    Button(action: handleSubmit) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                            Text(isRegistering ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(authManager.isLoading || !isFormValid)
                    .keyboardShortcut(.defaultAction)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Button(action: {
                        withAnimation {
                            isRegistering.toggle()
                            clearError()
                        }
                    }) {
                        Text(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.windowBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .padding()
                .frame(maxWidth: 400)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .sheet(isPresented: $showingForgotPasswordSheet) {
            ForgotPasswordView()
                .environmentObject(authManager)
        }
    }
    
    private var isFormValid: Bool {
        if isRegistering {
            return !email.isEmpty && !password.isEmpty && !name.isEmpty && isValidEmail(email)
        } else {
            return !email.isEmpty && !password.isEmpty && isValidEmail(email)
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func handleSubmit() {
        guard isValidEmail(email) else {
            authManager.errorMessage = "Please enter a valid email address"
            return
        }
        
        Task {
            if isRegistering {
                let success = await authManager.register(email: email, password: password, name: name)
                if success {
                    focusedField = nil
                }
            } else {
                let success = await authManager.login(email: email, password: password)
                if success {
                    focusedField = nil
                }
            }
        }
    }
    
    private func clearError() {
        authManager.errorMessage = nil
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var showingSuccess = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Reset Password")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter your email address and we'll send you instructions to reset your password.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button(action: handleResetPassword) {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Text("Send Instructions")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authManager.isLoading || email.isEmpty)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 400)
        .alert("Email Sent", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("If an account exists with this email, you'll receive password reset instructions.")
        }
    }
    
    private func handleResetPassword() {
        Task {
            // Mock password reset - in production, call API
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            showingSuccess = true
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
