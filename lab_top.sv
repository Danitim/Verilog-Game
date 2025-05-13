`include "config.svh"
`include "game_config.svh"

module lab_top
# (
    parameter  clk_mhz       = 50,
               pixel_mhz     = 25,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,
               screen_width  = 640,
               screen_height = 480,
               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,
               w_x           = $clog2 ( screen_width  ),
               w_y           = $clog2 ( screen_height ),
               strobe_to_update_xy_counter_width
                   = $clog2 (clk_mhz * 1000 * 1000) - 6
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,
    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,
    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,
    input                        display_on,
    input        [w_x     - 1:0] x,
    input        [w_y     - 1:0] y,
    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,
    input        [         23:0] mic,
    output       [         15:0] sound,
    input                        uart_rx,
    output                       uart_tx,
    inout        [w_gpio  - 1:0] gpio
);

    //------------------------------------------------------------------------
    assign led        = '0;
    assign sound      = '0;
    assign uart_tx    = '1;

    //------------------------------------------------------------------------
    wire [`GAME_RGB_WIDTH - 1:0] rgb;
    wire [15:0] target_count;

    game_top
    # (
        .clk_mhz                           (clk_mhz                          ),
        .pixel_mhz                         (pixel_mhz                        ),
        .screen_width                      (screen_width                     ),
        .screen_height                     (screen_height                    ),
        .strobe_to_update_xy_counter_width (strobe_to_update_xy_counter_width)
    )
    i_game_top
    (
        .clk              (   clk                ),
        .rst              (   rst                ),
        .launch_key      ( | key                ),
        .left_right_keys  ( { key [1], key [0] } ),
        .display_on       (   display_on         ),
        .x                (   x                  ),
        .y                (   y                  ),
        .rgb              (   rgb                ),
        .target_count     (   target_count       )
    );

    assign red   = { w_red   { rgb [2] } };
    assign green = { w_green { rgb [1] } };
    assign blue  = { w_blue  { rgb [0] } };

    // Логика для семисегментного дисплея (десятичный вывод)
    logic [3:0] bcd_digits [0:3];  // 4 цифры (0-9999)
    logic [1:0] digit_sel;         // Выбор текущего разряда
    logic [7:0] seg_data;          // Данные для сегментов (a-h)
    
    // Преобразование в BCD
    always_comb begin
        bcd_digits[0] = target_count % 10;          // Единицы
        bcd_digits[1] = (target_count / 10) % 10;   // Десятки
        bcd_digits[2] = (target_count / 100) % 10;  // Сотни
        bcd_digits[3] = (target_count / 1000) % 10; // Тысячи
    end
    
    // Счетчик для мультиплексирования разрядов (~1kHz)
    logic [15:0] clk_div;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div <= 0;
            digit_sel <= 0;
        end else begin
            clk_div <= clk_div + 1;
            if (clk_div == 0) digit_sel <= digit_sel + 1;
        end
    end
    
    // Декодер 7-сегментного дисплея с правильной разметкой:
    //   --a--
    //  |     |
    //  f     b
    //  |     |
    //   --g--
    //  |     |
    //  e     c
    //  |     |
    //   --d--  h
    always_comb begin
        case (bcd_digits[digit_sel])
            4'd0: seg_data = 8'b00000011; // abcdef (0)
            4'd1: seg_data = 8'b01100000; // bc (1)
            4'd2: seg_data = 8'b11011010; // abged (2)
            4'd3: seg_data = 8'b11110010; // abgcd (3)
            4'd4: seg_data = 8'b01100110; // fgbc (4)
            4'd5: seg_data = 8'b10110110; // afgcd (5)
            4'd6: seg_data = 8'b10111110; // afgcde (6)
            4'd7: seg_data = 8'b11100000; // abc (7)
            4'd8: seg_data = 8'b11111110; // abcdefg (8)
            4'd9: seg_data = 8'b11110110; // abcdfg (9)
            default: seg_data = 8'b00000000; // Все сегменты выключены
        endcase
    end
    
    // Назначение выходов (для общего анода)
    always_comb begin
        abcdefgh = ~seg_data; // Инвертируем для общего анода
        digit = (8'b00000001 << digit_sel); // Активируем текущий разряд
    end

endmodule