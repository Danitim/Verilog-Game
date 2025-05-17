`include "game_config.svh"

module game_top
# (
    parameter  clk_mhz       = 50,
               pixel_mhz     = 25,

               screen_width  = 640,
               screen_height = 480,

               w_x           = $clog2 ( screen_width  ),
               w_y           = $clog2 ( screen_height ),

               strobe_to_update_xy_counter_width = 20
)
(
    input                          clk,
    input                          rst,

    input                          launch_key,
    input  [                  1:0] left_right_keys,
    input  [                  1:0] down_up_keys,

    input                          display_on,

    input  [w_x             - 1:0] x,
    input  [w_y             - 1:0] y,

    output [`GAME_RGB_WIDTH - 1:0] rgb,
    
    output [15:0]                  target_count 
);

    wire [`N_TARGETS-1:0] target_hit_wall;

    logic [15:0] target_counter = 0;
    assign target_count = target_counter;

    logic [`N_TARGETS-1:0] prev_target_hit_wall;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            target_counter <= 0;
            prev_target_hit_wall <= 0;
        end else begin
            prev_target_hit_wall <= target_hit_wall;

            if (collision) begin
                target_counter <= 0;
            end else begin
                for (int i = 0; i < `N_TARGETS; i++) begin
                    if (!prev_target_hit_wall[i] && target_hit_wall[i]) begin
                        target_counter <= target_counter + 1;
                    end
                end
            end
        end
    end

    //------------------------------------------------------------------------

    wire [15:0] random;

    game_random random_generator (clk, rst, random);

    //------------------------------------------------------------------------

    wire [`N_TARGETS-1:0]                sprite_target_write_xy;
    wire [`N_TARGETS-1:0]                sprite_target_write_dxy;

    logic [`N_TARGETS-1:0][w_x - 1:0]    sprite_target_write_x;
    wire [`N_TARGETS-1:0][w_y - 1:0]     sprite_target_write_y;

    logic [`N_TARGETS-1:0][3:0]          sprite_target_write_dx;
    logic [`N_TARGETS-1:0][3:0]          sprite_target_write_dy;

    wire [`N_TARGETS-1:0]                sprite_target_enable_update;

    wire [`N_TARGETS-1:0][w_x - 1:0]     sprite_target_x;
    wire [`N_TARGETS-1:0][w_y - 1:0]     sprite_target_y;

    wire [`N_TARGETS-1:0]                sprite_target_within_screen;

    wire [`N_TARGETS-1:0][w_x - 1:0]     sprite_target_out_left;
    wire [`N_TARGETS-1:0][w_x - 1:0]     sprite_target_out_right;
    wire [`N_TARGETS-1:0][w_y - 1:0]     sprite_target_out_top;
    wire [`N_TARGETS-1:0][w_y - 1:0]     sprite_target_out_bottom;

    wire [`N_TARGETS-1:0]                sprite_target_rgb_en;
    wire [`N_TARGETS-1:0][`GAME_RGB_WIDTH - 1:0] sprite_target_rgb;

    //------------------------------------------------------------------------

    logic [3:0] speed;
    logic [2:0] hit_counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            speed <= 4'b0001;
            hit_counter <= 0;
        end
        else if (collision) begin
            speed <= 4'b0001;
            hit_counter <= 0;
        end
        else begin
            for (int i = 0; i < `N_TARGETS; i++) begin
                if (!prev_target_hit_wall[i] && target_hit_wall[i]) begin
                    if (hit_counter == 4) begin
                        speed <= (speed < 4'b1111) ? speed + 1 : speed;
                        hit_counter <= 0;
                    end
                    else begin
                        hit_counter <= hit_counter + 1;
                    end
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < `N_TARGETS; i++) begin
            logic [15:0] rand_part;
            rand_part = random ^ (i * 16'h5555);
            
            case (rand_part[1:0])
                2'b00: begin
                    sprite_target_write_x[i] = 10'd0 + rand_part[3:0] * 8;
                    sprite_target_write_dx[i] = speed;
                    sprite_target_write_dy[i] = speed;
                end
                2'b01: begin
                    sprite_target_write_x[i] = screen_width - 16 - rand_part[7:4] * 8;
                    sprite_target_write_dx[i] = -speed;
                    sprite_target_write_dy[i] = speed;
                end
                2'b10: begin
                    sprite_target_write_x[i] = rand_part[11:8] % (screen_width - 8);
                    sprite_target_write_dx[i] = speed;
                    sprite_target_write_dy[i] = -speed;
                end
                2'b11: begin
                    sprite_target_write_x[i] = rand_part[15:12] % (screen_width - 8);
                    sprite_target_write_dx[i] = -speed;
                    sprite_target_write_dy[i] = speed;
                end
            endcase
            sprite_target_write_y[i] = screen_height/10 + rand_part[5:0];
        end
    end

    //------------------------------------------------------------------------

    logic [`N_TARGETS-1:0] target_enable = '1;
    wire [`N_TARGETS-1:0] target_collide_x;
    wire [`N_TARGETS-1:0] target_collide_y;

    game_target_collisions #(
        .N_TARGETS(`N_TARGETS),
        .w_x(w_x),
        .w_y(w_y)
    ) target_collisions_inst (
        .clk(clk),
        .rst(rst),
        .sprite_left(sprite_target_out_left),
        .sprite_right(sprite_target_out_right),
        .sprite_top(sprite_target_out_top),
        .sprite_bottom(sprite_target_out_bottom),
        .collide_x(target_collide_x),
        .collide_y(target_collide_y)
    );

    generate
        genvar i;
        for (i = 0; i < `N_TARGETS; i++) begin : target_gen
            game_sprite_top #(
                .SPRITE_WIDTH  ( 32 ),
                .SPRITE_HEIGHT ( 32 ),
                .DX_WIDTH      ( 4 ),
                .DY_WIDTH      ( 4 ),
                .ROW_0 ( 32'h000bb000 ),
                .ROW_1 ( 32'h00099000 ),
                .ROW_2 ( 32'h00099000 ),
                .ROW_3 ( 32'hb99ff99b ),
                .ROW_4 ( 32'hb99ff99b ),
                .ROW_5 ( 32'h00099000 ),
                .ROW_6 ( 32'h00099000 ),
                .ROW_7 ( 32'h000bb000 ),
                .screen_width(screen_width),
                .screen_height(screen_height),
                .strobe_to_update_xy_counter_width(strobe_to_update_xy_counter_width)
            ) sprite_target (
                .clk(clk),
                .rst(rst),
                .enable(target_enable[i]),
                .pixel_x(x),
                .pixel_y(y),
                .sprite_write_xy(sprite_target_write_xy[i]),
                .sprite_write_dxy(sprite_target_write_dxy[i]),
                .sprite_write_x(sprite_target_write_x[i]),
                .sprite_write_y(sprite_target_write_y[i]),
                .sprite_write_dx(sprite_target_write_dx[i]),
                .sprite_write_dy(sprite_target_write_dy[i]),
                .sprite_enable_update(sprite_target_enable_update[i]),
                .sprite_x(sprite_target_x[i]),
                .sprite_y(sprite_target_y[i]),
                .sprite_within_screen(sprite_target_within_screen[i]),
                .sprite_out_left(sprite_target_out_left[i]),
                .sprite_out_right(sprite_target_out_right[i]),
                .sprite_out_top(sprite_target_out_top[i]),
                .sprite_out_bottom(sprite_target_out_bottom[i]),
                .rgb_en(sprite_target_rgb_en[i]),
                .rgb(sprite_target_rgb[i]),
                .collide_x(target_collide_x[i]),
                .collide_y(target_collide_y[i]),
                .hit_wall(target_hit_wall[i])
            );
        end
    endgenerate

    //------------------------------------------------------------------------

    wire                          sprite_torpedo_write_xy;
    wire                          sprite_torpedo_write_dxy;

    wire  [w_x             - 1:0] sprite_torpedo_write_x;
    wire  [w_y             - 1:0] sprite_torpedo_write_y;

    logic [                  2:0] sprite_torpedo_write_dx;
    logic [                  2:0] sprite_torpedo_write_dy;

    wire                          sprite_torpedo_enable_update;

    wire  [w_x             - 1:0] sprite_torpedo_x;
    wire  [w_y             - 1:0] sprite_torpedo_y;

    wire                          sprite_torpedo_within_screen;

    wire  [w_x             - 1:0] sprite_torpedo_out_left;
    wire  [w_x             - 1:0] sprite_torpedo_out_right;
    wire  [w_y             - 1:0] sprite_torpedo_out_top;
    wire  [w_y             - 1:0] sprite_torpedo_out_bottom;

    wire                          sprite_torpedo_rgb_en;
    wire  [`GAME_RGB_WIDTH - 1:0] sprite_torpedo_rgb;

    //------------------------------------------------------------------------

    assign sprite_torpedo_write_x  = screen_width / 2 + random [15:10];
    assign sprite_torpedo_write_y  = screen_height - 64;

    always_comb
    begin
        case (left_right_keys)
        2'b00: sprite_torpedo_write_dx = 3'b000;
        2'b01: sprite_torpedo_write_dx = 3'b010;
        2'b10: sprite_torpedo_write_dx = 3'b110;
        2'b11: sprite_torpedo_write_dx = 3'b000;
        endcase

        case (down_up_keys)
        2'b00: sprite_torpedo_write_dy = 3'b000;
        2'b01: sprite_torpedo_write_dy = 3'b110;
        2'b10: sprite_torpedo_write_dy = 3'b010;
        2'b11: sprite_torpedo_write_dy = 3'b000;
        endcase
    end

    //------------------------------------------------------------------------

    game_sprite_top
    #(
        .SPRITE_WIDTH  ( 8 ),
        .SPRITE_HEIGHT ( 8 ),

        .DX_WIDTH      ( 3 ),
        .DY_WIDTH      ( 3 ),

        .ROW_0 ( 32'h000cc000 ),
        .ROW_1 ( 32'h00cccc00 ),
        .ROW_2 ( 32'h0cceecc0 ),
        .ROW_3 ( 32'hcccccccc ),
        .ROW_4 ( 32'hcc0cc0cc ),
        .ROW_5 ( 32'hcc0cc0cc ),
        .ROW_6 ( 32'hcc0cc0cc ),
        .ROW_7 ( 32'hcc0cc0cc ),

        .screen_width
        (screen_width),

        .screen_height
        (screen_height),

        .strobe_to_update_xy_counter_width
        (strobe_to_update_xy_counter_width)
    )
    sprite_torpedo
    (
        .clk                   ( clk                           ),
        .rst                   ( rst                           ),
        .enable                ( 1'b1                          ),

        .pixel_x               ( x                             ),
        .pixel_y               ( y                             ),

        .sprite_write_xy       ( sprite_torpedo_write_xy       ),
        .sprite_write_dxy      ( sprite_torpedo_write_dxy      ),

        .sprite_write_x        ( sprite_torpedo_write_x        ),
        .sprite_write_y        ( sprite_torpedo_write_y        ),

        .sprite_write_dx       ( sprite_torpedo_write_dx       ),
        .sprite_write_dy       ( sprite_torpedo_write_dy       ),

        .sprite_enable_update  ( sprite_torpedo_enable_update  ),

        .sprite_x              ( sprite_torpedo_x              ),
        .sprite_y              ( sprite_torpedo_y              ),

        .sprite_within_screen  ( sprite_torpedo_within_screen  ),

        .sprite_out_left       ( sprite_torpedo_out_left       ),
        .sprite_out_right      ( sprite_torpedo_out_right      ),
        .sprite_out_top        ( sprite_torpedo_out_top        ),
        .sprite_out_bottom     ( sprite_torpedo_out_bottom     ),

        .rgb_en                ( sprite_torpedo_rgb_en         ),
        .rgb                   ( sprite_torpedo_rgb            )
    );

    //------------------------------------------------------------------------

    wire collision;
    wire [`N_TARGETS-1:0] target_collisions;

    generate
        genvar j;
        for (j = 0; j < `N_TARGETS; j++) begin : overlap_gen
            game_overlap #(
                .screen_width(screen_width),
                .screen_height(screen_height)
            ) overlap_inst (
                .clk(clk),
                .rst(rst),
                .target_enable(target_enable[j]),
                .left_1(sprite_target_out_left[j]),
                .right_1(sprite_target_out_right[j]),
                .top_1(sprite_target_out_top[j]),
                .bottom_1(sprite_target_out_bottom[j]),
                .left_2(sprite_torpedo_out_left),
                .right_2(sprite_torpedo_out_right),
                .top_2(sprite_torpedo_out_top),
                .bottom_2(sprite_torpedo_out_bottom),
                .overlap(target_collisions[j])
            );
        end
    endgenerate

    assign collision = |target_collisions;

    //------------------------------------------------------------------------

    wire end_of_game_timer_start;
    wire end_of_game_timer_running;

    game_timer # (.width (25)) timer
    (
        .clk     ( clk                       ),
        .rst     ( rst                       ),
        .value   ( 25'h1000000               ),
        .start   ( end_of_game_timer_start   ),
        .running ( end_of_game_timer_running )
    );

    //------------------------------------------------------------------------

    wire game_won;

    game_mixer mixer
    (
        .clk                           ( clk                           ),
        .rst                           ( rst                           ),

        .sprite_target_rgb_en          ( sprite_target_rgb_en          ),
        .sprite_target_rgb             ( sprite_target_rgb             ),

        .sprite_torpedo_rgb_en         ( sprite_torpedo_rgb_en         ),
        .sprite_torpedo_rgb            ( sprite_torpedo_rgb            ),

        .game_won                      ( game_won                      ),
        .end_of_game_timer_running     ( end_of_game_timer_running     ),
        .random                        ( random [0]                    ),

        .rgb                           ( rgb                           )
    );

    //------------------------------------------------------------------------

    `GAME_MASTER_FSM_MODULE master_fsm
    (
        .clk                           ( clk                           ),
        .rst                           ( rst                           ),

        .launch_key                    ( launch_key                    ),

        .sprite_target_write_xy        ( sprite_target_write_xy        ),
        .sprite_torpedo_write_xy       ( sprite_torpedo_write_xy       ),

        .sprite_target_write_dxy       ( sprite_target_write_dxy       ),
        .sprite_torpedo_write_dxy      ( sprite_torpedo_write_dxy      ),

        .sprite_target_enable_update   ( sprite_target_enable_update   ),
        .sprite_torpedo_enable_update  ( sprite_torpedo_enable_update  ),

        .sprite_target_within_screen   ( sprite_target_within_screen   ),
        .sprite_torpedo_within_screen  ( sprite_torpedo_within_screen  ),

        .collision                     ( collision                     ),

        .game_won                      ( game_won                      ),
        .end_of_game_timer_start       ( end_of_game_timer_start       ),

        .end_of_game_timer_running     ( end_of_game_timer_running     )
    );

endmodule
