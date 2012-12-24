#include <ctype.h>
#include <ShiftRegLCD.h>
#include <Button.h>
#include <Keypad.h>
#include <EEPROM.h>

//#define TEST
//#define EVENTS_LOG_ENABLED
//#define LANG_UKR

#if defined(ARDUINO) && (ARDUINO < 19)
// copied from WProgram.h
#if defined(__AVR_ATmega1280__) || defined(__AVR_ATmega2560__)
const static uint8_t A0 = 54;
const static uint8_t A1 = 55;
const static uint8_t A2 = 56;
const static uint8_t A3 = 57;
const static uint8_t A4 = 58;
const static uint8_t A5 = 59;
const static uint8_t A6 = 60;
const static uint8_t A7 = 61;
const static uint8_t A8 = 62;
const static uint8_t A9 = 63;
const static uint8_t A10 = 64;
const static uint8_t A11 = 65;
const static uint8_t A12 = 66;
const static uint8_t A13 = 67;
const static uint8_t A14 = 68;
const static uint8_t A15 = 69;
#else
const static uint8_t A0 = 14;
const static uint8_t A1 = 15;
const static uint8_t A2 = 16;
const static uint8_t A3 = 17;
const static uint8_t A4 = 18;
const static uint8_t A5 = 19;
const static uint8_t A6 = 20;
const static uint8_t A7 = 21;
#endif
#endif

#define BoolToHighLow(val) (val ?  HIGH : LOW)

const static byte PIN_BAD = 0xFF;
// Keypad pins
const static byte PinKeypad_Col0 = 3;
const static byte PinKeypad_Col1 = 4;
const static byte PinKeypad_Col2 = 5;
const static byte PinKeypad_Col3 = 6;
const static byte PinKeypad_Row0 = 7;
const static byte PinKeypad_Row1 = 8;
const static byte PinKeypad_Row2 = 9;
const static byte PinKeypad_Row3 = 10;
// ShiftRegLCD pins
const static uint8_t PinLCD_Backlight = 13;
const static uint8_t PinLCD_Data = 12;
const static uint8_t PinLCD_Clock = 11;
// Alarm pins
const static byte PinAlarm_Out = A0;
const static byte PinAlarm_In = A1;
const static byte PinAlarm_Tamper = A2;
const static byte PinLed = A3;
const static byte PinFire = A4; //PIN_BAD;
const static byte PinBuzzer = 2;
//const static byte PinGSM_TX = 1;
//const static byte PinGSM_RX = 0;

const static byte SettingsMagic = 0x11;
const static byte PasswordLength_Max = 17;
struct AlarmSettings
{
  byte magic;
  char alarmPassword1[PasswordLength_Max];
//  char alarmPassword2[PasswordLength_Max];
//  char alarmPassword3[PasswordLength_Max];
//  char alarmPassword4[PasswordLength_Max];
  char menuPassword[PasswordLength_Max];
  unsigned int keypadDebounceTime;
  unsigned int lcdBacklightTime;
  unsigned int beforeTurnOnDelay;
  unsigned int beforeAlarmDelay;
  unsigned int alarmOutMask;
  unsigned int alarmInMask;
  unsigned int alarmTamperMask;
  unsigned int alarmFireMask;
  unsigned int alarmStatOutCount;
  unsigned int alarmStatInCount;
  unsigned int alarmStatTamperCount;
  unsigned int alarmStatFireCount;
}
settings =
{
  SettingsMagic, // magic
  "1111", // alarmPassword1,
//  "1111", // alarmPassword2,
//  "1111", // alarmPassword3,
//  "1111", // alarmPassword4,
  "0000", // menuPassword
  80,     // keypadDebounceTime
  60000,  // lcdBacklightTime
  30000,   // beforeTurnOnDelay
  15000,   // beforeAlarmDelay
  0xFFFFFFFF, // alarmOutMask - all outputs are enabled
  0xFFFFFFFF, // alarmInMask - all inputs are enabled
  0xFFFFFFFF, // alarmTamperMask - all tampers are enabled
  0xFFFFFFFF, // alarmFireMask - all fire inputs are enabled
  0, // alarmStatOutCount
  0, // alarmStatInCount
  0, // alarmStatTamperCount
  0, // alarmFireCount
};

void saveSettings(void)
{
  byte* p = (byte*)&settings;
  for (int i = 0; i < sizeof(AlarmSettings); i++)
    EEPROM.write(i, p[i]);
};

void loadSettings(void)
{
  byte magic = EEPROM.read(0);
  if (magic != SettingsMagic)
  {
    saveSettings();
    return;
  }

  byte* p = (byte*)&settings;
  for (int i = 0; i < sizeof(AlarmSettings); i++)
    p[i] = EEPROM.read(i);
};

/////////////////// ShiftRegLCDExt /////////////////// 

class ShiftRegLCDExt: public ShiftRegLCD
{
  private:
    const uint8_t pinBacklight;
  public:
    ShiftRegLCDExt(uint8_t srdata, uint8_t srclock, uint8_t srbacklight, uint8_t enable, uint8_t lines);

    unsigned long lcdBacklightOnTime;

    void setBacklight(bool on);
    void setBacklightOn();
    void printn(char ch, int n);
};

ShiftRegLCDExt::ShiftRegLCDExt(uint8_t srdata, uint8_t srclock, uint8_t srbacklight, uint8_t enable, uint8_t lines)
  : ShiftRegLCD(srdata, srclock, enable, lines), pinBacklight(srbacklight), lcdBacklightOnTime(0)
{
  pinMode(pinBacklight, OUTPUT);
  #ifdef LANG_UKR
  static const uint8_t ch_d[8]  = {14, 10, 10, 10, 10, 31, 17, 0};
  static const uint8_t ch_ya[8] = {15, 17, 17, 15, 9, 9, 17, 0};
  static const uint8_t ch_sh[8] = {17, 17, 21, 21, 21, 21, 31, 0};
  static const uint8_t ch_l[8]  = {15, 9, 9, 9, 9, 9, 17, 0};
  static const uint8_t ch_uj[8] = {6, 17, 19, 21, 25, 17, 17, 0};

  createChar(1, ch_d);
  createChar(2, ch_ya);
  createChar(3, ch_sh);
  createChar(4, ch_l);
  createChar(5, ch_uj);
  #endif
}

void ShiftRegLCDExt::setBacklight(bool on)
{
  digitalWrite(pinBacklight, BoolToHighLow(on));
}

void ShiftRegLCDExt::setBacklightOn()
{
  setBacklight(true);
  lcdBacklightOnTime = millis();
}

void ShiftRegLCDExt::printn(char ch, int n)
{
  for (int i = 0; i < n; i++)
    print(ch);
}

/////////////////// ShiftRegLCDExt ///////////////////

// LCD Init
ShiftRegLCDExt lcd(PinLCD_Data, PinLCD_Clock, PinLCD_Backlight, TWO_WIRE, 2 /* lines */);

/////////////////// KeypadExt ///////////////////

class KeypadExt: public Keypad
{
  public:
    const static char KeyMenu = 'a';
    const static char KeyEnter = 'd';
    const static char KeyBackspace = 'c';
    const static char KeyEsc = 'b';
    const static char KeyLeft = '*';
    const static char KeyRight = '#';
  private:
    const static int bufferLenMax = 16;
    char buffer[bufferLenMax + 1];
  public:
    KeypadExt(char *userKeymap, byte *row, byte *col, byte rows, byte cols);

    char getKey();
    char gets(bool onlyDigits = false);
    char* getBuffer();
    void setBuffer(const char* str);
    void clearBuffer();
};

KeypadExt::KeypadExt(char *userKeymap, byte *row, byte *col, byte rows, byte cols)
  : Keypad(userKeymap, row, col, rows, cols)
{
  clearBuffer();
}

char KeypadExt::getKey()
{
  char key = Keypad::getKey();
  if (key != NO_KEY)
    lcd.setBacklightOn();
  return key;
}

char KeypadExt::gets(bool onlyDigits)
{
  char key = getKey();
  int len = strlen(buffer);
  switch (key)
  {
    case NO_KEY:
    case KeypadExt::KeyMenu:
    case KeypadExt::KeyEnter:
    case KeypadExt::KeyEsc:
    case KeypadExt::KeyLeft:
    case KeypadExt::KeyRight:
      break;
    case KeypadExt::KeyBackspace:
      if (len > 0)
        buffer[len - 1] = '\0';
      break;
    default:
      if (onlyDigits && !isdigit(key))
        break;
      if (len < bufferLenMax)
      {
        buffer[len] = key;
        buffer[len + 1] = '\0';
      };
      break;
  }
#ifdef TEST
  if (key != NO_KEY)
  {
    Serial.print("Buffer ");
    Serial.println(buffer);
  }
#endif
  return key;
}

char* KeypadExt::getBuffer()
{
  return buffer;
}

void KeypadExt::setBuffer(const char* str)
{
  if (strlen(str) <= bufferLenMax)
    strcpy(buffer, str);
}

void KeypadExt::clearBuffer()
{
  buffer[0] = '\0';
}

/////////////////// KeypadExt ///////////////////

/////////////////// ButtonExt ///////////////////

class ButtonExt: public Button
{
  protected:
    unsigned long pressedLastTime;
    unsigned int debounceTime;
  public:
    ButtonExt(uint8_t buttonPin, uint8_t buttonMode=PULLDOWN, unsigned int _debounceTime=50);
    
    bool isPressedExt();
};

ButtonExt::ButtonExt(uint8_t buttonPin, uint8_t buttonMode, unsigned int _debounceTime)
  : Button(buttonPin, buttonMode), debounceTime(_debounceTime), pressedLastTime(0)
{
}

bool ButtonExt::isPressedExt()
{
  bool result = Button::isPressed();
return result;
  if (result || (debounceTime == 0))
  {
    pressedLastTime = 0;
    return result;
  };
  unsigned long now = millis();
  if (pressedLastTime == 0)
  {
    pressedLastTime = now;
    return false;
  }
  if (pressedLastTime > now)
  {
    if (now <= debounceTime)
      return false;
    else
      pressedLastTime = now - debounceTime;
  };
  result = ((now - pressedLastTime) <= debounceTime);
  return result;
}

/////////////////// ButtonExt ///////////////////

// Keypad init
const static byte rowsKeypad = 4;
const static byte colsKeypad = 4;
char keys[rowsKeypad][colsKeypad] = {
  {'1','2','3', 'a'},
  {'4','5','6', 'b'},
  {'7','8','9', 'c'},
  {'*','0','#', 'd'}
};

byte rowPins[rowsKeypad] = {PinKeypad_Row0, PinKeypad_Row1, PinKeypad_Row2, PinKeypad_Row3}; //connect to the row pinouts of the keypad
byte colPins[colsKeypad] = {PinKeypad_Col0, PinKeypad_Col1, PinKeypad_Col2, PinKeypad_Col3}; //connect to the column pinouts of the keypad

KeypadExt keypad = KeypadExt(makeKeymap(keys), rowPins, colPins, rowsKeypad, colsKeypad);

/////////////////// Menu ///////////////////

class MenuBase
{
  private:
    const char* name;
    bool menuActive;
  public:
    MenuBase(const char* _name)
      : name(_name)
    {
      setActive(false);
    }
    virtual void setActive(bool _active)
    {
      menuActive = _active;
    }
    bool isActive(void)
    {
      return menuActive;
    }
    const char* getName()
    {
      return name;
    }
    virtual char* getHint(void)
    {
      return "";
    }
    virtual bool process(void) = 0;
};

class MenuItemValue
{
  public:
    virtual void Load(void)
    {
      keypad.clearBuffer();
    }
    virtual bool Save(void)
    {
      return true;
    }
    char* getLastError()
    {
      return "Invalid input";
    }
};

class MenuItemUIntValue: public MenuItemValue
{
  private:
    unsigned int* value;
  public:
    MenuItemUIntValue(unsigned int* _value)
      : value(_value)
    {
    }
    virtual void Load(void)
    {
      ltoa(*value, keypad.getBuffer(), 10);
    }
    virtual bool Save(void)
    {
      *value = atol(keypad.getBuffer());
      saveSettings();
      return true;
    }
};

class MenuItemMaskValue: public MenuItemValue
{
  private:
    unsigned int* value;
  public:
    MenuItemMaskValue(unsigned int* _value)
      : value(_value)
    {
    }
    virtual void Load(void)
    {
      ltoa((*value & 1), keypad.getBuffer(), 10);
    }
    virtual bool Save(void)
    {
      *value = (atol(keypad.getBuffer()) == 0) ? 0 : 1;
      saveSettings();
      return true;
    }
};

class MenuItemStrValue: public MenuItemValue
{
  private:
    char* value;
  public:
    MenuItemStrValue(char* _value)
      : value(_value)
    {
    }
    virtual void Load(void)
    {
      keypad.setBuffer(value);
    }
    virtual bool Save(void)
    {
      strcpy(value, keypad.getBuffer());
      saveSettings();
      return true;
    }
};

class MenuItem: public MenuBase
{
  public:
    MenuItemValue* value;

    MenuItem(const char* _name, MenuItemValue* _value);

    bool process();

    void setActive(bool _active);
    char* getHint(void);
    void print(void);
};

class Menu: public MenuBase
{
  protected:
    int itemCount;
    int currIndex;
    MenuBase** items;
  public:
    Menu(const char* _name, int _index, MenuBase** _item);

    bool process();
};

MenuItem::MenuItem(const char* _name, MenuItemValue* _value)
  : MenuBase(_name), value(_value)
{
}

bool MenuItem::process()
{
  char ch = keypad.gets();
  switch (ch)
  {
    case KeypadExt::KeyEsc:
      setActive(false);
      keypad.clearBuffer();
      return true;
    case KeypadExt::KeyEnter:
      if (value->Save())
      {
        setActive(false);
        keypad.clearBuffer();
        return true;
      }
      {
        lcd.clear();
        lcd.print(value->getLastError());
        delay(2000);
        return false;
      }
  }
  if (ch != NO_KEY)
    print();
  return false;
}

void MenuItem::setActive(bool _active)
{
  MenuBase::setActive(_active);
  if(_active)
  {
    value->Load();
    lcd.cursor();
    print();
  }
  else
    lcd.noCursor();
}

char* MenuItem::getHint(void)
{
  if (!isActive())
    value->Load();
  return keypad.getBuffer();
}

void MenuItem::print(void)
{
  lcd.clear();
  lcd.print(getName());
  lcd.setCursor(0, 1);
  lcd.print(getHint());
}

Menu::Menu(const char* _name, int _itemCount, MenuBase** _items)
  : MenuBase(_name), itemCount(_itemCount), items(_items), currIndex(0)
{
}

bool Menu::process()
{
  if (isActive())
  {
    char ch = keypad.getKey();
    switch (ch)
    {
      case KeypadExt::KeyEsc:
        setActive(false);
        return true;
      case KeypadExt::KeyEnter:
        setActive(false);
        items[currIndex]->setActive(true);
        return false;
      case KeypadExt::KeyLeft:
        if (currIndex == 0)
          currIndex = itemCount - 1;
        else
          currIndex--;
        break;
      case KeypadExt::KeyRight:
        if (currIndex == (itemCount - 1))
          currIndex = 0;
        else
          currIndex++;
        break;
    }
    lcd.clear();
    lcd.print(currIndex + 1);
    lcd.print('.');
    lcd.print(items[currIndex]->getName());
    lcd.setCursor(0, 1);
    lcd.print(items[currIndex]->getHint());
    delay(100);
  }
  else
  if (items[currIndex]->process())
    setActive(true);

  return false;
}

/////////////////// Menu ///////////////////

// Menu init
MenuItemUIntValue menuDebounceTimeVal(&settings.keypadDebounceTime);
MenuItemUIntValue menuBeforeTurnOnDelayVal(&settings.beforeTurnOnDelay);
MenuItemUIntValue menuBeforeAlarmDelayVal(&settings.beforeAlarmDelay);
MenuItemUIntValue menuBacklightTimeVal(&settings.lcdBacklightTime);

MenuItemStrValue menuAlarmPasswordVal(settings.alarmPassword1);
MenuItemStrValue menuMenuPasswordVal(settings.menuPassword);

MenuItemMaskValue menuAlarmOutVal(&settings.alarmOutMask);
MenuItemMaskValue menuAlarmInVal(&settings.alarmInMask);
MenuItemMaskValue menuAlarmTamperVal(&settings.alarmTamperMask);
MenuItemMaskValue menuAlarmFireVal(&settings.alarmFireMask);

MenuItemUIntValue menuAlarmOutStatVal(&settings.alarmStatOutCount);
MenuItemUIntValue menuAlarmInStatVal(&settings.alarmStatInCount);
MenuItemUIntValue menuAlarmTamperStatVal(&settings.alarmStatTamperCount);
MenuItemUIntValue menuAlarmFireStatVal(&settings.alarmStatFireCount);

const static int menuDelayItemCount = 4;
MenuItem menuBeforeTurnOnDelay("Turn On", &menuBeforeTurnOnDelayVal);
MenuItem menuItemDelayAlarm("Alarm", &menuBeforeAlarmDelayVal);
MenuItem menuItemDelayDebounce("Key Debounce", &menuDebounceTimeVal);
MenuItem menuItemDelayBacklight("LCD backlight", &menuBacklightTimeVal);
MenuBase* menuDelayItems[menuDelayItemCount] =
{
  &menuBeforeTurnOnDelay,
  &menuItemDelayAlarm,
  &menuItemDelayDebounce,
  &menuItemDelayBacklight
};
Menu menuDelay("Delays (in ms)", menuDelayItemCount, menuDelayItems);

const static int menuPinsItemCount = 4;
MenuItem menuItemAlarmOut("Out", &menuAlarmOutVal);
MenuItem menuItemAlarmIn("In", &menuAlarmInVal);
MenuItem menuItemAlarmTamper("Tamper", &menuAlarmTamperVal);
MenuItem menuItemAlarmFire("Fire", &menuAlarmFireVal);
MenuBase* menuPinsItems[menuPinsItemCount] =
{
  &menuItemAlarmOut,
  &menuItemAlarmIn,
  &menuItemAlarmTamper,
  &menuItemAlarmFire
};
Menu menuPins("Pins mask", menuPinsItemCount, menuPinsItems);

#ifdef EVENTS_LOG_ENABLED
const static int menuPinsStatItemCount = 4;
MenuItem menuItemAlarmOutStat("Out stat", &menuAlarmOutStatVal);
MenuItem menuItemAlarmInStat("In stat", &menuAlarmInStatVal);
MenuItem menuItemAlarmTamperStat("Tamper stat", &menuAlarmTamperStatVal);
MenuItem menuItemAlarmFireStat("Fire stat", &menuAlarmFireStatVal);
MenuBase* menuPinsStatItems[menuPinsStatItemCount] =
{
  &menuItemAlarmOutStat,
  &menuItemAlarmInStat,
  &menuItemAlarmTamperStat,
  &menuItemAlarmFireStat
};
Menu menuPinsStat("Statistics", menuPinsStatItemCount, menuPinsStatItems);
#endif

const static int menuMainItemCount = 4
  #ifdef EVENTS_LOG_ENABLED
  + 1
  #endif
  ;
MenuItem menuItemPasswordAlarm("Alarm Password", &menuAlarmPasswordVal);
MenuItem menuItemPasswordMenu("Menu Password", &menuMenuPasswordVal);
MenuBase* menuMainItems[menuMainItemCount] =
{
  //&menuDateTime,
  &menuDelay,
  &menuPins,
  #ifdef EVENTS_LOG_ENABLED
  &menuPinsStat,
  #endif
  &menuItemPasswordAlarm,
  &menuItemPasswordMenu
};
Menu menu("", menuMainItemCount, menuMainItems);

/////////////////// Alarm ////////////////////////////

enum AlarmState {asBeforeArmed, asArmed, asBeforeAlarm, asAlarm, asDisarmed, asMenuPwdPromt, asMenuShow};
enum AlarmLedMode {lmOff, lmOn, lmBlink};

#ifdef LANG_UKR
const char* lcdPasswordPromt = "BBE\1ITb KO\1 ";
const char* lcdPasswordWrong = "HEBIPHU\5 KO\1";
const char* lcdBeforeArmMsg1 = "\1O BBIMKHEH\2";
const char* lcdBeforeArmMsg2 = "3A\4U\3U\4OCb ";
const char* lcdArmModeOnMsg = "BBIMKHEHO !";
const char* lcdArmModeOffMsg = "BUMKHEHO";
const char* lcdMotionDetectedMsg = "PYX";
const char* lcdFireDetectedMsg = "FIRE";
#else
const char* lcdPasswordPromt = "ENTER PASSWORD ";
const char* lcdPasswordWrong = "WRONG PASSWORD";
const char* lcdBeforeArmMsg1 = "WILL BE ARMED";
const char* lcdBeforeArmMsg2 = "IN ";
const char* lcdArmModeOnMsg = "ARMED !";
const char* lcdArmModeOffMsg = "DISARMED";
const char* lcdMotionDetectedMsg = "MOTION";
const char* lcdFireDetectedMsg = "FIRE";
#endif

const char KeyAlarmOn = KeypadExt::KeyEnter;
const char KeyAlarmOff = KeypadExt::KeyEnter;
const char KeyAlarmMenu = 'a';

class Alarm
{
  protected:
    const static unsigned int lcdPrintDelay = 250;
    const static unsigned int lcdShowInvalidPasswordMessageTime = 2500;
    const static unsigned int ledBlinkTime = 500;
    const static byte passwordLenMax = 8;

    const byte pinOut;
    const byte pinLed;
    const byte pinBuzzer;
    const byte pinTamper;
    const byte pinIn;
    const byte pinFire;

    unsigned long lcdPrintLastTime;
    unsigned long lcdShowInvalidPasswordMessageLastTime;
    unsigned long ledBlinkLastTime;
    unsigned long currStateStartTime;

    bool ledOn;
    volatile AlarmState currState;
    AlarmLedMode ledMode;
    bool showInvalidPasswordMessage;

    ButtonExt btnInput;
    ButtonExt btnTamper;
    ButtonExt btnFire;

    bool lcdCanPrint();

    bool passwordPromt(bool _showInvalidPasswordMessage);

    void setAlarm(bool on);
    void setBuzzer(bool on);
    void setLedMode(AlarmLedMode _ledMode);
    void setState(const AlarmState _newState);

    void process_BeforeArmed();
    void process_Armed();
    void process_BeforeAlarm();
    void process_Alarm();
    void process_Disarmed();
    void process_MenuPwdPromt();
    void process_MenuShow();

    void enter_BeforeArmed();
    void enter_Armed();
    void enter_BeforeAlarm();
    void enter_Alarm();
    void enter_Disarmed();
    void enter_MenuPwdPromt();
    void enter_MenuShow();

    void leave_BeforeArmed();
    void leave_Armed();
    void leave_BeforeAlarm();
    void leave_Alarm();
    void leave_Disarmed();
    void leave_MenuPwdPromt();
    void leave_MenuShow();
  public:
    Alarm(AlarmState _state, byte _pinOut, byte _pinIn, byte _pinTamper, byte _pinFire, byte _pinLed, byte _pinBuzzer);

    void init();

    void process();
};

Alarm::Alarm(AlarmState _state, byte _pinOut, byte _pinIn, byte _pinTamper, byte _pinFire, byte _pinLed, byte _pinBuzzer)
  : currState(_state), pinOut(_pinOut), pinIn(_pinIn), pinTamper(_pinTamper), pinFire(pinFire), pinLed(_pinLed), pinBuzzer(_pinBuzzer),
    btnInput(_pinIn, PULLUP), btnTamper(_pinTamper, PULLUP), btnFire(_pinFire, PULLUP)
{
  currStateStartTime = 0;
  lcdPrintLastTime = 0;
  lcdShowInvalidPasswordMessageLastTime = 0;
  ledBlinkLastTime = 0;
  ledMode = lmOff;
  ledOn = false;
  showInvalidPasswordMessage = false;
  if (pinOut != PIN_BAD)
    pinMode(pinOut, OUTPUT);
  if (pinLed != PIN_BAD)
    pinMode(pinLed, OUTPUT);
  if (pinBuzzer != PIN_BAD)
    pinMode(pinBuzzer, OUTPUT);
  if (pinIn != PIN_BAD)
    pinMode(pinIn, INPUT);
  if (pinTamper != PIN_BAD)
    pinMode(pinTamper, INPUT);
}

void Alarm::init()
{
  lcd.clear();
  lcd.setBacklightOn();
  setState(currState);
}

bool Alarm::lcdCanPrint()
{
  unsigned long now = millis();
  if (lcdPrintLastTime > now)
    lcdPrintLastTime = 0;
  if ((now - lcdPrintLastTime) > lcdPrintDelay)
  {
    lcdPrintLastTime = now;
    return true;
  }
  else
    return false;
}

bool Alarm::passwordPromt(bool _showInvalidPasswordMessage)
{
  unsigned long now = millis();
  if (_showInvalidPasswordMessage)
  {
    showInvalidPasswordMessage = true;
    lcdShowInvalidPasswordMessageLastTime = now;
    lcd.clear();
    lcd.print(lcdPasswordWrong);
    return false;
  }
  if (showInvalidPasswordMessage)
  {
    if (lcdShowInvalidPasswordMessageLastTime > now)
      lcdShowInvalidPasswordMessageLastTime = 0;
    if ((now - lcdShowInvalidPasswordMessageLastTime) > lcdShowInvalidPasswordMessageTime)
      showInvalidPasswordMessage = false;
    if (showInvalidPasswordMessage)
    {
      if (lcdCanPrint())
      {
        lcd.clear();
        lcd.print(lcdPasswordWrong);
      }
      return false;
    }
  }
  char key = keypad.gets();
  if (lcdCanPrint() || (key != NO_KEY))
  {
    lcd.clear();
    lcd.print(lcdPasswordPromt);
    lcd.setCursor(0, 1);
    lcd.printn('*', strlen(keypad.getBuffer()));
    lcd.setBacklightOn();
  }
  return (key == KeypadExt::KeyEnter);
}

void Alarm::setAlarm(bool on)
{
  if (settings.alarmOutMask & 1)
    digitalWrite(pinOut, BoolToHighLow(on));
}

void Alarm::setBuzzer(bool on)
{
  digitalWrite(pinBuzzer, BoolToHighLow(on));
}

void Alarm::setLedMode(AlarmLedMode _ledMode)
{
  ledMode = _ledMode;
}

void Alarm::setState(const AlarmState _newState)
{
  switch(currState)
  {
    case asBeforeArmed:
      leave_BeforeArmed();
      break;
    case asArmed:
      leave_Armed();
      break;
    case asBeforeAlarm:
      leave_BeforeAlarm();
      break;
    case asAlarm:
      leave_Alarm();
      break;
    case asDisarmed:
      leave_Disarmed();
      break;
    case asMenuPwdPromt:
      leave_MenuPwdPromt();
      break;
    case asMenuShow:
      leave_MenuShow();
      break;
  };
  switch(_newState)
  {
    case asBeforeArmed:
      enter_BeforeArmed();
      break;
    case asArmed:
      enter_Armed();
      break;
    case asBeforeAlarm:
      enter_BeforeAlarm();
      break;
    case asAlarm:
      enter_Alarm();
      break;
    case asDisarmed:
      enter_Disarmed();
      break;
    case asMenuPwdPromt:
      enter_MenuPwdPromt();
      break;
    case asMenuShow:
      enter_MenuShow();
      break;
  };
  currState = _newState;
  currStateStartTime = millis();
}

void Alarm::process()
{
  unsigned long now = millis();
  // backlight
  lcd.setBacklight((now - lcd.lcdBacklightOnTime) <= settings.lcdBacklightTime);
  // led
  if (ledMode == lmBlink)
  {
    if (ledBlinkLastTime > now)
      ledBlinkLastTime = 0;
    if ((now - ledBlinkLastTime) > ledBlinkTime)
    {
      ledBlinkLastTime = now;
      ledOn = !ledOn;
    }
  }
  else
    ledOn = (ledMode == lmOn);
  digitalWrite(pinLed, BoolToHighLow(ledOn));
  // correct start time
  if (currStateStartTime > now)
    currStateStartTime = 0;

  if (currState != asAlarm)
  {
    if ((settings.alarmTamperMask & 1) && !btnTamper.isPressedExt())
    {
      #ifdef TEST
      Serial.println("Tamper pin is disconnected");
      #endif
      setState(asAlarm);
      #ifdef EVENTS_LOG_ENABLED
      settings.alarmStatTamperCount++;
      saveSettings();
      #endif
    }
  }
  // process
  switch(currState)
  {
    case asBeforeArmed:
      process_BeforeArmed();
      break;
    case asArmed:
      process_Armed();
      break;
    case asBeforeAlarm:
      process_BeforeAlarm();
      break;
    case asAlarm:
      process_Alarm();
      break;
    case asDisarmed:
      process_Disarmed();
      break;
    case asMenuPwdPromt:
      process_MenuPwdPromt();
      break;
    case asMenuShow:
      process_MenuShow();
      break;
  };
}

void Alarm::enter_BeforeArmed()
{
  // ? setLedMode(lmOn);
}

void Alarm::process_BeforeArmed()
{
  unsigned long workTime = millis() - currStateStartTime;
  if (lcdCanPrint())
  {
    lcd.clear();
    lcd.print(lcdBeforeArmMsg1);
    lcd.setCursor(0, 1);
    lcd.print(lcdBeforeArmMsg2);
    lcd.print((settings.beforeTurnOnDelay - workTime) / 1000);
    lcd.setBacklightOn();
  }
  if (workTime > settings.beforeTurnOnDelay)
    setState(asArmed);
}

void Alarm::leave_BeforeArmed()
{
  lcd.clear();
}

void Alarm::enter_Armed()
{
  setLedMode(lmOn);
  // to avoid false positives
  keypad.getKey();
  delay(200);
}

void Alarm::process_Armed()
{
  if (lcdCanPrint())
  {
    lcd.clear();
    lcd.print(lcdArmModeOnMsg);
  };

  if ((settings.alarmFireMask & 1) && !btnFire.isPressedExt())
  {
    #ifdef TEST
    Serial.println("Fire pin is disconnected");
    #endif
    setState(asBeforeAlarm);
    #ifdef EVENTS_LOG_ENABLED
    settings.alarmStatFireCount++;
    saveSettings();
    #endif
    return;
  }

  if ((settings.alarmInMask & 1) && !btnInput.isPressedExt())
  {
    #ifdef TEST
    Serial.println("Input pin is disconnected");
    #endif
    setState(asBeforeAlarm);
    #ifdef EVENTS_LOG_ENABLED
    settings.alarmStatInCount++;
    saveSettings();
    #endif
    return;
  }

  char key = keypad.getKey();
  if (key == NO_KEY)
    return;

  if (key == KeyAlarmOff)
    setState(asBeforeAlarm);
}

void Alarm::leave_Armed()
{
  setLedMode(lmOff);
  lcd.clear();
}

void Alarm::enter_BeforeAlarm()
{
  setBuzzer(true);
}

void Alarm::process_BeforeAlarm()
{
  unsigned long workTime = millis() - currStateStartTime;
  if (workTime > settings.beforeAlarmDelay)
    setState(asAlarm);
  if (passwordPromt(false))
  {
    bool pwdMatch = (strcmp(keypad.getBuffer(), settings.alarmPassword1) == 0);
    keypad.clearBuffer();
    if (pwdMatch)
      setState(asDisarmed);
    else
      passwordPromt(true);
  }
}

void Alarm::leave_BeforeAlarm()
{
  setBuzzer(false);
  lcd.clear();
}

void Alarm::enter_Alarm()
{
  setAlarm(true);
  setBuzzer(true);
  setLedMode(lmBlink);
  // TODO: Send SMS

  #ifdef EVENTS_LOG_ENABLED
  settings.alarmStatOutCount++;
  saveSettings();
  #endif
}

void Alarm::process_Alarm()
{
  if (passwordPromt(false))
  {
    bool pwdMatch = (strcmp(keypad.getBuffer(), settings.alarmPassword1) == 0);
    keypad.clearBuffer();
    if (pwdMatch)
      setState(asDisarmed);
    else
      passwordPromt(true);
  }
}

void Alarm::leave_Alarm()
{
  setAlarm(false);
  setBuzzer(false);
  setLedMode(lmOff);
  // ? SMS
  lcd.clear();
}

void Alarm::enter_Disarmed()
{
  // to avoid false positives
  keypad.getKey();
  delay(200);
}

void Alarm::process_Disarmed()
{
  if (lcdCanPrint())
  {
    lcd.clear();
    lcd.print(lcdArmModeOffMsg);
    lcd.setCursor(0, 1);
    if ((settings.alarmInMask & 1) && !btnInput.isPressedExt())
    {
      lcd.print(lcdMotionDetectedMsg);
      lcd.print(" ");
    }
    if ((settings.alarmFireMask & 1) && !btnFire.isPressedExt())
      lcd.print(lcdFireDetectedMsg);
  }

  char key = keypad.getKey();
  switch (key)
  {
    case KeyAlarmMenu:
      setState(asMenuPwdPromt);
      break;
    case KeyAlarmOn:
      setState(asBeforeArmed);
      break;
  }
}

void Alarm::leave_Disarmed()
{
  lcd.clear();
}

void Alarm::enter_MenuPwdPromt()
{
}

void Alarm::process_MenuPwdPromt()
{
  if (passwordPromt(false))
  {
    bool pwdMatch = (strcmp(keypad.getBuffer(), settings.menuPassword) == 0);
    keypad.clearBuffer();
    if (pwdMatch)
      setState(asMenuShow);
    else
    {
      lcd.clear();
      lcd.print(lcdPasswordWrong);
      delay(2000);
      setState(asDisarmed);
    }
  }
}

void Alarm::leave_MenuPwdPromt()
{
}

void Alarm::enter_MenuShow()
{
  menu.setActive(true);
}

void Alarm::process_MenuShow()
{
  if (menu.process())
    setState(asDisarmed);
}

void Alarm::leave_MenuShow()
{
  keypad.clearBuffer();
}

/////////////////// Alarm ////////////////////////////

// Alarm init
Alarm alarm(asBeforeArmed/*asDisarmed*/, PinAlarm_Out, PinAlarm_In, PinAlarm_Tamper,
  PinFire, PinLed, PinBuzzer);

void setup()
{
#ifdef TEST
  Serial.begin(9600);
#endif
  loadSettings();
  keypad.setDebounceTime(settings.keypadDebounceTime);
  alarm.init();
}

void loop()
{
  alarm.process();
}
