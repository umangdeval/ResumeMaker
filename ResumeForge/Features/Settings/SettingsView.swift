import SwiftUI

struct SettingsView: View {
    let pythonStatus: PythonEnvironmentStatus

    var body: some View {
        EditableProviderSettingsView(pythonStatus: pythonStatus)
    }
}

#Preview {
    SettingsView(pythonStatus: .ready)
}
