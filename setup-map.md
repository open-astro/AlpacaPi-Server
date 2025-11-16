# AlpacaPi Setup Wizard – Flow Map

This document defines the **state machine** and **UI flow** for the Bubble Tea / Bubble Gum–based setup wizard.

The goal:  
- Let users **select only the drivers they need** (not “install everything”).  
- Make it easy to **add/remove drivers later**.  
- Keep the TUI **clean, predictable, and modern**.

> ⚠️ Implementations MUST follow these states and transitions. Do not invent new states or change transitions without updating this file.

---

## 1. Data Model

The core `Model` used by Bubble Tea should at minimum track:

- `currentState` – one of the state IDs defined below.
- `deviceCategories []DeviceCategory`
- `manufacturersByCategory map[string][]Manufacturer`
- `modelsByManufacturer map[string][]DeviceModel`

- `selectedCategory *DeviceCategory`
- `selectedManufacturer *Manufacturer`
- `selectedModel *DeviceModel`

- `pendingDrivers []DriverSelection`  
  (what will be installed or removed during this run)

- `installedDrivers []InstalledDriver`  
  (read from system / config, for “Review & Manage” mode)

- `mode WizardMode` – one of:
  - `ModeInstall` – add new drivers
  - `ModeRemove` – remove existing drivers
  - `ModeReview` – just show what’s installed

- `err error` – last error to display in footer/notification
- `progress float64` – 0–1 for install/remove progress
- `logLines []string` – output log for progress screen

Navigation helpers (indexes for lists):

- `categoryIndex int`
- `manufacturerIndex int`
- `modelIndex int`
- `pendingIndex int`
- `installedIndex int`

---

## 2. Global UI Rules

- Use Bubble Tea + Bubble Gum primitives (lists, status bars, spinners, progress).
- Layout:
  - Title centered at top.
  - Main content in the middle.
  - Footer line at bottom with key hints.
- Max width ≈ 80 chars; avoid wrapping nightmares.
- Consistent key bindings across states:
  - `↑/↓` or `k/j` – move selection
  - `Enter` – confirm / continue
  - `b` – go back (if applicable)
  - `q` – quit wizard (with confirmation if needed)
  - `Tab` – switch focus when there are multiple panes (e.g., logs vs buttons)

---

## 3. State Machine Overview

States:

1. `stateWelcome`
2. `stateModeSelect`
3. `stateDeviceCategorySelect`
4. `stateManufacturerSelect`
5. `stateModelSelect`
6. `statePendingReview`
7. `stateInstalledReview` (manage/remove)
8. `stateInstallProgress`
9. `stateResult`

---

## 4. States in Detail

### 4.1 `stateWelcome`

**Purpose**  
Introduce the setup wizard and explain that only the selected, relevant drivers will be installed.

**Input Requirements**  
- None.

**UI Content**
- Centered title: `AlpacaPi Setup Wizard`
- Short description:
  - Explains:
    - “Install only the drivers you need.”
    - “You can also review and remove drivers later.”
- Options (simple menu):
  - `Start setup`
  - `Review installed drivers`
  - `Quit`

**User Actions**
- `↑/↓` or `j/k` – move between options
- `Enter`:
  - If `Start setup` → `stateModeSelect`
  - If `Review installed drivers` → `stateInstalledReview` (ModeReview)
  - If `Quit` → exit program
- `q` – exit immediately

**Transitions**
- `stateWelcome` → `stateModeSelect`
- `stateWelcome` → `stateInstalledReview`
- `stateWelcome` → exit

---

### 4.2 `stateModeSelect`

**Purpose**  
Let user pick whether they are installing new drivers or managing/removing existing ones.

**Input Requirements**
- Installed driver list may be loaded here if not already (optional lazy load).

**UI Content**
- Title: `Choose Setup Mode`
- Choices:
  - `Install new drivers`
  - `Remove existing drivers`
  - `Back to welcome`

**User Actions**
- `↑/↓`, `j/k` – move selection
- `Enter`:
  - `Install new drivers`:
    - `mode = ModeInstall`
    - `stateDeviceCategorySelect`
  - `Remove existing drivers`:
    - `mode = ModeRemove`
    - `stateInstalledReview`
  - `Back to welcome` → `stateWelcome`
- `b` → `stateWelcome`
- `q` → exit

**Transitions**
- `stateModeSelect` → `stateDeviceCategorySelect` (install)
- `stateModeSelect` → `stateInstalledReview` (remove)
- `stateModeSelect` → `stateWelcome`

---

### 4.3 `stateDeviceCategorySelect`

**Purpose**  
User chooses the **type of device**: camera, focuser, mount, etc.

**Input Requirements**
- `deviceCategories` populated with something like:
  - Cameras
  - Focusers
  - Filter Wheels
  - Mounts
  - Rotators
  - Domes
  - Weather
  - GPIO / Aux

**UI Content**
- Title: `Select Device Category`
- Body: Bubble Gum list of categories.
- Footer: `↑/↓ Select • Enter Next • b Back • q Quit`

**User Actions**
- `↑/↓`, `j/k` – move selection
- `Enter`:
  - Set `selectedCategory`
  - Load manufacturers for this category if needed
  - `stateManufacturerSelect`
- `b` → `stateModeSelect`
- `q` → exit

**Transitions**
- `stateDeviceCategorySelect` → `stateManufacturerSelect`
- `stateDeviceCategorySelect` → `stateModeSelect` (back)

---

### 4.4 `stateManufacturerSelect`

**Purpose**  
Choose the **manufacturer** for the selected category.

**Input Requirements**
- `selectedCategory != nil`
- `manufacturersByCategory[selectedCategory.ID]` loaded.

**UI Content**
- Title: `Select Manufacturer – {CategoryName}`
- List of manufacturers (e.g., ZWO, QHY, iOptron, Pegasus Astro, etc.).
- Footer: `↑/↓ Select • Enter Next • b Back • q Quit`

**User Actions**
- `↑/↓`, `j/k` – move selection
- `Enter`:
  - Set `selectedManufacturer`
  - Load `modelsByManufacturer` if needed
  - Go to `stateModelSelect`
- `b`:
  - Clear `selectedManufacturer`
  - Go back to `stateDeviceCategorySelect`
- `q` → exit

**Transitions**
- `stateManufacturerSelect` → `stateModelSelect`
- `stateManufacturerSelect` → `stateDeviceCategorySelect`

---

### 4.5 `stateModelSelect`

**Purpose**  
Select the **specific device / driver** model to install or manage.

**Input Requirements**
- `selectedCategory`
- `selectedManufacturer`
- `modelsByManufacturer[selectedManufacturer.ID]` loaded.

**UI Content**
- Title: `Select Device – {ManufacturerName} {CategoryName}`
- Main list of models/devices for this manufacturer.
- Hint that multiple selections can be added to a queue (if supported).
- Footer:
  - `↑/↓ Select • Enter Add • b Back • p Pending queue • q Quit`

**User Actions**
- `↑/↓`, `j/k` – move selection
- `Enter`:
  - Create a `DriverSelection` record:
    - Category
    - Manufacturer
    - Model
    - Action = `Install` (in ModeInstall) or `Remove` (if in some future extension)
  - Append to `pendingDrivers`
  - Optionally show a small Toast/notification: “Added to pending install.”
  - Stay in `stateModelSelect` so user can add more for same category/manufacturer.
- `p`:
  - Go to `statePendingReview` (only if `len(pendingDrivers) > 0`)
- `b`:
  - Clear `selectedModel`
  - Go back to `stateManufacturerSelect`
- `q` → exit

**Transitions**
- `stateModelSelect` → `stateModelSelect` (after each add)
- `stateModelSelect` → `statePendingReview`
- `stateModelSelect` → `stateManufacturerSelect`

---

### 4.6 `statePendingReview`

**Purpose**  
Show a summary of what will be installed/changed and allow the user to confirm or adjust.

**Input Requirements**
- `pendingDrivers` (could be empty, but usually ≥ 1).

**UI Content**
- Title: `Pending Changes`
- Main list:
  - Each entry: `{Action} – {Category} / {Manufacturer} / {Model}`
- Right or bottom pane: short description / notes for selected item.
- Footer:
  - `↑/↓ Select • d Delete entry • Enter Install • b Back • q Quit`

**User Actions**
- `↑/↓`, `j/k` – move selection over pending items.
- `d`:
  - Remove selected `DriverSelection` from `pendingDrivers`.
  - Adjust `pendingIndex` safely.
- `Enter`:
  - If `len(pendingDrivers) == 0`: show error “No drivers selected.”
  - Otherwise:
    - Transition to `stateInstallProgress`.
- `b`:
  - Return to `stateModelSelect` (or last selection screen; keep it simple for now: go back to `stateDeviceCategorySelect` if you prefer).
- `q` → exit.

**Transitions**
- `statePendingReview` → `stateInstallProgress`
- `statePendingReview` → `stateModelSelect` (or `stateDeviceCategorySelect` based on design)
- `statePendingReview` → `statePendingReview` (when deleting items)

---

### 4.7 `stateInstalledReview`

**Purpose**  
List **already installed drivers** and allow user to:
- Just review them (ModeReview)
- Mark some for removal (ModeRemove)

**Input Requirements**
- `installedDrivers` loaded from system config.

**UI Content**
- Title: `Installed Drivers`
- List of installed drivers:
  - `{Category} / {Manufacturer} / {Model} – {Version}`
- Footer:
  - For ModeReview:
    - `↑/↓ Select • b Back • q Quit`
  - For ModeRemove:
    - `↑/↓ Select • r Remove/Queue • p Pending removals • b Back • q Quit`

**User Actions**
- `↑/↓`, `j/k` – move selection
- If `mode == ModeReview`:
  - `b` → back to:
    - `stateWelcome` if from welcome
    - `stateModeSelect` if from there
- If `mode == ModeRemove`:
  - `r`:
    - Add to `pendingDrivers` with Action = `Remove`
    - Optional toast: “Queued for removal.”
  - `p`:
    - `statePendingReview`
- `q` → exit

**Transitions**
- `stateInstalledReview` → `statePendingReview` (when removals queued)
- `stateInstalledReview` → `stateModeSelect` or `stateWelcome` (back)
- `stateInstalledReview` → `stateInstalledReview` (multiple removals queued)

---

### 4.8 `stateInstallProgress`

**Purpose**  
Actually run the install/remove steps and show real-time progress/log output.

**Input Requirements**
- `pendingDrivers` not empty.
- Backend function(s) to perform install/remove must be invoked from this state’s update loop.

**UI Content**
- Title: `Applying Changes`
- Content:
  - Progress bar (0–100%)
  - Spinner while work is ongoing
  - Log area showing last N lines of output.
- Footer:
  - While running: `Installing... • Press q to cancel (if supported)`
  - After completion: `Enter Finish • l View full log • q Quit`

**User Actions**
- While running:
  - `q`:
    - Optional: attempt to cancel / set flag. If not supported, ignore or show “Cancelling not supported.”
- When done:
  - `Enter` → `stateResult`
  - `l` → maybe toggle a full-screen log view (optional; if not implemented, just ignore)
  - `q` → exit

**Transitions**
- `stateInstallProgress` → `stateResult` (on completion)
- `stateInstallProgress` → exit (if hard abort)

---

### 4.9 `stateResult`

**Purpose**  
Show final summary of what happened: success, partial success, failures.

**Input Requirements**
- Status of each `DriverSelection` (success/fail + message).

**UI Content**
- Title: `Setup Complete`
- Sections:
  - `Success:` list of drivers/changes that succeeded.
  - `Failed:` list of drivers/changes that failed with a short reason.
- Footer:
  - `Enter Back to welcome • q Quit`

**User Actions**
- `Enter`:
  - Clear `pendingDrivers`
  - Possibly refresh `installedDrivers`
  - `stateWelcome`
- `q` → exit

**Transitions**
- `stateResult` → `stateWelcome`
- `stateResult` → exit

---

## 5. State Transition Summary

- `stateWelcome`
  - → `stateModeSelect`
  - → `stateInstalledReview`
  - → exit

- `stateModeSelect`
  - → `stateDeviceCategorySelect` (Install)
  - → `stateInstalledReview` (Remove)
  - → `stateWelcome`

- `stateDeviceCategorySelect`
  - → `stateManufacturerSelect`
  - → `stateModeSelect`

- `stateManufacturerSelect`
  - → `stateModelSelect`
  - → `stateDeviceCategorySelect`

- `stateModelSelect`
  - → `stateModelSelect` (add more)
  - → `statePendingReview`
  - → `stateManufacturerSelect`

- `statePendingReview`
  - → `stateInstallProgress`
  - → `stateModelSelect` (or `stateDeviceCategorySelect`, depending on last context)
  - → `statePendingReview` (edit list)

- `stateInstalledReview`
  - → `statePendingReview` (when ModeRemove and items queued)
  - → `stateModeSelect` or `stateWelcome` (back)

- `stateInstallProgress`
  - → `stateResult`
  - → exit (on abort)

- `stateResult`
  - → `stateWelcome`
  - → exit

---

## 6. Implementation Notes for Cursor / AI

When modifying the wizard code:

- **Do not add new states** without updating this document.
- **Do not change transitions** described here.
- Keep logic split into:
  - `model.go` – data model + state enums
  - `update.go` – `Update` function with state-based branches
  - `view.go` – `View` with one function per state
- All user navigation must respect the key bindings defined above.