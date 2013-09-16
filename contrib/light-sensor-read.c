// Load it up onto your arduino with the Arduino SDK.
void setup() {
  Serial.begin(9600);  // Default baud rate.
}

void loop() {
  Serial.println(analogRead(0));  // Pin number
  delay(1000);
}

