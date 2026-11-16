// Lab 3 Part 2.b: rock-paper-scissors, PC terminal vs Pmod KYPD keypad.
// 1 = rock, 2 = paper, 3 = scissors.
#include "xparameters.h"
#include "xil_printf.h"
#include "sleep.h"
#include "PmodKYPD.h"

// Keypad layout used by Digilent's PmodKYPD example
#define DEFAULT_KEYTABLE "0FED789C456B123A"

static PmodKYPD keypad;
static const char *names[] = { "", "rock", "paper", "scissors" };

// Block until a valid choice (1-3) is typed in the terminal.
static int read_pc_choice(void)
{
    while (1) {
        char c = inbyte();
        if (c >= '1' && c <= '3') {
            xil_printf("%c\r\n", c);
            return c - '0';
        }
    }
}

// Block until a single key 1-3 is pressed and released on the keypad.
static int read_keypad_choice(void)
{
    u16 state;
    u8 key;
    XStatus status;

    while (1) {
        state  = KYPD_getKeyStates(&keypad);
        status = KYPD_getKeyPressed(&keypad, state, &key);
        if (status == KYPD_SINGLE_KEY && key >= '1' && key <= '3') {
            int choice = key - '0';
            // Wait for release so one press counts once
            do {
                usleep(1000);
                state  = KYPD_getKeyStates(&keypad);
                status = KYPD_getKeyPressed(&keypad, state, &key);
            } while (status != KYPD_NO_KEY);
            return choice;
        }
        usleep(1000);
    }
}

int main(void)
{
    int pc, fpga, round = 1;

    KYPD_begin(&keypad, XPAR_PMODKYPD_0_AXI_LITE_GPIO_BASEADDR);
    KYPD_loadKeyTable(&keypad, (u8 *) DEFAULT_KEYTABLE);

    xil_printf("\r\nRock-paper-scissors: 1 = rock, 2 = paper, 3 = scissors\r\n");

    while (1) {
        xil_printf("\r\nRound %d\r\n", round++);

        xil_printf("PC player, enter your choice: ");
        pc = read_pc_choice();

        xil_printf("FPGA player, press 1-3 on the keypad...\r\n");
        fpga = read_keypad_choice();

        xil_printf("PC: %s, FPGA: %s\r\n", names[pc], names[fpga]);

        // a beats b exactly when (a - b) mod 3 == 1
        if (pc == fpga)
            xil_printf("Tie! %s = %s\r\n", names[pc], names[fpga]);
        else if ((fpga - pc + 3) % 3 == 1)
            xil_printf("FPGA won! %s > %s\r\n", names[fpga], names[pc]);
        else
            xil_printf("PC won! %s > %s\r\n", names[pc], names[fpga]);
    }
    return 0;
}
