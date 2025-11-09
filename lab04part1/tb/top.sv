`timescale 1ns/1ps

import shape_pkg::*;

module top;

  function automatic point_s[$] parse_points(string line);
    point_s result[$];
    real coordinates[$];
    string token = "";
    for (int i = 0; i < line.len(); i++) begin
      byte c = line[i];
      case (c)
        " ", "\t", "\n", "\r": begin
          if (token.len() != 0) begin
            coordinates.push_back($atof(token));
            token = "";
          end
        end
        default: token = {token, c};
      endcase
    end
    if (token.len() != 0) begin
      coordinates.push_back($atof(token));
    end

    if ((coordinates.size() % 2) != 0) begin
      $warning("Ignoring line with odd number of coordinates: '%s'", line);
      return result;
    end

    for (int i = 0; i < coordinates.size(); i += 2) begin
      point_s point;
      point.x = coordinates[i];
      point.y = coordinates[i + 1];
      result.push_back(point);
    end
    return result;
  endfunction

  initial begin
    string line;
    int file_handle;
    int line_number = 0;

    file_handle = $fopen("lab04part1_shapes.txt", "r");
    if (file_handle == 0) begin
      $fatal(1, "Failed to open lab04part1_shapes.txt");
    end

    while ($fgets(line, file_handle)) begin
      line_number++;
      point_s points[$] = parse_points(line);
      if (points.size() == 0) begin
        continue;
      end
      shape_c shape = shape_factory::make_shape(points);
      if (shape == null) begin
        $warning("Line %0d: unable to create shape", line_number);
      end
    end

    $fclose(file_handle);

    $display("\n================ Shape Reports ================");
    shape_reporter#(triangle_c)::report_shapes();
    shape_reporter#(rectangle_c)::report_shapes();
    shape_reporter#(polygon_c)::report_shapes();
    shape_reporter#(circle_c)::report_shapes();

    $finish;
  end

endmodule : top