# 🏥 Medical Trial Consent Contract

> A blockchain-based digital consent management system for medical research trials on the Stacks blockchain

## 📋 Overview

The Medical Trial Consent Contract enables secure, transparent, and immutable digital consent management for medical research trials. Participants can digitally sign consent forms, withdraw consent at any time, and trial organizers can manage trials with full transparency and compliance.

## ✨ Features

### 🔬 For Trial Organizers
- **Create Medical Trials** - Set up trials with detailed parameters
- **Participant Management** - Track consent status and participant data
- **Trial Controls** - Deactivate or extend trials as needed
- **Age Verification** - Ensure participants meet minimum age requirements

### 👥 For Participants  
- **Digital Consent** - Sign consent forms with blockchain verification
- **Profile Management** - Create and maintain participant profiles
- **Consent Withdrawal** - Withdraw consent at any time with timestamp proof
- **Trial History** - Track participation across multiple trials

### 🔒 Security & Compliance
- **Immutable Records** - All consent actions permanently recorded
- **Emergency Contacts** - Required emergency contact information
- **Medical History** - Secure medical history storage
- **Age Validation** - Automatic age verification against trial requirements

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet for interaction

### Installation
```bash
git clone <repository-url>
cd Medical-Trial-Consent-Contract
clarinet check
```

### Testing
```bash
npm install
npm test
```

## 📖 Usage Guide

### 🏥 Creating a Trial (Organizers)

```clarity
(contract-call? .Medical-Trial-Consent-Contract create-trial
    "COVID-19 Vaccine Trial"
    "Phase 3 clinical trial for new COVID-19 vaccine"
    u1000  ;; duration in blocks
    u100   ;; max participants
    u18    ;; minimum age
    u500   ;; compensation amount
)
```

### 👤 Creating Participant Profile

```clarity
(contract-call? .Medical-Trial-Consent-Contract create-participant-profile
    "John Doe"
    u19850615  ;; date of birth
    "john.doe@email.com, +1234567890"
)
```

### ✍️ Giving Consent

```clarity
(contract-call? .Medical-Trial-Consent-Contract give-consent
    u1  ;; trial-id
    u35 ;; participant age
    "Jane Doe - Sister +1987654321"  ;; emergency contact
    "No known allergies, healthy"    ;; medical history
)
```

### ❌ Withdrawing Consent

```clarity
(contract-call? .Medical-Trial-Consent-Contract withdraw-consent
    u1  ;; trial-id
)
```

## 🔍 Query Functions

### Get Trial Information
```clarity
(contract-call? .Medical-Trial-Consent-Contract get-trial u1)
```

### Check Consent Status
```clarity
(contract-call? .Medical-Trial-Consent-Contract is-participant-consented 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; participant address
    u1  ;; trial-id
)
```

### Get Trial Status
```clarity
(contract-call? .Medical-Trial-Consent-Contract get-trial-status u1)
```

### Validate Eligibility
```clarity
(contract-call? .Medical-Trial-Consent-Contract validate-consent-eligibility
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; participant address
    u1  ;; trial-id
)
```

## 📊 Data Structure

### Trial Data
- **Organizer**: Principal who created the trial
- **Title & Description**: Trial information
- **Duration**: Start and end blocks
- **Participants**: Current/max participant counts
- **Requirements**: Minimum age and compensation
- **Status**: Active/inactive state

### Consent Data
- **Participant**: Principal who gave consent
- **Trial ID**: Associated trial
- **Timestamps**: Consent and withdrawal times
- **Personal Info**: Age, emergency contact, medical history
- **Status**: Consent given/withdrawn state

### Participant Profile
- **Personal Details**: Name, date of birth, contact info
- **Trial History**: Total trials participated in
- **Creation Date**: When profile was created

## ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `ERR-NOT-AUTHORIZED` | Unauthorized action |
| u101 | `ERR-TRIAL-NOT-FOUND` | Trial doesn't exist |
| u102 | `ERR-TRIAL-INACTIVE` | Trial is not active |
| u103 | `ERR-TRIAL-FULL` | Trial has reached max participants |
| u104 | `ERR-ALREADY-CONSENTED` | Participant already consented |
| u105 | `ERR-NO-CONSENT-FOUND` | No consent record found |
| u106 | `ERR-ALREADY-WITHDRAWN` | Consent already withdrawn |
| u107 | `ERR-TRIAL-ENDED` | Trial has ended |
| u108 | `ERR-INVALID-AGE` | Participant doesn't meet age requirement |
| u109 | `ERR-INVALID-PARTICIPANT` | Invalid participant |
| u110 | `ERR-TRIAL-NOT-STARTED` | Trial hasn't started yet |


## 🔧 Development

### Contract Structure
- **Data Variables**: Contract state management
- **Maps**: Persistent data storage
- **Public Functions**: State-changing operations
- **Read-Only Functions**: Data retrieval
- **Private Functions**: Internal utilities

### Key Functions
- `create-trial`: Creates new medical trials
- `give-consent`: Records participant consent
- `withdraw-consent`: Allows consent withdrawal
- `get-trial-status`: Returns comprehensive trial status


## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

