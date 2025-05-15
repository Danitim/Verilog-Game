`include "game_config.svh"

module game_sprite_control
#(
    parameter SPRITE_WIDTH  = 8,
              SPRITE_HEIGHT = 8,
              DX_WIDTH      = 2,  // X speed width in bits
              DY_WIDTH      = 2,  // Y speed width in bits

              screen_width  = 640,
              screen_height = 480,

              w_x           = $clog2 ( screen_width  ),
              w_y           = $clog2 ( screen_height ),

              strobe_to_update_xy_counter_width = 20
)

//----------------------------------------------------------------------------

(
    input                    clk,
    input                    rst,

    input                    sprite_write_xy,
    input                    sprite_write_dxy,

    input  [w_x       - 1:0] sprite_write_x,
    input  [w_y       - 1:0] sprite_write_y,

    input  [ DX_WIDTH - 1:0] sprite_write_dx,
    input  [ DY_WIDTH - 1:0] sprite_write_dy,

    input                    sprite_enable_update,

    output [w_x       - 1:0] sprite_x,
    output [w_y       - 1:0] sprite_y
);

    wire strobe_to_update_xy;

    game_strobe
    # (.width (strobe_to_update_xy_counter_width))
    strobe_generator
    (clk, rst, strobe_to_update_xy);

    logic [w_x       - 1:0] x;
    logic [w_y       - 1:0] y;

    logic [ DX_WIDTH - 1:0] dx;
    logic [ DY_WIDTH - 1:0] dy;

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
            x  <= 0;
            y  <= 0;
            dx <= 0;
            dy <= 0;
        end else begin
            // Приоритет 1: Запись новых координат
            if (sprite_write_xy) begin
                x <= sprite_write_x;
                y <= sprite_write_y;
            end
            // Приоритет 2: Запись новых скоростей
            if (sprite_write_dxy) begin
                dx <= sprite_write_dx;
                dy <= sprite_write_dy;
            end
            // Приоритет 3: Обновление позиции с проверкой столкновений
            if (sprite_enable_update && strobe_to_update_xy && !sprite_write_xy && !sprite_write_dxy) begin
                logic [w_x-1:0] x_new;
                logic [w_y-1:0] y_new;
                logic [DX_WIDTH-1:0] dx_new;
                logic [DY_WIDTH-1:0] dy_new;

                // Вычисление новых координат
                x_new = x + { { w_x - DX_WIDTH { dx[DX_WIDTH-1] } }, dx };
                y_new = y + { { w_y - DY_WIDTH { dy[DY_WIDTH-1] } }, dy };

                dx_new = dx;
                dy_new = dy;

                // Проверка столкновений по X
                if (x_new < 0) begin
                    dx_new = ~dx + 1; // Инверсия знака (дополнение до двух)
                    x_new = 0;
                end else if (x_new + SPRITE_WIDTH >= screen_width) begin
                    dx_new = ~dx + 1;
                    x_new = screen_width - SPRITE_WIDTH;
                end

                // Проверка столкновений по Y
                if (y_new < 0) begin
                    dy_new = ~dy + 1;
                    y_new = 0;
                end else if (y_new + SPRITE_HEIGHT >= screen_height) begin
                    dy_new = ~dy + 1;
                    y_new = screen_height - SPRITE_HEIGHT;
                end

                // Обновление регистров
                x <= x_new;
                y <= y_new;
                dx <= dx_new;
                dy <= dy_new;
            end
        end
    end

    assign sprite_x = x;
    assign sprite_y = y;

endmodule