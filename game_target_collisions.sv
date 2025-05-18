`include "game_config.svh"

module game_target_collisions #(
    parameter N_TARGETS         = `N_TARGETS,
              w_x               = $clog2(640),
              w_y               = $clog2(480),
              IMMUNITY_DURATION = 5
) (
    input                          clk,
    input                          rst,
    input [N_TARGETS-1:0]         enable_targets,
    input [N_TARGETS-1:0][w_x-1:0] sprite_left,
    input [N_TARGETS-1:0][w_x-1:0] sprite_right,
    input [N_TARGETS-1:0][w_y-1:0] sprite_top,
    input [N_TARGETS-1:0][w_y-1:0] sprite_bottom,
    output logic [N_TARGETS-1:0]   collide_x,
    output logic [N_TARGETS-1:0]   collide_y
);

typedef struct packed {
    logic [IMMUNITY_DURATION-1:0] counter;
    logic                         active;
} immunity_t;

immunity_t immunity_matrix [N_TARGETS-1:0][N_TARGETS-1:0];


logic [N_TARGETS-1:0][N_TARGETS-1:0] activate_immunity;


always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        for (int i = 0; i < N_TARGETS; i++) begin
            for (int j = 0; j < N_TARGETS; j++) begin
                immunity_matrix[i][j].counter <= '0;
                immunity_matrix[i][j].active  <= 1'b0;
            end
        end
    end else begin
        for (int i = 0; i < N_TARGETS; i++) begin
            for (int j = i+1; j < N_TARGETS; j++) begin
                if (immunity_matrix[i][j].active) begin
                    immunity_matrix[i][j].counter <= immunity_matrix[i][j].counter - 1;
                    if (immunity_matrix[i][j].counter == 0) begin
                        immunity_matrix[i][j].active <= 1'b0;
                    end
                end
                if (activate_immunity[i][j]) begin
                    immunity_matrix[i][j].counter <= IMMUNITY_DURATION;
                    immunity_matrix[i][j].active  <= 1'b1;
                end
            end
        end
    end
end



logic x_olap;
logic y_olap;
always_comb begin
    x_olap = '0;
    y_olap = '0;
    collide_x = '0;
    collide_y = '0;
    activate_immunity = '0;

    for (int i = 0; i < N_TARGETS; i++) begin
        for (int j = i+1; j < N_TARGETS; j++) begin
            if (enable_targets[i] && enable_targets[j]) begin
                x_olap = (sprite_left[i] < sprite_right[j]) && 
                          (sprite_right[i] > sprite_left[j]);
                y_olap = (sprite_top[i] < sprite_bottom[j]) && 
                          (sprite_bottom[i] > sprite_top[j]);

                if (!immunity_matrix[i][j].active && x_olap && y_olap) begin
                    collide_x[i] = 1'b1;
                    collide_x[j] = 1'b1;
                    collide_y[i] = 1'b1;
                    collide_y[j] = 1'b1;
                    activate_immunity[i][j] = 1'b1;
                end
            end
        end
    end
end

endmodule