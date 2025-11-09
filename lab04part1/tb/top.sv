module top;

  import shape_pkg::*;

  // Alias na kolejkę punktów  bezpośrednie 'point_s[$]' w nagłówku funkcji bywa problematyczne dla niektórych kompilatorów
  typedef point_s point_queue_t[$];

  // Konwersja string -> real bez $atof (Cadence)
  function automatic bit try_parse_real(string s, output real val);
    if ($sscanf(s, "%f", val) == 1) return 1;
    if ($sscanf(s, "%g", val) == 1) return 1;
    if ($sscanf(s, "%e", val) == 1) return 1;
    return 0;
  endfunction

  // Parsowanie linii na kolejkę punktów (x1 y1 x2 y2 ...)
  function automatic point_queue_t parse_points(string line);
    point_queue_t result;
    real   coordinates[$];
    string token;
    int    i;

    token = "";

    for (i = 0; i < line.len(); i++) begin
      byte c;
      c = line[i];
      case (c)
        " ", "\t", "\n", "\r": begin
          if (token.len() != 0) begin
            real v;
            if (try_parse_real(token, v)) begin
              coordinates.push_back(v);
            end else begin
              $warning("Cannot parse real from token '%s'", token);
            end
            token = "";
          end
        end
        default: token = {token, c};
      endcase
    end

    if (token.len() != 0) begin
      real v_last;
      if (try_parse_real(token, v_last)) begin
        coordinates.push_back(v_last);
      end else begin
        $warning("Cannot parse real from token '%s'", token);
      end
    end

    if ((coordinates.size() % 2) != 0) begin
      $warning("Ignoring line with odd number of coordinates: '%s'", line);
      return result;
    end

    for (i = 0; i < coordinates.size(); i += 2) begin
      point_s p;
      p.x = coordinates[i];
      p.y = coordinates[i + 1];
      result.push_back(p);
    end

    return result;
  endfunction


  // ====== Główny przebieg ======
  initial begin
    string        line;
    int           file_handle;
    int           line_number;
    point_queue_t points;
    shape_c       shape;

    line_number = 0;

    // Wymaganie: czytamy lab04part1_shapes.txt
    file_handle = $fopen("../lab04part1_shapes.txt", "r");
    if (file_handle == 0) begin
      $fatal(1, "Failed to open lab04part1_shapes.txt");
    end

    // Dla każdej linii: make_shape()
    while ($fgets(line, file_handle)) begin
      line_number++;
      points = parse_points(line);
      if (points.size() == 0) begin
        continue;
      end

      shape = shape_factory::make_shape(points);
      if (shape == null) begin
        $warning("Line %0d: unable to create shape", line_number);
      end
    end

    $fclose(file_handle);

    // Wymaganie: na końcu  raport dla każdego typu
    $display("\n================ Shape Reports ================");
    shape_reporter#(triangle_c)::report_shapes();
    shape_reporter#(rectangle_c)::report_shapes();
    shape_reporter#(polygon_c)::report_shapes();
    shape_reporter#(circle_c)::report_shapes();

    $finish;
  end

endmodule : top
