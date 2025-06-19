import http.requests.*;
import java.util.ArrayList;
import java.util.Comparator;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import java.io.OutputStreamWriter;
import processing.data.*;
import ddf.minim.*;
import processing.event.MouseEvent;
import java.util.Map;
import java.util.HashMap;
import java.io.File;


/***** 0. Gemini LLM 相關設定 *****/
final String LLM_URL =
    ""
  + "?key=";
String adviceText    = "";      // 教學建議
boolean adviceFetched = false;  // 只呼叫一次

/***** 0a. Google Sheets API v4 讀取使用者回應 *****/
final String API_KEY         = "";
final String SHEET_ID        = ""
// 對應你 Google Sheet 的分頁標籤名稱 (tab name)
final String RESPONSES_RANGE = "表單回應 1";
String fetchSheetJson(String sheetName) throws Exception {
  // 單引號直接包起來
  //String rawRange = "'" + sheetName + "'";
  // 空格用 %20 替代（避免 URLEncoder 把空格變成 +）
  String encodedRange = URLEncoder.encode(sheetName, "UTF-8");
  //String encodedRange = rawRange.replace(" ", "%20");

  String urlStr = "https://sheets.googleapis.com/v4/spreadsheets/"
                + SHEET_ID
                + "/values/" + encodedRange
                + "?key=" + API_KEY;

  HttpURLConnection conn = (HttpURLConnection)new URL(urlStr).openConnection();
  conn.setRequestMethod("GET");
  BufferedReader br = new BufferedReader(
      new InputStreamReader(conn.getInputStream(), "UTF-8")
  );
  StringBuilder sb = new StringBuilder();
  String line;
  while ((line = br.readLine()) != null) {
    sb.append(line);
  }
  br.close();
  conn.disconnect();
  return sb.toString();
}


// 0b. Problem Set 即時讀取 (API v4)
final String PROBLEM_SHEET_ID    = "";
// 對應你的分頁標籤名稱（tab name），例如 "工作表1"、"Sheet1"、或你自訂的名稱
final String PROBLEM_SHEET_NAME  = "工作表1"; 
/**
 * 透過 Sheets API v4，取得指定工作表範圍的 JSON
 */
String fetchProblemSetJson() throws Exception {
    // 工作表名稱加單引號，並將空格轉 %20
    //String rawRange    = "'" + PROBLEM_SHEET_NAME + "'";
    //String encodedRange = rawRange.replace(" ", "%20");
    String encodedRange = URLEncoder.encode(PROBLEM_SHEET_NAME, "UTF-8");
    String urlStr = "https://sheets.googleapis.com/v4/spreadsheets/"
                    + PROBLEM_SHEET_ID
                    + "/values/" + encodedRange
                    + "?key=" + API_KEY;  // 使用既有的 API_KEY

    HttpURLConnection conn = (HttpURLConnection) new URL(urlStr).openConnection();
    conn.setRequestMethod("GET");
    BufferedReader br = new BufferedReader(
        new InputStreamReader(conn.getInputStream(), "UTF-8")
    );
    StringBuilder sb = new StringBuilder();
    String line;
    while ((line = br.readLine()) != null) {
        sb.append(line);
    }
    br.close();
    conn.disconnect();
    return sb.toString();  // 回傳整張表的 JSON 字串
}



/***** 1. 全域計分與隱形設定 *****/
int   correctCount = 0;
float totalScore   = 0;
final int   basePoints          = 100;
final float timeBonusMultiplier = 2.0f;
final int   collisionPenalty    = 100;
final float easyMultiplier      = 1.0f;
final float mediumMultiplier    = 1.2f;
final float hardMultiplier      = 1.5f;
final int   crossingReward      = 50;
final int   invisReward         = 100;
final int   MAX_INVISIBLE       = 3;
int   invisibleUses  = 0;
boolean isInvisible  = false;
long   invisibleStart = 0;
final int INVISIBLE_DURATION = 3000; // ms

/***** 1a. AI Advice Modal 狀態 *****/
boolean showAdviceModal    = false;
float   adviceScrollOffset = 0;

/***** 2. 統一倒數計時 (40 秒) *****/
final int TOTAL_DURATION = 40 * 1000;
long      countdownStartTime;

// === 題庫 CSV 來源（與使用者回應不同） ===
final String SHEET_URL     =
  "";
// Google Form 提交用
final String FORM_URL      =
  "";
/***** Google Form 欄位代號 *****/
final String ENTRY_NAME     = "entry.1290096940";
final String ENTRY_ACCOUNT  = "entry.1469038103";
final String ENTRY_PASSWORD = "entry.182905058";
final String ENTRY_SCORE    = "entry.1610854592";

String story =
  "歡迎，勇敢的冒險者，來到神秘的巴拉圭！\n" +
  "你原本只是在師大校園裡悠閒漫步（應該不是翹課），\n" +
  "卻被突如其來的時空風暴捲入，\n" +
  "來到這片南美內陸的熱帶原野。\n" +
  "身上沒帶一毛錢（工讀薪水還沒發……），\n" +
  "但別擔心，真正的冒險才剛開始！\n" +
  "接下來的試煉關卡將帶你探索壯麗的潘帕草原、\n" +
  "深入充滿文化的巴拉圭，並收集散落在四處的寶物。\n" +
  "唯一要小心的，是那些形狀詭異、暗藏危機的怪物，\n" +
  "它們正潛伏在陰影中，等著考驗你的智慧與勇氣！";

/***** 4. 場景管理 *****/
enum Scene {
  LOGIN,      // 登入頁
  REGISTER,   // 註冊頁
  STORY,      // 「歡迎來到 Paraguary 馬路」這一幕
  BUILDING1,  // 新增：第一張引導圖
  BUILDING2,  // 新增：第二張引導圖
  BUILDING3,  // 新增：第三張引導圖
  INTRO,      // 遊戲說明
  QUIZ,
  TRANSITION,
  TREASURE,
  RESULT,
  RECORDS
}
Scene scene     = Scene.LOGIN;
Scene lastScene = null;

PImage building1Img, building2Img, building3Img;

/***** 5. 排行榜資料 *****/
ArrayList<ScoreEntry> globalRanking = null;
class ScoreEntry {
  String name;
  int    score;
  ScoreEntry(String name,int score){
    this.name=name; this.score=score;
  }
}

/***** 6. 題目結構 *****/
class Question {
  String text, difficulty, answer;
  String[] opts;
  PImage img;

  // 新增這個建構子
  Question(String text, String difficulty, String answer, String[] opts, String imageUrl){
    this.text       = text;
    this.difficulty = difficulty;
    this.answer     = answer;
    this.opts       = opts;
    this.img        = (imageUrl != null && imageUrl.length()>0)
                      ? loadImage(imageUrl)
                      : null;
  }

}


/***** 7. 答案紀錄結構 *****/
class AnswerEntry {
  String qText, selected, correct;
  AnswerEntry(String qText,String selected,String correct){
    this.qText=qText;
    this.selected=selected;
    this.correct=correct;
  }
}
ArrayList<AnswerEntry> answerLog = new ArrayList<>();

/***** 8. 簡易輸入框 *****/
class InputBox {
  float x,y,w,h;
  String label, value="";
  boolean active=false;
  InputBox(String l,float x,float y,float w,float h){
    label=l; this.x=x; this.y=y; this.w=w; this.h=h;
  }
  void draw(){
    stroke(active?color(0,120,255):150);
    fill(255);
    rect(x,y,w,h,4);
    fill(0); textAlign(LEFT,CENTER);
    String prefix = label + ": ";
    float prefixW = textWidth(prefix);
    float availW  = w - 10 - prefixW;
    String disp   = value;
    while(textWidth(disp)>availW && disp.length()>0){
      disp = "…" + disp.substring(1);
    }
    text(prefix + disp, x+5, y+h/2);
  }
  boolean over(float mx,float my){
    return mx>x && mx<x+w && my>y && my<y+h;
  }
}

/***** 9. 小遊戲物件 *****/
class GameObject {
  PImage img; float x,y,w,h;
  GameObject(String path,float x,float y,float w,float h){
    img = loadImage(path);
    img.resize((int)w,(int)h);
    this.x=x; this.y=y; this.w=w; this.h=h;
  }
  void draw(){ image(img,x,y); }
}
class PlayerCharacter extends GameObject {
  final float SPEED = 10;
  PlayerCharacter(String p,float x,float y,float w,float h){
    super(p,x,y,w,h);
  }
  void move(int vy,int vx){
    y += vy * SPEED;
    y = constrain(y,0,height-h);
    x += vx * SPEED;
    x = constrain(x,0,width-w);
  }
  boolean detect(GameObject o){
    return !(y>o.y+o.h || y+h<o.y || x>o.x+o.w || x+w<o.x);
  }
  void setImage(String path){
    img = loadImage(path);
    img.resize((int)w, (int)h);
  }
}
class EnemyCharacter extends GameObject {
  float speed = 5;
  EnemyCharacter(String p,float x,float y,float w,float h){
    super(p,x,y,w,h);
  }
  void move(float maxW){
    if(x<=0) speed = abs(speed);
    if(x>=maxW-w) speed = -abs(speed);
    x += speed * levelSpeed;
  }
}

/***** 10. 全域狀態 *****/
ArrayList<Question> questions = new ArrayList<>();
int qIndex=0, selected=-1, pendingSelected=-1;
String name="", account="", password="";
String loginError="", registerError="";
PFont font;
InputBox boxName     = new InputBox("Name",    260,200,280,32);
InputBox boxAccount  = new InputBox("Account", 260,250,280,32);
InputBox boxPassword = new InputBox("Password",260,300,280,32);
PImage bg;

PlayerCharacter player;
ArrayList<EnemyCharacter> enemies;
GameObject treasure;
float levelSpeed = 1;
int dirV=0, dirH=0;
boolean zoomedImage = false;
float quizImgX, quizImgY, quizImgW, quizImgH;
String[] monsterFiles;
String[] mapFiles;

void loadMonsterFiles(){
  File folder = new File(dataPath(""));      // data/ 資料夾
  ArrayList<String> names = new ArrayList<>();
  for(File f : folder.listFiles()){
    String n = f.getName();
    if(n.startsWith("monster_") && n.endsWith(".png")){
      names.add(n);
    }
  }
  monsterFiles = names.toArray(new String[0]);
  println("Found monsters:", monsterFiles.length);
}
void loadMapFiles() {
  File folder = new File(dataPath(""));      // 指向 data/ 資料夾
  ArrayList<String> names = new ArrayList<>();
  for (File f : folder.listFiles()) {
    String n = f.getName();
    if (n.startsWith("background_") && n.endsWith(".png")) {
      names.add(n);
    }
  }
  mapFiles = names.toArray(new String[0]);
  println("Found backgrounds:", mapFiles.length);
}

/***** 11. 音樂 *****/
Minim minim;
AudioPlayer startMusic, questionMusic, roadMusic, awardMusic;

/***** 12. Setup *****/
PImage welcomeBg;
/***** 12.1 爆炸*****/
PImage boomImg;
boolean showBoom = false;
long boomStartTime = 0;
final int BOOM_DURATION = 1000;
float boomX, boomY;
AudioPlayer stepSound;
AudioPlayer boomSound;
void setup(){
  size(800,600);
  // (B) 載入並調整 welcome.png
  welcomeBg = loadImage("welcome.png");
  welcomeBg.resize(width, height);
  boomImg = loadImage("boom.png");

  // ── 在這裡載入三張引導圖（滿版）
  building1Img = loadImage("building_intro_1.png");
  building1Img.resize(width, height);
  building2Img = loadImage("building_intro_2.png");
  building2Img.resize(width, height);
  building3Img = loadImage("building_intro_3.png");
  building3Img.resize(width, height);

  //font = createFont("SansSerif",18);
  font = createFont("NotoSansTC-Regular.ttf", 18);
  textFont(font);
  minim = new Minim(this);
  startMusic    = minim.loadFile("data/strart.mp3");
  questionMusic = minim.loadFile("data/question.mp3");
  roadMusic     = minim.loadFile("data/road.mp3");
  awardMusic    = minim.loadFile("data/award.mp3");
  stepSound = minim.loadFile("data/step.mp3");
  boomSound = minim.loadFile("data/boom.MP3");
  loadMonsterFiles();
  loadMapFiles();
  loadProblemSetQuestions();
  setupGameLevel();
}

/***** 13. 音樂控制 *****/
void stopAllMusic(){
  startMusic.pause();    startMusic.rewind();
  questionMusic.pause(); questionMusic.rewind();
  roadMusic.pause();     roadMusic.rewind();
  awardMusic.pause();    awardMusic.rewind();
}
void updateMusic(){
  if(scene==lastScene) return;
  stopAllMusic();
  switch(scene){
    case LOGIN: case REGISTER: case INTRO: case RECORDS:
      startMusic.loop(); break;
    case QUIZ:
      questionMusic.loop(); break;
    case TREASURE:
      roadMusic.loop(); break;
    case RESULT:
      awardMusic.loop(); break;
  }
  lastScene = scene;
}

/***** 14. 主迴圈 *****/

void drawTransition(){
  background(0); 
  fill(255); textAlign(CENTER, CENTER); textSize(32);
  // 計算已顯示幾個字
  int len = transitionText.length();
  long elapsed = millis() - transitionStart;
  displayedChars = min(len, (int)(elapsed / charInterval));
  text(transitionText.substring(0, displayedChars), width/2, height/2);
  // 如果打完一次
  if(displayedChars == len && !typeDone){
    typeDone = true;
    typeFinishedTime = millis();
  }
  // 打完後再等三秒，自動進場
  if(typeDone && millis() - typeFinishedTime >= 3000){
    // 一旦呼叫，重置旗標
    typeDone = false;
    displayedChars = 0;
    // 真正進入下一個場景
    enterTreasure();
  }
}

void draw(){
  background(245);
  updateMusic();

  switch(scene){
    case LOGIN:       drawLogin();    break;
    case REGISTER:    drawRegister(); break;
    case STORY:       drawStory();    break;
    case BUILDING1:   drawBuilding(1); break;
    case BUILDING2:   drawBuilding(2); break;
    case BUILDING3:   drawBuilding(3); break;
    case INTRO:       drawIntro();    break;
    case QUIZ:        drawQuiz();     break;
    case TRANSITION:  drawTransition(); break;
    case TREASURE:    drawTreasure(); break;
    case RESULT:      drawResult();   break;
    case RECORDS:     drawRecords();  break;
  }
}

void drawBuilding(int idx){
  // 先把對應的圖當背景
  if(idx == 1) image(building1Img, 0, 0);
  else if(idx == 2) image(building2Img, 0, 0);
  else if(idx == 3) image(building3Img, 0, 0);

  // 在畫面下方畫一個「下一頁」按鈕
  String lbl = "下一頁";
  float btnW = 120, btnH = 40;
  float btnX = (width - btnW) / 2;
  float btnY = height - btnH - 20;

  drawButton(lbl, btnX, btnY, btnW, btnH);
}



/***** 15. HUD / 按鈕 *****/
void drawHUD(){
  fill(0); textAlign(LEFT,TOP); textSize(18);
  text("Score: "+(int)totalScore,20,20);
  text("Invis left: "+(MAX_INVISIBLE-invisibleUses),20,40);
}
void drawButton(String lbl,float x,float y,float w,float h){
  fill(overButton(x,y,w,h)?color(200,230,255):220);
  stroke(150); rect(x,y,w,h,6);
  fill(0); textAlign(CENTER,CENTER); text(lbl,x+w/2,y+h/2);
}
boolean overButton(float x,float y,float w,float h){
  return mouseX>x && mouseX<x+w && mouseY>y && mouseY<y+h;
}
void drawOption(String txt,float x,float y,int idx){
  fill(idx==selected?color(180,220,255):230);
  stroke(150); rect(x,y,640,40,6);
  fill(0); textAlign(LEFT,CENTER);
  text((char)('A'+idx)+". "+txt, x+10, y+20);
}

void drawStory(){
  background(30, 30, 60);
  fill(255); textAlign(CENTER, TOP);
  textSize(32);
  text("歡迎來到Paraguay馬路", width/2, 60);
  fill(255); textAlign(LEFT, TOP); textSize(18);
  text(story, 100, 140, 600, 300);
  drawButton("我可以的！", width/2-80, height-80, 160, 40);
}


/***** 16. LOGIN *****/
void drawLogin(){
  // (C) 先把 welcome.png 畫滿整個畫布當背景
  image(welcomeBg, 0, 0);

  // 以下維持原本的登入畫面繪製
  fill(0); textAlign(CENTER); textSize(28);
  //text("Quiz & Crossing Game", width/2,100);
  boxAccount.draw(); boxPassword.draw();
  drawButton("Login", width/2-140,370,120,40);
  drawButton("Register", width/2+20,370,120,40);
  if(!loginError.isEmpty()){
    fill(200,0,0); textAlign(CENTER); textSize(16);
    text(loginError, width/2,420);
  }
}
void loginMouse(){
  if(overButton(width/2-140,370,120,40)){
    account=boxAccount.value.trim();
    password=boxPassword.value.trim();
    try {
      String json = fetchSheetJson(RESPONSES_RANGE);
      JSONObject root  = JSONObject.parse(json);
      JSONArray rows   = root.getJSONArray("values");
      boolean ok = false;
      for(int i=1; i<rows.size(); i++){
        JSONArray row = rows.getJSONArray(i);
        if(row.getString(2).equals(account)
        && row.getString(3).equals(password)){
          ok = true;
          name = row.getString(1);
          break;
        }
      }
      if(ok){
        loginError="";
        scene = Scene.STORY; 
      } else {
        loginError="帳號或密碼錯誤";
      }
    } catch(Exception e){
      loginError="登入時出錯";
      e.printStackTrace();
    }
  }
  else if(overButton(width/2+20,370,120,40)){
    loginError=""; scene=Scene.REGISTER;
  }
}

/***** 17. REGISTER *****/
void drawRegister(){
  fill(0); textAlign(CENTER); textSize(28);
  text("Create Account", width/2,120);
  boxName.draw(); boxAccount.draw(); boxPassword.draw();
  drawButton("Submit", width/2-60,370,120,40);
  drawButton("Back",20,20,80,32);
  if(!registerError.isEmpty()){
    fill(200,0,0); textAlign(CENTER); textSize(16);
    text(registerError, width/2,420);
  }
}
void registerMouse(){
  if(overButton(width/2-60,370,120,40)){
    name=boxName.value.trim();
    account=boxAccount.value.trim();
    password=boxPassword.value.trim();
    try {
      String json = fetchSheetJson(RESPONSES_RANGE);
      JSONObject root = JSONObject.parse(json);
      JSONArray rows  = root.getJSONArray("values");
      boolean exists = false;
      for(int i=1; i<rows.size(); i++){
        if(rows.getJSONArray(i).getString(2).equals(account)){
          exists = true; break;
        }
      }
      if(exists){
        registerError="帳號已存在";
      } else {
        sendForm(name,account,password,0);
        registerError="";
        scene = Scene.STORY; 
      }
    } catch(Exception e){
      registerError="註冊時出錯";
      e.printStackTrace();
    }
  }
  else if(overButton(20,20,80,32)){
    scene=Scene.LOGIN;
  }
}

/***** 18. INTRO *****/
void drawIntro(){
  fill(0); textAlign(CENTER); textSize(28);
  text("計分方式與操作方式", width/2,80);
  fill(50); textAlign(LEFT,TOP); textSize(18);
  float px=100, py=140;
  text("1. 答題正確：+100",px,py);
  text("2. 時間獎勵：剩餘秒數 ×2 (最多 +60)",px,py+30);
  text("3. 難度加成：簡單×1 中等×1.2 困難×1.5",px,py+60);
  text("4. 過馬路成功：+50／次",px,py+90);
  text("5. 撞到障礙物：−100／次",px,py+120);
  text("6. 隱形剩餘獎勵：+100／次 (最多 3 次)",px,py+150);
  text("使用方向上下移動腳色",px,py+210);
  text("J是防護罩！可以避開怪物攻擊，但你只有三次使用機會！",px,py+240);

  drawButton("開始遊戲", width/2-60,height-120,120,40);
}
void introMouse(){
  if(overButton(width/2-60,height-120,120,40)){
    enterTreasure();
  }
}

/***** 19. QUIZ *****/
void drawQuiz(){
  int elapsed = millis() - int(countdownStartTime);
  if(elapsed >= TOTAL_DURATION){ scene = Scene.RESULT; globalRanking = null; return; }
  int remain = (TOTAL_DURATION - elapsed) / 1000;
  if(zoomedImage){
    fill(0,150); rect(0,0,width,height);
    Question q = questions.get(qIndex);
    PImage qi = q.img;
    float scale = min((width*0.8f)/qi.width, (height*0.8f)/qi.height);
    float w2 = qi.width*scale, h2 = qi.height*scale;
    float x2=(width-w2)/2, y2=(height-h2)/2;
    image(qi,x2,y2,w2,h2);
    fill(255,0,0); rect(x2+w2-30,y2+10,20,20,4);
    fill(255); textAlign(CENTER,CENTER); text("X",x2+w2-20,y2+20);
    return;
  }
  drawHUD();
  fill(0); textAlign(RIGHT,TOP); textSize(18);
  text("Time: "+remain+"s", width-20,20);
  if(qIndex >= questions.size()){
    scene = Scene.RESULT;
    globalRanking = null;
    return;
  }
  Question q = questions.get(qIndex);
  float textY, baseY;
  if(q.img != null){
    float w = 200, h = q.img.height*(200.0f/q.img.width);
    float x = width/2 - w/2, y = 80;
    image(q.img,x,y,w,h);
    quizImgX = x; quizImgY = y; quizImgW = w; quizImgH = h;
    textY = 80 + h + 20; baseY = 80 + h + 60;
  } else {
    quizImgX = quizImgY = quizImgW = quizImgH = 0;
    textY = 80; baseY = 220;
  }
  fill(0); textAlign(LEFT,TOP); textSize(20);
  text("Q"+(qIndex)+" ("+q.difficulty+"): "+q.text, 60, textY, 680, 200);
  for(int i=0; i<4; i++){
    drawOption(q.opts[i], 80, baseY + i*60, i);
  }
  drawButton("Next", width-160, height-80,120,40);
}
void quizMouse(){
  Question q = questions.get(qIndex);
  float baseY = (q.img!=null)
    ? 80 + q.img.height*(200.0f/q.img.width) + 60
    : 220;
  for(int i=0; i<4; i++){
    if(mouseX>80 && mouseX<720
    && mouseY>baseY+i*60 && mouseY<baseY+i*60+40){
      selected = i;
    }
  }
// 在 quizMouse() 裡，Next 按鈕被按到的那段
if (overButton(width-160, height-80, 120, 40)) {
    pendingSelected = selected;

    // 選過場文字
    transitionText = transitionTexts[transitionIndex];
    transitionIndex = (transitionIndex + 1) % transitionTexts.length;

    // **馬上播放音效**
    stepSound.rewind();
    stepSound.play();

    // 開始打字機效果
    transitionStart = millis();
    scene = Scene.TRANSITION;
}

}

/***** 20. TREASURE *****/
/** 以 API 拉回回應，聚合每人最高分並排序 **/
void loadGlobalRanking(){
  try {
    String json = fetchSheetJson(RESPONSES_RANGE);
    JSONObject root = JSONObject.parse(json);
    JSONArray rows  = root.getJSONArray("values");
    Map<String,Integer> best = new HashMap<>();
    for(int i=1; i<rows.size(); i++){
      JSONArray row = rows.getJSONArray(i);
      String nm = row.getString(1).trim();
      int    sc = safeInt(row.getString(4).trim());
      if(nm.isEmpty()) continue;
      if(!best.containsKey(nm) || sc > best.get(nm)){
        best.put(nm, sc);
      }
    }
    globalRanking = new ArrayList<>();
    for(Map.Entry<String,Integer> e : best.entrySet()){
      globalRanking.add(new ScoreEntry(e.getKey(), e.getValue()));
    }
    globalRanking.sort((a,b)->b.score - a.score);
  } catch(Exception e){
    e.printStackTrace();
  }
}

void drawTreasure(){
  int elapsed = millis() - int(countdownStartTime);
  if(elapsed >= TOTAL_DURATION){ scene = Scene.RESULT; globalRanking = null; return; }
  int remain = (TOTAL_DURATION - elapsed) / 1000;
  image(bg,0,0);
  noStroke(); fill(255,200); rect(10,10,200,80,6);
  fill(0); textAlign(LEFT,TOP); textSize(18);
  text("Score: "+(int)totalScore,       20,18);
  text("Invis left: "+(MAX_INVISIBLE-invisibleUses),20,40);
  text("Time: "+remain+"s",             20,62);
  if(isInvisible && millis()-invisibleStart>INVISIBLE_DURATION){
    isInvisible = false;
  }
  treasure.draw();
  for(EnemyCharacter e : enemies){
    e.move(width);
    e.draw();
  }
  if(isInvisible) tint(255,100);
  player.draw();
  noTint();
  player.move(dirV, 0);
  
  boolean collided = false;
  if(!isInvisible){
    for(EnemyCharacter e : enemies){
      if(player.detect(e)){
        totalScore -= collisionPenalty;
        resetPlayerPosition();
        showBoom = true;
        if(boomSound.isPlaying()) boomSound.rewind();
            boomSound.pause();
            boomSound.rewind();
            boomSound.play();
        boomStartTime = millis();
        boomX = player.x + player.w/2 - boomImg.width/2;
        boomY = player.y + player.h/2 - boomImg.height/2;
        collided = true;
        break;
      }
    }
  }
  if(player.detect(treasure)){
    totalScore += crossingReward;
    setupGameLevel();
    processPendingAnswer();
  }
  if(showBoom){
    float alpha = map(millis() - boomStartTime, 0, BOOM_DURATION, 255, 0);
    tint(255, alpha);
    image(boomImg, boomX, boomY);
    noTint();
    if(millis() - boomStartTime > BOOM_DURATION){
    showBoom = false;
    }
  }
}
void resetPlayerPosition(){
  // 依你遊戲邏輯定義玩家起點位置
  player.x = 375;
  player.y = 700;
}
/***** 21. RESULT *****/
void drawResult(){
  float finalScore = totalScore + (MAX_INVISIBLE-invisibleUses)*invisReward;
  if(globalRanking == null){
    loadGlobalRanking();
  }
  if(!adviceFetched){
    generateAdvice();
    adviceFetched = true;
  }
  noStroke(); fill(0,150); rect(0,0,width,height);
  float pw=600, ph=520, px=(width-pw)/2, py=(height-ph)/2;
  fill(255); stroke(200); strokeWeight(2); rect(px,py,pw,ph,16);
  fill(40); textAlign(CENTER,TOP); textSize(36);
  text("Completed!", width/2, py+30);
  textSize(24);
  text("Final Score: "+(int)finalScore, width/2, py+80);
  text("Correct: "+correctCount+"/"+questions.size(), width/2, py+120);
  text("Invis bonus: "+(MAX_INVISIBLE-invisibleUses)+"×"+invisReward,
        width/2, py+160);
  if(globalRanking.size()>0){
    fill(0); textAlign(LEFT,TOP); textSize(18);
    text("Global Ranking (Top 5)", px+20, py+200);
    for(int i=0; i<min(5,globalRanking.size()); i++){
      ScoreEntry e = globalRanking.get(i);
      text((i+1)+". "+e.name+" : "+e.score, px+40, py+230+i*24);
    }
  }
  // 按鈕：AI 建議／Upload／Records／Restart
  drawButton("Show AI Advice", px+40,  py+ph-130,160,40);
  drawButton("Upload",          px+40,  py+ph-80, 120,40);
  drawButton("Your Top 5",         px+180, py+ph-80, 120,40);
  drawButton("Restart",         px+pw-160,py+ph-80,120,40);
  // AI 建議 Modal
  if(showAdviceModal){
    fill(0,200); rect(0,0,width,height);
    float mx=width*0.1f, my=height*0.1f;
    float mw=width*0.8f, mh=height*0.8f;
    fill(255); stroke(0); rect(mx,my,mw,mh,10);
    fill(0); textAlign(LEFT,TOP); textSize(16);
    pushMatrix(); translate(0, adviceScrollOffset);
    text(adviceText, mx+20, my+20, mw-40, mh-40);
    popMatrix();
    drawButton("Close", mx+mw-100, my+mh-50,80,30);
  }
}

void resultMouse(){
  float pw=600, ph=520;
  float px=(width-pw)/2, py=(height-ph)/2;
  float mx=width*0.1f, my=height*0.1f;
  float mw=width*0.8f, mh=height*0.8f;

  if(showAdviceModal){
    if(overButton(mx+mw-100, my+mh-50, 80,30)){
      showAdviceModal=false;
      adviceScrollOffset=0;
    }
    return;
  }

  if(overButton(px+40, py+ph-80,120,40)){       // Upload
    int finalSc = (int)(totalScore + (MAX_INVISIBLE-invisibleUses)*invisReward);
    sendForm(name,account,password,finalSc);
    loadGlobalRanking();
  }
  else if(overButton(px+180, py+ph-80,120,40)){ // Records
    loadPersonalRecords();
    scene=Scene.RECORDS;
  }
  else if(overButton(px+pw-160,py+ph-80,120,40)){ // Restart
    qIndex=0; correctCount=0; totalScore=0;
    invisibleUses=0; globalRanking=null; adviceText=""; adviceFetched=false;
    scene=Scene.INTRO;
  }
  else if(overButton(px+40, py+ph-130,160,40)){ // Show AI Advice
    showAdviceModal=true; adviceScrollOffset=0;
  }
}

/***** 22. RECORDS *****/
ArrayList<ScoreEntry> personalRecords = new ArrayList<>();
void loadPersonalRecords(){
  personalRecords.clear();
  try {
    String json = fetchSheetJson(RESPONSES_RANGE);
    JSONObject root = JSONObject.parse(json);
    JSONArray rows  = root.getJSONArray("values");
    for(int i=1; i<rows.size(); i++){
      JSONArray row = rows.getJSONArray(i);
      if(row.getString(2).equals(account)){
        String ts = row.getString(0).trim();
        int    sc = safeInt(row.getString(4).trim());
        personalRecords.add(new ScoreEntry(ts, sc));
      }
    }
    personalRecords.sort((a,b)->b.score - a.score);
  } catch(Exception e){
    e.printStackTrace();
  }
}
void drawRecords(){
  fill(0); textAlign(CENTER); textSize(26);
  text("Your Top 5 Records", width/2,60);
  textAlign(LEFT);
  for(int i=0; i<min(5,personalRecords.size()); i++){
    ScoreEntry e = personalRecords.get(i);
    text(e.name+"  Score:"+e.score, 120,120+i*30);
  }
  drawButton("Back",20,20,80,32);
}

/***** 23. 事件管理 *****/
void mousePressed() {
  // 處理所有 InputBox 的 focus 狀態
  for (InputBox b : new InputBox[] { boxName, boxAccount, boxPassword }) {
    b.active = b.over(mouseX, mouseY);
  }

  switch (scene) {
    case STORY:
      // 在 STORY 場景下，點擊「我可以的！」按鈕後進入第一張引導圖
      if (overButton(width / 2 - 80, height - 80, 160, 40)) {
        scene = Scene.BUILDING1;
      }
      break;

    case BUILDING1:
      // 在第一張引導圖，點擊「下一頁」進 BUILDING2
      if (overButton((width - 120) / 2, height - 60, 120, 40)) {
        scene = Scene.BUILDING2;
      }
      break;

    case BUILDING2:
      // 在第二張引導圖，點擊「下一頁」進 BUILDING3
      if (overButton((width - 120) / 2, height - 60, 120, 40)) {
        scene = Scene.BUILDING3;
      }
      break;

    case BUILDING3:
      // 在第三張引導圖，點擊「下一頁」才真正進入遊戲說明 INTRO
      if (overButton((width - 120) / 2, height - 60, 120, 40)) {
        scene = Scene.INTRO;
      }
      break;

    case LOGIN:
      // LOGIN 場景下的點擊處理，會呼叫 loginMouse() 判斷帳號密碼
      loginMouse();
      break;

    case REGISTER:
      // REGISTER 場景下的點擊處理，會呼叫 registerMouse() 判斷註冊流程
      registerMouse();
      break;

    case INTRO:
      // INTRO（遊戲說明）場景，點擊「開始遊戲」按鈕會執行 introMouse()
      introMouse();
      break;

    case QUIZ:
      // QUIZ 場景，如果圖片放大，點擊 X 關閉放大；否則傳遞給 quizMouse() 處理
      if (zoomedImage) {
        if (mouseX > quizImgX + quizImgW - 30 &&
            mouseX < quizImgX + quizImgW - 10 &&
            mouseY > quizImgY + 10 &&
            mouseY < quizImgY + 30) {
          zoomedImage = false;
        }
      } else {
        quizMouse();
      }
      break;

    case TRANSITION:
      // TRANSITION 場景通常只做打字機效果，若需要可在此加處理
      break;

    case TREASURE:
      // TREASURE 場景下，敵人移動／碰撞邏輯在 draw() 裡已經處理，
      // 這裡如果有按鈕（例如隱藏、暫停等）可在此判斷
      break;

    case RESULT:
      // RESULT 場景下會顯示最終分數、AI 建議、上傳按鈕、Records、Restart
      resultMouse();
      break;

    case RECORDS:
      // RECORDS 場景下點擊「Back」會回到 RESULT
      if (overButton(20, 20, 80, 32)) {
        scene = Scene.RESULT;
      }
      break;
  }
}


void keyTyped(){
  if(scene==Scene.LOGIN||scene==Scene.REGISTER){
    for(InputBox b: new InputBox[]{boxName,boxAccount,boxPassword}){
      if(b.active){
        if(key==BACKSPACE && b.value.length()>0){
          b.value = b.value.substring(0,b.value.length()-1);
        } else if(key!=CODED && key!=ENTER){
          b.value += key;
        }
      }
    }
  }
}
void keyPressed(){
  if(scene==Scene.TREASURE){
    if((key=='j'||key=='J') && !isInvisible && invisibleUses<MAX_INVISIBLE){
      isInvisible=true; invisibleStart=millis(); invisibleUses++;
    }
if (key == 'w' || key == 'W' || keyCode == UP) {
  dirV = -1;
  //player.img = loadImage("player_2.png");  // 向前時顯示 player_2
  player.setImage("player_2.png");
}
else if (key == 's' || key == 'S' || keyCode == DOWN) {
  dirV = 1;
  //player.img = loadImage("player_1.png");  // 向後時顯示 player_1
  player.setImage("player_1.png");
}

    if(key=='a'||key=='A') dirH=-1;
    else if(key=='d'||key=='D') dirH=1;
    if(key==CODED){
      if(keyCode==UP)    dirV=-1;
      if(keyCode==DOWN)  dirV=1;
      if(keyCode==LEFT)  dirH=-1;
      if(keyCode==RIGHT) dirH=1;
    }
  }
}
void keyReleased(){
  if(scene==Scene.TREASURE){
    if(key=='w'||key=='W'||key=='s'||key=='S'
    ||(key==CODED&&(keyCode==UP||keyCode==DOWN))){
      dirV=0;
    }
    if(key=='a'||key=='A'||key=='d'||key=='D'
    ||(key==CODED&&(keyCode==LEFT||keyCode==RIGHT))){
      dirH=0;
    }
  }
}

void mouseWheel(MouseEvent event){
  if(showAdviceModal){
    adviceScrollOffset += -event.getCount()*20;
  }
}

/***** 25. 功能函式 *****/
// 取代原本的 loadQuestions()
void loadProblemSetQuestions(){
  try {
    String json = fetchProblemSetJson();             // 呼叫新的 API 讀 JSON
    JSONObject root = JSONObject.parse(json);
    JSONArray rows   = root.getJSONArray("values");  // 第一列是標題
    questions.clear();
    for (int i = 1; i < rows.size(); i++){
      JSONArray row = rows.getJSONArray(i);
      Question q = new Question(
        row.getString(0),              // 題目 text
        row.getString(1),              // 難易 difficulty
        row.getString(2),              // 正確答案 answer
        new String[]{
          row.getString(3),            // 選項 A
          row.getString(4),            // 選項 B
          row.getString(5),            // 選項 C
          row.getString(6)             // 選項 D
        },
        row.size()>7 ? row.getString(7) : ""  // 圖片 URL
      );
      questions.add(q);
    }
  } catch(Exception e){
    e.printStackTrace();
  }
}


void sendForm(String nm,String acc,String pwd,int sc){
  PostRequest req = new PostRequest(FORM_URL);
  req.addHeader("Content-Type","application/x-www-form-urlencoded");
  req.addData(ENTRY_NAME, nm);
  req.addData(ENTRY_ACCOUNT, acc);
  req.addData(ENTRY_PASSWORD, pwd);
  req.addData(ENTRY_SCORE, str(sc));
  req.send();
  println("Form submitted for "+acc+": score="+sc);
}

void enterTreasure(){
  scene = Scene.TREASURE;
  countdownStartTime = millis();
}

void processPendingAnswer(){
  Question q = questions.get(qIndex);
  boolean correct = pendingSelected>-1
    && q.answer.equals(""+(char)('A'+pendingSelected));
  if(correct) correctCount++;
  float timeLeft = max(0,(TOTAL_DURATION-(millis()-countdownStartTime))/1000f);
  float pts = (correct?basePoints:0) + timeLeft * timeBonusMultiplier;
  float diff = q.difficulty.equals("簡單")
           ? easyMultiplier
           : q.difficulty.equals("中等")
           ? mediumMultiplier
           : hardMultiplier;
  totalScore += pts * diff;
  answerLog.add(new AnswerEntry(
    q.text,
    (pendingSelected==-1)?"(No answer)":""+(char)('A'+pendingSelected),
    q.answer
  ));
  qIndex++;
  selected = -1;
  pendingSelected = -1;
  scene = Scene.QUIZ;
}

void setupGameLevel(){
  int bgIndex = (int)random(mapFiles.length);
  bg = loadImage(mapFiles[bgIndex]);
  bg.resize(width, height);

  isInvisible = false;
  player = new PlayerCharacter("player_2.png",375,700,46.2,77.4);
  enemies = new ArrayList<>();
  int level = qIndex+1;
  int num   = min(2+level,4);
  for(int i=0; i<num; i++){
    float y = random(100, height-150);
// 隨機挑一張 monster_X.png
int idx = (int)random(monsterFiles.length);
String imgPath = monsterFiles[idx];
enemies.add(
  new EnemyCharacter(imgPath, random(0, width-40), y, 50, 50)
);

  }
  treasure  = new GameObject("treasure.png",375,50,50,50);
  dirV=dirH=0;
  levelSpeed = 1 + level*0.1f;
}

// 25a. 過場打字機效果用
String[] transitionTexts = {
  "巴拉圭的國旗正反面圖案不同，十分罕見！",
  "在巴拉圭，有人使用木頭當作正式貨幣過！",
  "巴拉圭擁有世界最大水力發電廠之一──伊泰普水壩。",
  "巴拉圭的交通中，牛車在農村仍然常見。",
  "巴拉圭曾是南美洲最早施行全民免費教育的國家之一。",
  "巴拉圭的國鳥是鐘聲鳥（Bellbird），叫聲清脆響亮。",
  "當地有種傳統樂器叫阿爾帕（Arpa），是一種南美豎琴。",
  "巴拉圭的舊首都曾經是恩卡納西翁（Encarnación）。",
  "巴拉圭擁有豐富的濕地與草原生態，是候鳥的天堂。",
  "巴拉圭的貨幣單位是瓜拉尼，命名自原住民族。"
};

String transitionText;      // 目前要顯示的文字
int transitionIndex = 0;  // 用來輪播，也可以改成隨機

int    displayedChars     = 0;
int    charInterval       = 100;    // 每個字間隔 100 ms
long   transitionStart    = 0;
long   typeFinishedTime   = 0;
boolean typeDone          = false;


/***** 26. 呼叫 Gemini 產生建議 *****/
void generateAdvice(){
  if(answerLog.isEmpty()) return;
  StringBuilder sb = new StringBuilder();
  sb.append(
    "以下內容是繁體中文，請直接理解中文後給作答的學生建議，"
  + "不要使用 markdown，請用一段話直接說，你是友善的老師，"
  + "可以提供具體建議以及教學和補充說明，讓學生可以學習：\n\n"
  );
  for(int i=0; i<answerLog.size() && i<questions.size(); i++){
    AnswerEntry a = answerLog.get(i);
    Question     q = questions.get(i);
    sb.append((i+1)+". Q: "+a.qText+"\n");
    for(int j=0; j<4; j++){
      sb.append("   "+(char)('A'+j)+": "+q.opts[j]+"\n");
    }
    sb.append("   Answered: "+a.selected+" | Correct: "+a.correct+"\n");
  }
  String prompt = sb.toString();
  // build JSON payload
  JSONObject payload  = new JSONObject();
  JSONArray  contents = new JSONArray();
  JSONObject firstMsg = new JSONObject();
  JSONArray  parts    = new JSONArray();
  JSONObject part     = new JSONObject();
  part.setString("text",prompt);
  parts.append(part);
  firstMsg.setJSONArray("parts",parts);
  contents.append(firstMsg);
  payload.setJSONArray("contents",contents);
  String jsonString = payload.toString();
  println("=== LLM Prompt ===");
  println(prompt);
  println("=== JSON Payload ===");
  println(jsonString);
  // HTTP POST
  try {
    URL url = new URL(LLM_URL);
    HttpURLConnection conn = (HttpURLConnection)url.openConnection();
    conn.setRequestMethod("POST");
    conn.setRequestProperty("Content-Type","application/json; charset=UTF-8");
    conn.setDoOutput(true);
    OutputStreamWriter osw = new OutputStreamWriter(
      conn.getOutputStream(),"UTF-8"
    );
    osw.write(jsonString);
    osw.flush();
    osw.close();
    int status = conn.getResponseCode();
    BufferedReader br = new BufferedReader(
      new InputStreamReader(
        status>=200&&status<300
        ? conn.getInputStream()
        : conn.getErrorStream(),
        "UTF-8"
      )
    );
    StringBuilder response = new StringBuilder();
    String line;
    while((line=br.readLine())!=null) response.append(line);
    br.close(); conn.disconnect();
    // parse JSON
    JSONObject obj = JSONObject.parse(response.toString());
    JSONArray candidates = obj.getJSONArray("candidates");
    if(candidates!=null && candidates.size()>0){
      JSONObject cand    = candidates.getJSONObject(0);
      JSONObject content = cand.getJSONObject("content");
      JSONArray candParts = content.getJSONArray("parts");
      if(candParts!=null && candParts.size()>0){
        adviceText = candParts.getJSONObject(0).getString("text");
      }
    }
  } catch(Exception e){
    adviceText = "(LLM request failed: "+e.getMessage()+")";
    e.printStackTrace();
  }
}

/***** 工具函式 *****/
int safeInt(String s){
  try { return int(Float.parseFloat(s.trim())); }
  catch(Exception e){ return 0; }
}
