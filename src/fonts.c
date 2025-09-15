#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include "ft2build.h"
#include FT_FREETYPE_H

#include "fonts.h"

struct Chars getChars() {
    FT_Library ft;

    FT_Init_FreeType(&ft);

    FT_Face face;
    FT_New_Face(ft, "src/fonts/arial.ttf", 0, &face);

    FT_Set_Pixel_Sizes(face, 24, 48);

    struct Chars chars;

    for (int c = MIN_CHAR; c < MAX_CHAR; c++) {
        FT_Load_Char(face, c, FT_LOAD_RENDER);

        int sum = 0;
        int pixels = face->glyph->bitmap.width * 48;
        for (int i = 0; i < pixels; i++) {
            sum += face->glyph->bitmap.buffer[i];
        }

        int opacity = sum / pixels;

        chars.chars[c - MIN_CHAR].opacity = opacity;
        chars.chars[c - MIN_CHAR].character = c;
    }

    bool swapped = false;
    do {
        swapped = false;

        for (int i = 0; i < NUM_CHARS; i++) {
            if (chars.chars[i].opacity > chars.chars[i + 1].opacity) {
                struct CharInfo swap = chars.chars[i];
                chars.chars[i] = chars.chars[i + 1];
                chars.chars[i + 1] = swap;

                swapped = true;
            }
        }
    } while (swapped);

    chars.min = chars.chars[0].opacity;
    chars.max = chars.chars[NUM_CHARS - 1].opacity;

    return chars;
}
