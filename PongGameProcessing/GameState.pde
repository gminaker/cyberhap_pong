int gameStage = 0; 
Canvas Dialog;

void StateChange()
{
 switch(gameStage)
 {
   case 0:
     SimplePlay();
     prevButton.hide();
     break;
   case 1:
     Pt();
     break;
   case 2:
     PtVtPc();
     break;
   case 3:
     Notice1();
     break;
   case 4:
     VtVc();
     break;
   case 5:
     PtVtVc();
     nextButton.show();
     break;
   case 6:
     PtVtVcVg();
     nextButton.hide();
     break;
 }  
}

/**
* Remove all control elements
*/
void SimplePlay()
{
  radioHapticFeedback.hide();
  radioRatePosition.hide();
  radioHapticFeedback.hide();
  sliderCp.hide();
  sliderCv.hide();
  cp5.removeCanvas(canvasVelocityTime);
  cp5.removeCanvas(canvasPositionTime);
}

/**
* Show only position/time graph, 
* under position control, 
* with haptics on, 
* no gain
*/
void Pt()
{
  radioHapticFeedback.show();
  radioRatePosition.show();
  radioHapticFeedback.show();
  cp5.removeCanvas(canvasPositionTime);
  cp5.removeCanvas(canvasVelocityTime);
  cp5.addCanvas(canvasPositionTime);
  prevButton.show();
}

/**
* Show position/time graph, 
* show velocity/time graph,
* under position control, 
* with haptics on, 
* no gain
*/
void PtVtPc()
{
  cp5.removeCanvas(canvasPositionTime);
  cp5.removeCanvas(canvasVelocityTime);
  cp5.removeCanvas(Dialog);
  cp5.addCanvas(canvasPositionTime);
  cp5.addCanvas(canvasVelocityTime);
}

/**
* show velocity/time graph,
* under veocity control, 
* with haptics on, 
* no gain
*/
void VtVc()
{
  cp5.removeCanvas(Dialog);
  radioRatePosition.activate(1);
  rateControl = true;
  sliderCv.hide();
  cp5.removeCanvas(canvasPositionTime);
}

/**
* Show position/time graph,
* show velocity/time graph,
* under veocity control, 
* with haptics on, 
* no gain
*/
void PtVtVc()
{
  PtVtPc();
  radioRatePosition.activate(1);
  rateControl = true;
  sliderCv.hide();
}

/**
* Show position/time graph,
* show velocity/time graph,
* under veocity control, 
* with haptics on, 
* no gain
*/
void PtVtVcVg()
{
  radioRatePosition.activate(1);
  rateControl = true;
  sliderCv.show();
}

/**
* Overlay a notice onto the 
* screen explaining what students
* are about to do next. 
*/
void Notice1()
{
  String Title = "Understanding Checkpoint:";
  String Message = "So far, the paddle has been under position control. Now let\'s try velocity control.";
  Dialog = new DialogBox(WIDTH*0.02, HEIGHT*0.05, int(WIDTH*0.96), int(HEIGHT*0.85), Title, Message);
  Dialog.post();
  cp5.addCanvas(Dialog);
}

/**
* Class for generating position/time and velocity/time graphs
* on display. 
*
*/
class DialogBox extends Canvas {
  float x;
  float y;
  int cwidth;
  int cheight;
  String title;
  String message;
  
  
  DialogBox(float xin, float yin, int w, int h, String titlein, String messagein){
    x = xin;
    y = yin;
    cwidth = w;
    cheight = h;
    title = titlein;
    message = messagein;
  }

  public void setup(PApplet theApplet) {

  }  

  public void draw(PApplet p) {
    
    p.fill(50, 250);
    //p.stroke(255);
    p.rect(x, y, cwidth, cheight);
    p.fill(255);
    p.textSize(20);
    p.text(title, x+10, y+(cheight/3));
    p.textSize(16);
    p.text(message, x+10, y+(cheight/2));
  }
}
