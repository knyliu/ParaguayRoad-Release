# ParaguayRoad

An interactive learning game that combines multiple-choice quizzes, a mini road-crossing game, and personalized AI feedback. Built with **Processing (Java-based)**, it integrates Google Sheets for data storage and Google Gemini LLM for intelligent feedback generation.

---

## Features

* **Login / Register System**
  Authenticates users using data from a Google Sheet.

* **Live Quiz Loading**
  Loads questions from Google Sheets using the Sheets API v4.

* **Question Diversity**
  Each question includes text, difficulty level, multiple choices, and optional images.

* **Mini Road-Crossing Game**
  Players must cross the road and avoid monsters to collect treasure after each question.

* **AI Learning Suggestions**
  Generates personalized study feedback using Gemini 2.0 Flash (`generateContent` API).

* **Leaderboard**
  Displays each player’s highest score.

---

## Data Sources

### Google Sheets

* **User Response Sheet**
  Used for login, registration, and storing score records.

* **Problem Set Sheet**
  Contains questions, difficulty, answer key, choices (A–D), and image URLs.

### Google Form

* Used to submit scores after the game via HTTP POST.

### Gemini API

* Powered by `generativelanguage.googleapis.com` with model `gemini-2.0-flash`.

---

## Game Flow

1. **Login / Register**
2. **Story Introduction (with 3 illustrated slides)**
3. **Multiple-Choice Questions**
4. **Mini Road-Crossing Game**
5. **Final Score + AI Feedback + Upload Score**
6. **Leaderboard & Personal Records**

---

## Setup & Installation

### Requirements

* Java environment
* [Processing IDE](https://processing.org/download/)
* [Minim Audio Library](http://code.compartmental.net/tools/minim/)
* Google Sheets API enabled + API Key
* A published Google Sheet (for both quiz and user responses)

### Folder Structure

```
ParaguayQuiz/
├── data/
│   ├── monster_*.png
│   ├── background_*.png
│   ├── player_*.png
│   ├── treasure.png
│   ├── welcome.png
│   ├── building_intro_*.png
│   ├── strart.mp3
│   ├── question.mp3
│   ├── road.mp3
│   ├── award.mp3
│   ├── boom.png
│   ├── boom.MP3
│   └── step.mp3
├── ParaguayRoad.pde
├── ...
```

---

## Configuration

Update the following fields in the source code:

```java
final String API_KEY         = "YOUR_GOOGLE_API_KEY";
final String SHEET_ID        = "YOUR_USER_RESPONSE_SHEET_ID";
final String PROBLEM_SHEET_ID = "YOUR_PROBLEM_SET_SHEET_ID";
final String FORM_URL         = "YOUR_GOOGLE_FORM_POST_URL";
final String LLM_URL          = "YOUR_GEMINI_API_URL_WITH_KEY";
```

