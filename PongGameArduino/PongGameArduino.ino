
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
#include <ArduinoUnit.h>

/**************************************
* CONSTANTS
***************************************/
const int FORWARD = HIGH;
const int REVERSE = LOW;
const int ROTATION_THRESHOLD = 700;
const int READINGS = 10;

// Debug Comments
const boolean DEBUG_POSITION_CORRECTION = true;
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

int loopCount;

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
   
   // Initialize motor 
   analogWrite(pwmPinA, 0);     // set to not be spinning (0/255)
   digitalWrite(dirPinA, LOW);  // set direction
  
   // Reset all sensor readings to initial sensor value
   for(int i=0; i<READINGS; i++){
      readings[i] = initialPosition; 
   }
 
   loopCount = 0;
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
}

/**
* checks for serial communication 
* from processing. Runs after every loop()
* if serial data waiting.
*/
void serialEvent()
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
* Takes the raw MR sensor readings and corrects
* the value, accounting for flips of the motor wheel
* and the initial handle position
*/
int correctPosition()
{
    //calculate differences between MR sensor readings
    //difference btwn current raw position and last raw position
  int diff; 
    
   // Find the difference between the last two MR sensor readings:
  if(readingIndex > 0){
    diff = readings[readingIndex] - readings[readingIndex - 1];
  }else{
    diff = readings[readingIndex] - readings[READINGS - 1];
  }
  
  // Checks for a rotation of the motor wheel:
  if(!recentRotation){
     updateSensorRotations(diff); 
  }else{
     recentRotation = false; 
  }
  
  // Set handle starting position to be 0:
  long correction = readings[readingIndex] - initialPosition;
  // Account for 'flips' or 'rotations' that have occurred:
  correctedPosition = correction + (1000*sensorRotations);
  
  correctedPosition = convertToMetres();
  
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
* TODO: convert the corrected position
* to be in metres, using the calibration
* data and kinematic parameters. 
*
*/
int convertToMetres()
{
  return correctedPosition; 
}


/**
* Determines if the difference between 
* the last two sensor readins, 'diff', 
* is large enough to indicate a flip of 
* the motor wheel. If so, update the rotation
* counter. 
*/
void updateSensorRotations(int diff)
{  
  if(diff <= -ROTATION_THRESHOLD){
    sensorRotations++;
    Serial.println("SwitchForwards");
    recentRotation = true;
  }
  
  if(diff >= ROTATION_THRESHOLD){
    sensorRotations--;
    Serial.println("SwitchReverse");
    recentRotation = true;
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
*  Outputs the corrected position 
*  for use in Processing
*/
void sendDataToProcessing()
{
  Serial.println(correctedPosition);
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
