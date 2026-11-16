// Lab 3 Part 2.a: read "A/B" over serial, send back A*B.
// LD0 lights when the product is greater than 100.
#include "xparameters.h"
#include "xil_printf.h"
#include "xgpio.h"

#define DELIM     '/'
#define LED_CHAN  2
#define LINE_MAX  32

static XGpio leds;

// Read one line from the terminal with echo and backspace support.
// PuTTY does not echo locally, so every accepted char is sent back.
static int read_line(char *buf, int max)
{
    int n = 0;
    while (1) {
        char c = inbyte();
        if (c == '\r' || c == '\n') {
            xil_printf("\r\n");
            buf[n] = '\0';
            return n;
        } else if ((c == '\b' || c == 0x7F) && n > 0) {
            n--;
            xil_printf("\b \b");
        } else if (c >= ' ' && c <= '~' && n < max - 1) {
            buf[n++] = c;
            outbyte(c);
        }
    }
}

// Parse an optionally signed decimal number starting at *p.
// Advances *p past it. Returns 0 if no digits were found.
static int parse_int(const char **p, int *out)
{
    const char *s = *p;
    int neg = 0, val = 0, digits = 0;

    while (*s == ' ') s++;
    if (*s == '-' || *s == '+') neg = (*s++ == '-');
    while (*s >= '0' && *s <= '9') {
        val = val * 10 + (*s++ - '0');
        digits++;
    }
    while (*s == ' ') s++;

    *p = s;
    *out = neg ? -val : val;
    return digits > 0;
}

int main(void)
{
    char line[LINE_MAX];
    const char *p;
    int a, b, product;

#ifndef SDT
    XGpio_Initialize(&leds, XPAR_AXI_GPIO_0_DEVICE_ID);
#else
    XGpio_Initialize(&leds, XPAR_AXI_GPIO_0_BASEADDR);
#endif
    XGpio_SetDataDirection(&leds, LED_CHAN, 0x0000);   // all outputs
    XGpio_DiscreteWrite(&leds, LED_CHAN, 0x0000);

    xil_printf("\r\nSerial multiplier. Enter two numbers as A%cB\r\n", DELIM);

    while (1) {
        xil_printf("> ");
        read_line(line, LINE_MAX);
        p = line;

        if (!parse_int(&p, &a) || *p++ != DELIM || !parse_int(&p, &b) || *p != '\0') {
            xil_printf("Invalid input, expected A%cB (e.g. 8%c6)\r\n", DELIM, DELIM);
            continue;
        }

        product = a * b;
        xil_printf("%d\r\n", product);
        XGpio_DiscreteWrite(&leds, LED_CHAN, product > 100 ? 0x0001 : 0x0000);
    }
    return 0;
}
