# 🌟 Chetna: Proactive Health & Safety Ecosystem

> An edge-AI powered health ecosystem designed for proactive elderly care, featuring real-time fall detection, environmental sensor fusion, and multi-modal SOS alerts. Originally developed for the Bhopal Health Hack.

[![GitHub forks](https://img.shields.io/github/forks/ArnabTechiee/Chetna?style=social)](https://github.com/ArnabTechiee/Chetna/network)
[![GitHub stars](https://img.shields.io/github/stars/ArnabTechiee/Chetna?style=social)](https://github.com/ArnabTechiee/Chetna/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 📖 Table of Contents
- [About the Project](#-about-the-project)
- [Key Features](#-key-features)
- [Technology Stack](#-technology-stack)
- [System Architecture](#-system-architecture)
- [Getting Started](#-getting-started)
- [Usage](#-usage)
- [Contributors](#-contributors)

---

## 🚀 About the Project
Chetna bridges the gap between reactive emergency response and proactive wellness monitoring. It features a dual-interface system consisting of a user-facing mobile application and an Admin Dashboard tailored for researchers and healthcare professionals. By leveraging on-device machine learning, Chetna ensures high privacy, low latency, and continuous protection.

---

## ✨ Key Features

### 1. Edge AI Fall Detection
* **On-Device 1D-CNN:** Processes accelerometer and gyroscope data directly on the user's device.
* **3-Phase Fall Signature:** Accurately classifies falls by detecting Free-fall, Impact, and Stillness, drastically reducing false positives.

### 2. Proactive Wellness & Environmental Monitoring
* **Sensor Fusion:** Aggregates real-time data across Light, Noise, Temperature, and Air Quality Index (AQI).
* **Risk Detection:** Automatically flags potential environmental hazards, such as Sensory Overload and Respiratory Risk, before they become emergencies.

### 3. Comprehensive Emergency Protocol
* **Smart Cancellation:** Features a 15-second cancellation window to prevent false alarms.
* **Multi-Modal SOS:** Dispatches instant alerts via SMS, activates a loud device siren, and triggers heavy vibrations.
* **Chetna Voice Guardian:** A hands-free, voice-activated SOS protocol for situations where physical interaction with the device is impossible.

---

## 🛠️ Technology Stack

**Mobile Application:**
* Flutter / Dart (UI Framework)
* TensorFlow Lite (On-device Machine Learning)

**Backend & Dashboard:**
* Python / Flask or FastAPI
* Machine Learning: Scikit-learn, Pandas, NumPy
* Database: Firebase / PostgreSQL

---

## ⚙️ Getting Started

Follow these instructions to set up the project locally.

### Prerequisites
Make sure you have [Git](https://git-scm.com/), [Flutter](https://flutter.dev/docs/get-started/install), and [Python](https://www.python.org/downloads/) installed on your machine.

### Installation

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/ArnabTechiee/Chetna.git](https://github.com/ArnabTechiee/Chetna.git)
   cd Chetna
