# 🌟 Chetna: Proactive Health & Safety Ecosystem

> An edge-AI powered health ecosystem designed for proactive elderly care, featuring real-time fall detection, environmental sensor fusion, and multi-modal SOS alerts.  
> **Developed for the Google Solution Challenge 2026, directly addressing UN SDG 3: Good Health & Well-being.**

![GitHub Repo](https://img.shields.io/badge/Repo-Chetna-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📖 Table of Contents

- [🔗 Live Demos & Links](#-live-demos--links)
- [🚀 About the Project](#-about-the-project)
- [✨ Key Features](#-key-features)
- [🛠️ Technology Stack](#️-technology-stack)
- [⚙️ Getting Started](#️-getting-started)
- [💡 Usage](#-usage)
- [👥 Contributors](#-contributors)

---

## 🔗 Live Demos & Links

- 📱 **Mobile App Interactive Demo:**  
  👉 https://appetize.io/app/b_4yf3kdurbl3ionojmwphoopxoe  

- 💻 **Caregiver Web Dashboard:**  
  👉 https://chetna-healthhack.web.app/  

- 🎥 **3-Minute Pitch Video:**  
  👉 https://drive.google.com/file/d/15M_3lniA8H0waL7hH3Lt0QrtbUYRX50E/view  

---

## 🚀 About the Project

Chetna bridges the gap between reactive emergency response and proactive wellness monitoring.  

It features a **dual-interface system**:
- 📱 User-facing mobile application  
- 💻 Caregiver dashboard  

By leveraging:
- **On-device Machine Learning (TensorFlow Lite)**
- **Gemini API**

Chetna ensures:
- 🔒 High privacy  
- ⚡ Low latency  
- 🛡️ Continuous protection against the *"Silent Gap"* in emergency response  

---

## ✨ Key Features

### 1️⃣ Edge AI Fall Detection

- **On-Device 1D-CNN:**  
  Processes accelerometer and gyroscope data locally.

- **3-Phase Fall Signature:**  
  Detects:
  - Free-fall  
  - Impact  
  - Stillness  

  → Minimizes false positives significantly.

---

### 2️⃣ Proactive Wellness & Environmental Monitoring

- **Sensor Fusion:**  
  Combines real-time data from:
  - Light  
  - Noise  
  - Temperature  
  - Air Quality Index (AQI)

- **Gemini AI Risk Detection:**  
  Identifies risks like:
  - Sensory overload  
  - Respiratory hazards  

  → Before they become emergencies.

---

### 3️⃣ Comprehensive Emergency Protocol

- ⏳ **Smart Cancellation:**  
  15-second window to cancel false alerts  

- 🚨 **Multi-Modal SOS:**  
  - Dashboard alerts  
  - Loud siren  
  - Device vibration  

- 🎙️ **Chetna Voice Guardian:**  
  Hands-free voice-triggered SOS  

- 🧠 **Psychological First Aid:**  
  Plays trusted voice audio to reduce panic  

---

## 🛠️ Technology Stack

### 📱 Mobile Application
- Flutter / Dart  
- TensorFlow Lite (On-device ML)  
- Custom 2-step fall detection algorithm  

### ☁️ Backend & Dashboard
- Firebase (Realtime DB, Auth, Sync)  
- Gemini API  

---

## ⚙️ Getting Started

### ✅ Prerequisites

Make sure you have installed:
- Git  
- Flutter  
- Python  

---

### 📦 Installation

Here’s the **corrected Markdown for only the part in your image** 👇

````markdown
```bash
# Clone the repository
git clone https://github.com/ArnabTechiee/Chetna.git

# Navigate to project
cd Chetna/chetna_app

# Install dependencies
flutter pub get

# Run the app
flutter run
```
````


## 💡 Usage

### 📱 User Mobile App

Grant permissions:

* Microphone
* Sensors
* Location

Runs in background:

* Detects falls
* Listens for voice SOS

### 💻 Caregiver Dashboard

Login via Firebase web portal

Monitor:

* Environmental data
* Mood logs
* SOS alerts

## 👥 Contributors

**Team Name:** Chetna AI

* Arnab Mondal (Team Leader)
* Subhojeet Chanda
* Gaurang Pant

## ❤️ Acknowledgment

Built with ❤️ for the Google Solution Challenge 2026
