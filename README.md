---

🌟 Chetna: Proactive Health & Safety Ecosystem

> An edge-AI powered health ecosystem designed for proactive elderly care, featuring real-time fall detection, environmental sensor fusion, and multi-modal SOS alerts. 🚀 Developed for the Google Solution Challenge 2026, directly addressing UN SDG 3: Good Health & Well-being. 🏥

[![GitHub forks](https://img.shields.io/github/forks/ArnabTechiee/Chetna?style=social)](https://github.com/ArnabTechiee/Chetna/network)
[![GitHub stars](https://img.shields.io/github/stars/ArnabTechiee/Chetna?style=social)](https://github.com/ArnabTechiee/Chetna/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

📖 Table of Contents

- 🔗 Live Demos & Links
- 🚀 About the Project
- ✨ Key Features
- 🛠️ Technology Stack
- 📐 System Architecture
- ⚙️ Getting Started
- 💡 Usage
- 👥 Contributors

---

🔗 Live Demos & Links

📱 Mobile App Interactive Demo: Test Chetna on Appetize.io - https://appetize.io/app/b_4yf3kdurbl3ionojmwphoopxoe
💻 Caregiver Web Dashboard: Live Firebase Deployment - https://chetna-healthhack.web.app/
🎥 3-Minute Pitch Video: Watch on Google Drive - https://drive.google.com/file/d/15M_3lniA8H0waL7hH3Lt0QrtbUYRX50E/view

---

🚀 About the Project

Chetna bridges the gap between reactive emergency response and proactive wellness monitoring. It features a dual-interface system consisting of a user-facing mobile application and a Caregiver Dashboard tailored for guardians and healthcare professionals. By leveraging on-device machine learning (TensorFlow Lite) and the Gemini API, Chetna ensures high privacy, low latency, and continuous protection against the "Silent Gap" in emergency response. 🛡️

---

✨ Key Features

1. 🧠 Edge AI Fall Detection
   - 📊 On-Device 1D-CNN: Processes accelerometer and gyroscope data directly on the user's device.
   - ⚡ 3-Phase Fall Signature: Accurately classifies falls by detecting Free-fall, Impact, and Stillness, drastically reducing false positives.

2. 🌿 Proactive Wellness & Environmental Monitoring
   - 🔄 Sensor Fusion: Aggregates real-time data across Light, Noise, Temperature, and Air Quality Index (AQI).
   - 🤖 Gemini AI Risk Detection: Automatically flags potential environmental hazards, such as Sensory Overload and Respiratory Risk, before they become emergencies.

3. 🆘 Comprehensive Emergency Protocol
   - ⏱️ Smart Cancellation: Features a 15-second cancellation window to prevent false alarms.
   - 📢 Multi-Modal SOS: Dispatches instant alerts to the Caregiver Dashboard, activates a loud device siren, and triggers heavy vibrations.
   - 🗣️ Chetna Voice Guardian: A hands-free, NLP voice-activated SOS protocol for situations where physical interaction with the device is impossible (the "Physical Lock").
   - 🧘 Psychological First Aid: Triggers a "Trusted Voice" audio loop during emergencies to reduce user panic while help arrives.

---

🛠️ Technology Stack

📱 Mobile Application:
- 🎨 Frontend: Flutter / Dart
- 🤖 AI & Offline Intelligence: TensorFlow Lite (On-device Machine Learning), custom 2-step fall detection algorithm.

☁️ Backend & Dashboard:
- 🔥 Cloud & Database: Cloud Firebase (Real-time database, Authentication, secure syncing).
- 🌐 AI Integrations: Gemini API

---

⚙️ Getting Started

Follow these instructions to set up the project locally.

📋 Prerequisites:
Make sure you have Git, Flutter, and Python installed on your machine.

⚙️ Installation:

1. 📦 Clone the repository:
   git clone https://github.com/ArnabTechiee/Chetna.git
   cd Chetna/chetna_app

2. 📲 Install Flutter Dependencies:
   flutter pub get

3. 🚀 Run the Mobile App:
   flutter run

---

💡 Usage

- 📱 User Mobile App: Once installed, grant the necessary permissions (Microphone, Sensors, Location). The app will run quietly in the background monitoring for G-force anomalies or Voice Guardian triggers.
- 🖥️ Caregiver Dashboard: Log into the Firebase web portal to view real-time environmental data, mood logs, and instantly receive SOS alerts if a fall is detected.

---

👥 Contributors

🤝 Team Name: Chetna AI

- 👨‍💻 Arnab Mondal (Team Leader)
- 👨‍💻 Subhojeet Chanda
- 👨‍💻 Gaurang Pant

---

Built with ❤️ for the Google Solution Challenge 2026

---

That's it. Copy everything above exactly as is. GitHub will render the badge links correctly, and all emojis will show up. No markdown formatting that can break.
