// range of chars from MIN_CHAR to MAX_CHAR - 1 inclusive
#define MIN_CHAR 0x41
#define MAX_CHAR 0x5b
#define NUM_CHARS (MAX_CHAR - MIN_CHAR)

struct CharInfo {
  int opacity;
  char character;
};

struct Chars {
  int min;
  int max;
  struct CharInfo chars[NUM_CHARS];
};

struct Chars getChars();
