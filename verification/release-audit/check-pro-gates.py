"""Check that every user-facing entry point and AppState enforce launch Pro rules."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
app_state = (root / "Catch/Services/AppState.swift").read_text()
content = (root / "Catch/Views/ContentView.swift").read_text()
settings = (root / "Catch/Views/SettingsView.swift").read_text()
onboarding = (root / "Catch/Views/OnboardingView.swift").read_text()
editor = (root / "Catch/Views/AddLocationView.swift").read_text()

checks = {
    "free saved-place limit is one": "let freeSavedPlaceLimit = 1" in app_state,
    "AppState rejects excess saved places": "guard isProMember || savedLocations.count < freeSavedPlaceLimit" in app_state,
    "home Add checks the free limit": "appState.savedLocations.count < appState.freeSavedPlaceLimit" in content,
    "header Add uses the gated path": 'headerButton("plus", label: "Add saved stop") { openAddSavedPlace() }' in content,
    "editor save checks the free limit": "appState.savedLocations.count >= appState.freeSavedPlaceLimit" in editor,
    "notification state rejects free enable": 'presentProPaywall(context: "Notifications")' in app_state,
    "permission result cannot enable notifications for free": "let enabled = granted && isProMember" in app_state,
    "Settings labels notifications as Pro": 'label: "Notifications", isPro: true' in settings,
    "Settings blocks notification toggle for free": 'presentSettingsProPaywall(context: "Notifications")' in settings,
    "onboarding blocks notification permission for free": 'appState.presentProPaywall(context: "Notifications")' in onboarding,
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(("PASS: " if passed else "FAIL: ") + name)
if failed:
    raise SystemExit("Missing gates: " + ", ".join(failed))
