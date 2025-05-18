`include "game_config.svh"

module game_master_fsm_1_regular_state_encoded
(
    input                          clk,
    input                          rst,

    input                          launch_key,

    input        [`N_TARGETS-1:0]  new_target_activation,

    output logic [`N_TARGETS-1:0]  sprite_target_write_xy,
    output logic                   sprite_torpedo_write_xy,

    output logic [`N_TARGETS-1:0]  sprite_target_write_dxy,
    output logic                   sprite_torpedo_write_dxy,

    output logic [`N_TARGETS-1:0]  sprite_target_enable_update,
    output logic                   sprite_torpedo_enable_update,

    input        [`N_TARGETS-1:0]  sprite_target_within_screen,
    input                          sprite_torpedo_within_screen,

    input                          collision,

    output logic                   end_of_game_timer_start,
    output logic                   game_won,

    input                          end_of_game_timer_running
);

    localparam [1:0] STATE_START  = 0,
                     STATE_AIM    = 1,
                     STATE_SHOOT  = 2,
                     STATE_END    = 3;

    logic [1:0] state;
    logic [1:0] d_state;

    logic [`N_TARGETS-1:0] d_sprite_target_write_xy;
    logic                  d_sprite_torpedo_write_xy;

    logic [`N_TARGETS-1:0] d_sprite_target_write_dxy;
    logic                  d_sprite_torpedo_write_dxy;

    logic [`N_TARGETS-1:0] d_sprite_target_enable_update;
    logic                  d_sprite_torpedo_enable_update;

    logic                  d_end_of_game_timer_start;
    logic                  d_game_won;

    //------------------------------------------------------------------------
    wire [`N_TARGETS-1:0] target_out_of_screen = ~sprite_target_within_screen;
    wire                  torpedo_out_of_screen = ~sprite_torpedo_within_screen;
    wire                  game_over = collision || torpedo_out_of_screen;

    //------------------------------------------------------------------------
    always_comb begin
        // Default values
        d_state = state;
        
        d_sprite_target_write_xy        = '0;
        d_sprite_torpedo_write_xy       = 1'b0;
        
        d_sprite_target_write_dxy       = '0;
        d_sprite_torpedo_write_dxy      = 1'b0;
        
        d_sprite_target_enable_update   = '0;
        d_sprite_torpedo_enable_update  = 1'b0;
        
        d_end_of_game_timer_start       = 1'b0;
        d_game_won                      = game_won;

        case (state)
            //------------------------------------------------------------
            STATE_START: begin
                d_sprite_target_write_xy  = {`N_TARGETS{1'b1}};
                d_sprite_torpedo_write_xy = 1'b1;
                
                d_sprite_target_write_dxy = {`N_TARGETS{1'b1}};
                
                d_game_won = 1'b0;
                d_state = STATE_AIM;
            end

            //------------------------------------------------------------
            STATE_AIM: begin
                d_sprite_target_enable_update = {`N_TARGETS{1'b1}};

                for (int i = 0; i < `N_TARGETS; i++) begin
                    if (new_target_activation[i]) begin
                        d_sprite_target_write_xy[i]  = 1'b1;
                        d_sprite_target_write_dxy[i] = 1'b1;
                    end
                end

                // Перезапуск целей вне экрана
                for (int i = 0; i < `N_TARGETS; i++) begin
                    if (target_out_of_screen[i]) begin
                        d_sprite_target_write_xy[i]  = 1'b1;
                        d_sprite_target_write_dxy[i] = 1'b1;
                    end
                end

                if (game_over) begin
                    d_end_of_game_timer_start = 1'b1;
                    d_state = STATE_END;
                end
                else if (launch_key) begin
                    d_state = STATE_SHOOT;
                end
            end

            //------------------------------------------------------------
            STATE_SHOOT: begin
                d_sprite_torpedo_write_dxy     = 1'b1;
                d_sprite_target_enable_update  = {`N_TARGETS{1'b1}};
                d_sprite_torpedo_enable_update = 1'b1;

                for (int i = 0; i < `N_TARGETS; i++) begin
                    if (new_target_activation[i]) begin
                        d_sprite_target_write_xy[i]  = 1'b1;
                        d_sprite_target_write_dxy[i] = 1'b1;
                    end
                end

                // Перезапуск целей вне экрана
                for (int i = 0; i < `N_TARGETS; i++) begin
                    if (target_out_of_screen[i]) begin
                        d_sprite_target_write_xy[i]  = 1'b1;
                        d_sprite_target_write_dxy[i] = 1'b1;
                    end
                end

                if (collision) begin
                    d_game_won = 1'b1;
                    d_end_of_game_timer_start = 1'b1;
                    d_state = STATE_END;
                end
                else if (torpedo_out_of_screen) begin
                    d_end_of_game_timer_start = 1'b1;
                    d_state = STATE_END;
                end
            end

            //------------------------------------------------------------
            STATE_END: begin
                if (collision) d_game_won = 1'b1;
                if (!end_of_game_timer_running) d_state = STATE_START;
            end

        endcase
    end

    //------------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_START;
            
            sprite_target_write_xy       <= '0;
            sprite_torpedo_write_xy      <= 1'b0;
            
            sprite_target_write_dxy      <= '0;
            sprite_torpedo_write_dxy     <= 1'b0;
            
            sprite_target_enable_update  <= '0;
            sprite_torpedo_enable_update <= 1'b0;
            
            end_of_game_timer_start      <= 1'b0;
            game_won                     <= 1'b0;
        end
        else begin
            state <= d_state;
            
            sprite_target_write_xy       <= d_sprite_target_write_xy;
            sprite_torpedo_write_xy      <= d_sprite_torpedo_write_xy;
            
            sprite_target_write_dxy      <= d_sprite_target_write_dxy;
            sprite_torpedo_write_dxy     <= d_sprite_torpedo_write_dxy;
            
            sprite_target_enable_update  <= d_sprite_target_enable_update;
            sprite_torpedo_enable_update <= d_sprite_torpedo_enable_update;
            
            end_of_game_timer_start      <= d_end_of_game_timer_start;
            game_won                     <= d_game_won;
        end
    end

endmodule