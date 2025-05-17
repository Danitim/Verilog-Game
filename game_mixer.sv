`include "game_config.svh"

module game_mixer
(
    input                                clk,
    input                                rst,

    input        [`N_TARGETS-1:0]        sprite_target_rgb_en,
    input        [`N_TARGETS-1:0][`GAME_RGB_WIDTH - 1:0] sprite_target_rgb,

    input                                sprite_torpedo_rgb_en,
    input        [`GAME_RGB_WIDTH - 1:0] sprite_torpedo_rgb,

    input                                game_won,
    input                                end_of_game_timer_running,
    input                                random,

    output logic [`GAME_RGB_WIDTH - 1:0] rgb
);

    logic target_active;
    logic [`GAME_RGB_WIDTH - 1:0] target_rgb;

    always_comb begin
        target_active = 1'b0;
        target_rgb = 3'b000;
        for (int i = 0; i < `N_TARGETS; i++) begin
            if (sprite_target_rgb_en[i]) begin
                target_active = 1'b1;
                target_rgb = sprite_target_rgb[i];
                break;
            end
        end
    end

    always_ff @ (posedge clk or posedge rst)
        if (rst)
            rgb <= 3'b000;
        else if (end_of_game_timer_running)
            rgb <= { 1'b1, ~ game_won, random };
        else if (sprite_torpedo_rgb_en)
            rgb <= sprite_torpedo_rgb;
        else if (target_active)
            rgb <= target_rgb;
        else
            rgb <= 3'b000;

endmodule