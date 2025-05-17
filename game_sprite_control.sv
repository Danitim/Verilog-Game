`include "game_config.svh"

module game_sprite_control
#(
    parameter SPRITE_WIDTH   = 8,   // sprite width in pixels
              SPRITE_HEIGHT  = 8,   // sprite height in pixels

              DX_WIDTH       = 2,   // signed horizontal speed width
              DY_WIDTH       = 2,   // signed vertical speed width

              screen_width   = 640,
              screen_height  = 480,

              w_x            = $clog2(screen_width),   // coordinate bit‑widths
              w_y            = $clog2(screen_height),

              strobe_to_update_xy_counter_width = 20    // movement slow‑down
)
(
    input  logic                       clk,
    input  logic                       rst,
    input  logic                       enable,

    // control signals
    input  logic                       sprite_enable_update,
    input  logic                       sprite_write_xy,
    input  logic                       sprite_write_dxy,

    // write ports (external CPU)
    input  logic [w_x-1:0]             sprite_write_x,
    input  logic [w_y-1:0]             sprite_write_y,
    input  logic signed [DX_WIDTH-1:0] sprite_write_dx,
    input  logic signed [DY_WIDTH-1:0] sprite_write_dy,

    input  logic                       collide_x,
    input  logic                       collide_y,

    // read ports (to renderer)
    output logic [w_x-1:0]             sprite_x,
    output logic [w_y-1:0]             sprite_y,
    output logic                       hit_wall
);

    //--------------------------------------------------------------------
    //  Generate a slow strobe so sprites move visibly on screen
    //--------------------------------------------------------------------
    wire strobe_to_update_xy;

    game_strobe #(
        .width ( strobe_to_update_xy_counter_width )
    ) strobe_generator (
        .clk   ( clk  ),
        .rst   ( rst  ),
        .strobe( strobe_to_update_xy )
    );

    logic [w_x-1:0]             x;
    logic [w_y-1:0]             y;
    logic signed [DX_WIDTH-1:0] dx;
    logic signed [DY_WIDTH-1:0] dy;

    logic signed [w_x:0] next_x_s;
    logic signed [w_y:0] next_y_s;

    assign next_x_s = $signed({1'b0, x}) +
                      $signed({{(w_x-DX_WIDTH+1){dx[DX_WIDTH-1]}}, dx});
    assign next_y_s = $signed({1'b0, y}) +
                      $signed({{(w_y-DY_WIDTH+1){dy[DY_WIDTH-1]}}, dy});


    wire hit_left   = next_x_s < 0;
    wire hit_right  = next_x_s > screen_width  - SPRITE_WIDTH;
    wire hit_top    = next_y_s < 0;
    wire hit_bottom = next_y_s > screen_height - SPRITE_HEIGHT;

    assign hit_wall = (hit_left || hit_right || hit_top || hit_bottom);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            x <= 0;
            y <= 0;
        end
        else if (sprite_write_xy) begin
            x <= sprite_write_x;
            y <= sprite_write_y;
        end
        else if (enable && sprite_enable_update && strobe_to_update_xy) begin
            // Horizontal
            if (hit_left)
                x <= 0;
            else if (hit_right)
                x <= screen_width - SPRITE_WIDTH;
            else
                x <= next_x_s[w_x-1:0];

            // Vertical
            if (hit_top)
                y <= 0;
            else if (hit_bottom)
                y <= screen_height - SPRITE_HEIGHT;
            else
                y <= next_y_s[w_y-1:0];
        end
    end

    logic prev_collide_x, prev_collide_y;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            prev_collide_x <= 0;
            prev_collide_y <= 0;
        end else begin
            prev_collide_x <= collide_x;
            prev_collide_y <= collide_y;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dx <= '0;
            dy <= '0;
        end
        else if (!enable) begin
            dx <= '0;
            dy <= '0;
        end
        else if (sprite_write_dxy) begin
            dx <= sprite_write_dx;
            dy <= sprite_write_dy;
        end
        else if (sprite_enable_update && strobe_to_update_xy) begin
            if ((hit_left || hit_right) && !prev_collide_x) dx <= -dx;
            if ((hit_top  || hit_bottom) && !prev_collide_y) dy <= -dy;
            if (collide_x && !prev_collide_x) dx <= -dx;
            if (collide_y && !prev_collide_y) dy <= -dy;
        end
    end

    assign sprite_x = x;
    assign sprite_y = y;

endmodule
