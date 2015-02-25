
/**************************************
* PongGame
*
* A re-factored version of pong for arduino & hapkit
*
* Author: Gordon Minaker 
*         gminaker@cs.ubc.ca
*
*/

#include <math.h>

/**************************************
* CONSTANTS
***************************************/
const int FORWARD = HIGH;
const int REVERSE = LOW;
const int ROTATION_THRESHOLD = 700;
const int READINGS = 10;

// Debug Comments
const boolean DEBUG_POSITION_CORRECTION = false;
const boolean DEBUG_MOTOR_OUTPUT = false;

// Kinematic Parameters
const double lx = 0.065659;   //[m]
const double rp = 0.004191;   //[m]
const double rs = 0.073152;   //[m]
const double motorcalibration =  0.03;

// PIN DEFINITIONS
const int pwmPinA = 5;    // Motor Power (Output) 
const int dirPinA = 8;    // Motor Direction (Input)
const int posPinA = A2;   // Read MR Sensor (Input)

/**************************************
* VARIABLES
***************************************/

int initialPosition;
double correctedPosition;

int readings[READINGS];
int readingIndex;

int sensorRotations;
boolean recentRotation;

boolean hapticFeedback;
boolean rateControl;

/**************************************
* FUNCTIONS
***************************************/

/**
* runs once after each powerup or reset
* of the arduino board. Initializes ports. 
*
*/
void setup()
{
   // Adjust PWM Frequency for motor 
   setPwmFrequency(pwmPinA,1);
  
   // Initialize Serial Communication
   Serial.begin(9600);  
  
   // Declare Input & Output Pins
   pinMode(posPinA, INPUT);
   pinMode(dirPinA, OUTPUT);
   pinMode(pwmPinA, OUTPUT);
   
   // Initial position sensor reading
   initialPosition = analogRead(posPinA);
   correctedPosition = 0;
  
   // Reset all sensor readings to initial sensor value
   for(int i=0; i<READINGS; i++){
      readings[i] = initialPosition; 
   }
 
   sensorRotations = 0;
   readingIndex = 0;
   hapticFeedback = true;
}

/**
* Main loop function
* after every loop, serialEvent()
* is also called automatically.
*
*/
void loop()
{  
   readSensor();
   correctPosition();
   adjustMotorOutput();
   sendDataToProcessing();
   checkInputFromProcessing();
}

/**
* checks for serial communication 
* from processing. Runs after every loop()
* TODO: Update this to read proper inputs. 
*/
void checkInputFromProcessing()
{
  while (Serial.available())
  {
    char in = (char)Serial.read();
    Serial.println(in);
    byte val, b;
    
    if (in == 'f') 
    {
      val = Serial.read();
      if(val == 0){
        hapticFeedback = false;
      }else if(val == 1){
        hapticFeedback = true;
      }
    }
  } 
}

/**
* Reads sensor input values into 
* array, updates index value.
*
*/
void readSensor()
{
  readingIndex++;
  
  if(readingIndex >= 10){
   readingIndex = 0; 
  }
  
  readings[readingIndex] = analogRead(posPinA);
}


/**
*
*/
int correctPosition()
{
    //calculate differences between MR sensor readings
    //difference btwn current raw position and last raw position
  int diff; 
    
  if(readingIndex > 0){
    diff = readings[readingIndex] - readings[readingIndex - 1];
  }else{
    diff = readings[readingIndex] - readings[READINGS - 1];
  }
  
  if(!recentRotation){
     updateSensorRotations(diff); 
  }else{
     recentRotation = false; 
  }
  
  long correction = readings[readingIndex] - initialPosition;
  correctedPosition = correction + (1000*sensorRotations);
  
  if(DEBUG_POSITION_CORRECTION)
  {
    Serial.print("raw:");
    Serial.print(readings[readingIndex]);
    Serial.print(" corr:");
    Serial.print(correctedPosition);
    Serial.print("\n"); 
  }
  
}

/**
*
*/
void updateSensorRotations(int diff)
{  
  if(diff <= -ROTATION_THRESHOLD){
    sensorRotations++;
    recentRotation = true;
    //Serial.println("SwitchForwards");
  }
  
  if(diff >= ROTATION_THRESHOLD){
    sensorRotations--;
    recentRotation = true;
    //Serial.println("SwitchReverse");
  }
}

/**
* adjusts motor output based on 
* corrected position value.
*
*/
void adjustMotorOutput()
{

  float motorOutput;
  double force = correctedPosition / 1000;
  
  if(DEBUG_MOTOR_OUTPUT)
  {
    Serial.print("X:");
    Serial.print(correctedPosition);
    Serial.print("Force:");
    Serial.print(force);
    Serial.print("\n");
  }
  
  if(force > 0) {
    digitalWrite(dirPinA, REVERSE);
  } else {
    digitalWrite(dirPinA, FORWARD);
  } 

  force = abs(force);  
  
  double Tm = rp/rs * lx * force;        
  double duty = sqrt(Tm/motorcalibration);   
  
  duty = min(duty, .95);
  duty = max(duty, 0);
  
  if(hapticFeedback){
    motorOutput = (int)(duty * 255); 
  }else{
    motorOutput = 0;
  }
  
  analogWrite(pwmPinA, motorOutput);
  
  if(DEBUG_MOTOR_OUTPUT)
  {
    Serial.print("\n"); 
    Serial.print("m:");
    Serial.print(motorOutput); 
    Serial.print("\n"); 
  }
   
}


/**
*
*/
void sendDataToProcessing()
{
  int temp = map(correctedPosition, -4500, 4500, -500, 500);
  Serial.println(temp);
}

/**
 * Adjusts the PWM frequency for motor output.
 * This function will have side-effects that 
 * could affect the accuracy of timers in the 
 * program.
 *
 * This code snippet was taken from Arduino's
 * website: 
 * http://playground.arduino.cc/Code/PwmFrequency
 *
 */  
void setPwmFrequency(int pin, int divisor) {
  byte mode;
  if(pin == 5 || pin == 6 || pin == 9 || pin == 10) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 64: mode = 0x03; break;
      case 256: mode = 0x04; break;
      case 1024: mode = 0x05; break;
      default: return;
    }
    if(pin == 5 || pin == 6) {
      TCCR0B = TCCR0B & 0b11111000 | mode;
    } else {
      TCCR1B = TCCR1B & 0b11111000 | mode;
    }
  } else if(pin == 3 || pin == 11) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 32: mode = 0x03; break;
      case 64: mode = 0x04; break;
      case 128: mode = 0x05; break;
      case 256: mode = 0x06; break;
      case 1024: mode = 0x7; break;
      default: return;
    }
    TCCR2B = TCCR2B & 0b11111000 | mode;
  }
}
