
/**************************************
* PongV1
*
* First version of pong for arduino & hapkit
*
* Original Author : Oliver Schneider
*
* Revisions By: Gordon Minaker
*
*/

import controlP5.*;
import processing.serial.*;
import ddf.minim.*;

//sounds
Minim minim;
AudioPlayer toc;

// input widgets
ControlP5 cp5;
RadioButton radioRatePosition;
RadioButton radioHapticFeedback;
Slider sliderCp;
Slider sliderCv;
Canvas canvasPositionTime;
Canvas canvasVelocityTime;

//constants
int PADDLE_WIDTH = 15;
int PADDLE_HEIGHT = 100;
int BALL_RADIUS = 10;
int BALL_DIAMETER = BALL_RADIUS*2;
int WIDTH = 800;
int HEIGHT = 600;
int DEFAULT_BALL_V = 350;//px per s
int COMPUTER_V = 300; //px per s, make this SLOWER THAN THE BALL
int player_x = 50;
int computer_x = WIDTH-50-PADDLE_WIDTH;
int SCORE_FROM_MIDDLE = 150;

//variables
int ball_x, ball_y, player_y, computer_y;
int ball_vx = DEFAULT_BALL_V;
int ball_vy = DEFAULT_BALL_V;
int player_score = 0;
int computer_score =0;
int twiddlerPosition = 0;
boolean paused = true;
int last_time = 0;

// if rateControl is false, 
// inherently set to position control.
boolean rateControl = false;
boolean hapticFeedback = false;
double position_gain = 0.0;
double velocity_gain = 0.0;

//serialports 
// Arduino board serial port index, machine-dependent:
int serialPortIndex = 4;
int SERIAL_WRITE_LENGTH = 32;
Serial myPort;


void setup()
{
  size(WIDTH,HEIGHT);
  frameRate(30);
  myPort = new Serial(this, Serial.list()[serialPortIndex], 9600);
  
  myPort.bufferUntil('\n');
  
  //for sounds
  minim = new Minim(this);
  toc = minim.loadFile("toc.wav");
  
  randomSeed(millis());
  
  cp5 = new ControlP5(this);
  addInputWidgets();
  InitializeGame();
  
  updateHapKitBoolean('f',hapticFeedback);
  
}


void draw() {
  background(255);
  fill(0, 0, 0);
  stroke(0,0,255);
  
  UpdateGame();
  DrawGame();
}

public void updateHapKitBoolean(char updateType, Boolean bool)
{
    myPort.write(updateType);
    if(bool){
      myPort.write(1);
    }else{
      myPort.write(0);
    }
}

void addInputWidgets(){
  radioRatePosition = cp5.addRadioButton("Control By:")
                         .setPosition(WIDTH*0.05, HEIGHT*0.05)
                         .setSize(20,20)
                         .setColorForeground(color(255))
                         .setColorActive(color(255))
                         .setColorLabel(color(255))
                         .setItemsPerRow(1)
                         .setSpacingColumn(50)
                         .addItem("Position Control",1)
                         .addItem("Velocity Control",2)
                         .setNoneSelectedAllowed(false)
                         .activate(0);
                         
   radioHapticFeedback = cp5.addRadioButton("Haptic Feedback")
                         .setPosition(WIDTH*0.45, HEIGHT*0.05)
                         .setSize(20,20)
                         .setColorForeground(color(120))
                         .setColorActive(color(255))
                         .setColorLabel(color(255))
                         .setItemsPerRow(1)
                         .setSpacingColumn(50)
                         .addItem("Haptics On",1)
                         .addItem("Haptics Off",2)
                         .setNoneSelectedAllowed(false)
                         .activate(0);
                         
    sliderCp = cp5.addSlider("Position Gain")
                  .setPosition(WIDTH*0.2, HEIGHT*0.06)
                  .setRange(0,1);
                  
    sliderCv = cp5.addSlider("Velocity Gain")
                  .setPosition(WIDTH*0.2, HEIGHT*0.09)
                  .setRange(0,1);
                        
    canvasPositionTime = new Graph(WIDTH*0.57, HEIGHT*0.05, "Position / Time");
    canvasPositionTime.pre(); // use cc.post(); to draw on top of existing controllers.
    cp5.addCanvas(canvasPositionTime);
    
    canvasVelocityTime = new Graph(WIDTH*0.78, HEIGHT*0.05, "Velocity / Time");
    canvasVelocityTime.pre(); // use cc.post(); to draw on top of existing controllers.
    cp5.addCanvas(canvasVelocityTime);
}


/*
  Detailed functions
*/

/**
* TODO: Test This 
*/
void controlEvent(ControlEvent theEvent) {
  if(theEvent.isFrom(radioRatePosition)) {
    if(theEvent.getValue() == 1){
      rateControl = false; 
    }else if(theEvent.getValue() == 2){
      rateControl = true;
    }
  }else if(theEvent.isFrom(radioHapticFeedback)){
    if(theEvent.getValue() == 1){
      hapticFeedback = true; 
    }else if(theEvent.getValue() == 2){
      hapticFeedback = false;
    }
    updateHapKitBoolean('f', hapticFeedback);
  }
}


void InitializeGame()
{
  paused = true;
  ball_x = (int)random(WIDTH/4, WIDTH*3/4);
  ball_y = (int)random(HEIGHT/4, HEIGHT*3/4);;
  ball_vx = DEFAULT_BALL_V;
  ball_vy = DEFAULT_BALL_V;
  computer_y = ball_y - PADDLE_HEIGHT/2;
  last_time = millis();
}

void UpdateGame()
{
   int t = millis();
   int dt = t - last_time;
   
   updatePlayerPaddle();
      
  if (!paused)
  {
    //NOTE: This collision detection is EXTREMELY RUDIMENTARY
    //and relies on small time steps.
     checkBallHitWall();
     checkBallHitPaddle();
     checkWinConditions();
     updateBallPosition(dt);
     updateComputerPlayerPosition(dt);
   }
   last_time = t;
}

/**
* Updates the player's paddle position
*/
void updatePlayerPaddle(){
  
  int bottom_screen = HEIGHT-PADDLE_HEIGHT;
  int top_screen = 0;
  int mid_screen = (HEIGHT/2)-(PADDLE_HEIGHT/2);
  double gain;
  int correctedTwiddlerPos;
  int new_position;
  
  if(rateControl){
    int velocity;
    
    gain = 0.03;
    correctedTwiddlerPos = (int)(twiddlerPosition*gain);
    velocity = correctedTwiddlerPos;
    new_position = (player_y - mid_screen) + velocity;
  }else{
    gain = 0.3;
    correctedTwiddlerPos = (int)(twiddlerPosition*gain);
    new_position = correctedTwiddlerPos;
  }
  
   player_y = min(bottom_screen, 
                max(top_screen, 
                    mid_screen+new_position)); 
                    
}

/**
*
*/
void updateBallPosition(int dt)
{
    //1000.0 to convert ms -> s 
   ball_x += (int)(ball_vx * dt/1000.0); 
   ball_y += (int)(ball_vy * dt/1000.0);  
}

/**
* Determine if the ball has hit the wall, 
* if it has, update yvelocity of ball.
*/
void checkBallHitWall()
{
 if (ball_y < 0 || ball_y > HEIGHT)
     {
       ball_vy *= -1;
     } 
}

/**
*  Determines if the ball has hit a paddle, 
*  and updates program accordingly.
*/
void checkBallHitPaddle()
{
      //ball hitting paddles
     if (ball_x - BALL_RADIUS  < player_x + PADDLE_WIDTH && ball_x + BALL_RADIUS > player_x
         && ball_y - BALL_RADIUS < player_y + PADDLE_HEIGHT && ball_y +BALL_RADIUS > player_y)
       {
              ball_vx *= -1;
              toc.play(0); //0 means start at position 0
       }
       else if (ball_x - BALL_RADIUS  < computer_x + PADDLE_WIDTH && ball_x + BALL_RADIUS > computer_x
         && ball_y - BALL_RADIUS < computer_y + PADDLE_HEIGHT && ball_y +BALL_RADIUS > computer_y)
       {
              ball_vx *= -1;
              toc.play(0); //0 means start at position 0
       } 
}

/**
* Updates the x and y position of 
* the computer player's paddle
*/
void updateComputerPlayerPosition(int dt)
{
      int computer_v = COMPUTER_V;
      if (ball_y < computer_y + PADDLE_HEIGHT/2)
      {
        computer_v *= -1;
      }
      computer_y = min(HEIGHT-PADDLE_HEIGHT, max(0, computer_y+(int)(computer_v * dt/1000.0)));
}

/**
* Checks Position of ball to determine if 
* a player has won.
*/
void checkWinConditions(){
  
     if (ball_x + BALL_RADIUS < 0)
     {
       //computer point
       computer_score++;
       InitializeGame();
     } else if (ball_x - BALL_RADIUS > WIDTH)
     {
       //player point
       player_score++;
       InitializeGame();
     } 
}


void mousePressed()
{
  paused = !paused;
}

void serialEvent(Serial port) 
{
    String inString = "";
    
    while(myPort.available() > 0)
    {
      inString = myPort.readStringUntil('\n');
    }
    
    if (inString != null)
    {
       try {
        
        String[] list = split(inString, ',');
        
        String xString = trim(list[0]);                // trim off whitespaces.
        int xByte = int(xString);           // convert to a number.
        
        //println(xByte);
        
        if(!Float.isNaN(xByte) && xByte != 0){
          int updatedX = (int)map(xByte, -400, 400, -1000, 1000);
          twiddlerPosition = updatedX;
        }       
       } finally {}
    
     }
}


void DrawGame()
{
  background(0); //black bg
  
  fill(255); //white fill
  stroke(255);  //white stroke
  
  ellipse(ball_x, ball_y, BALL_DIAMETER, BALL_DIAMETER);
  
  textSize(36);
  text(player_score, WIDTH/2-SCORE_FROM_MIDDLE, HEIGHT/2);
  text(computer_score, WIDTH/2+SCORE_FROM_MIDDLE, HEIGHT/2);
  
  if (paused)
  {
    text("CLICK TO PLAY", WIDTH/2-150, HEIGHT*7/8);
  }
 
  rect(player_x, player_y, PADDLE_WIDTH, PADDLE_HEIGHT);
  rect(computer_x, computer_y, PADDLE_WIDTH, PADDLE_HEIGHT); 
  
}

/**
* Class for generating position/time and velocity/time graphs
* on display. 
*
*/
class Graph extends Canvas {

  int count;
  float x;
  float y;
  int cwidth;
  int cheight;
  String title;
  int[] plot;
  ArrayList<float[]> plots;
  
  boolean reachedMaxX;
  
  
  Graph(float xin, float yin, String titlein){
    x = xin;
    y = yin;
    title = titlein;
    plots = new ArrayList<float[]>(); 
    reachedMaxX = false;
  }

  public void setup(PApplet theApplet) {
    count = 0;
    cwidth = 150;
    cheight = 100;
  }  

  public void draw(PApplet p) {
    
    p.fill(100);
    p.stroke(255);
    p.rect(x, y, cwidth, cheight);
    p.fill(255);
    p.textSize(12);
    p.text(title, x+2, y+20);
    
    plotGraph(p);
    
    
    count++;
  }
  
  void plotGraph(PApplet p){
    
    if(x+count >= x+cwidth){
       reachedMaxX = true;
    }
    
    if(reachedMaxX){
     plots.remove(0); 
     
     for(int i=0; i < plots.size() ;i++){
        float[] plot = {plots.get(i)[0]-1, plots.get(i)[1]};
        plots.set(i, plot);
     }
    }
    
    float correctedy = map(twiddlerPosition, -4500, 4500, -cheight, cheight);
    float[] plot = {min(x+count, x+cwidth), min(y+cheight, max(y, y+(cheight/2)+correctedy))};
    plots.add(plot);
   
    if(plots.size() >1){
      for(int i=1; i < plots.size() ;i++){
        p.line(plots.get(i-1)[0],  plots.get(i-1)[1], plots.get(i)[0],  plots.get(i)[1]);
      }
    }
  }

}

