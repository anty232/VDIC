package shape_pkg;

  // ====== Prosty typ punktu (x,y) ======
  typedef struct {
    real x;
    real y;
  } point_s;

  // ====== Pomocnicza wartość bezwzględna ======
  function automatic real abs_real(real value);
    if (value < 0.0) begin
      return -value;
    end
    return value;
  endfunction


  // ====== Klasa bazowa (abstrakcyjna) ======
  // - ma nazwę i tablicę punktów (kolejkę)
  // - ma NIEWDROŻONĄ (pure virtual) get_area()
  // - ma WDROŻONĄ print() (wymóg zadania)
  virtual class shape_c;
    protected string  m_name;
    protected point_s m_points[$];

    function new(string name, point_s points[$]);
      m_name = name;
      foreach (points[i]) begin
        m_points.push_back(points[i]);
      end
    endfunction

    // wymusza implementację w klasach pochodnych
    pure virtual function real get_area();

    function string get_name();
      return m_name;
    endfunction

    // Wspólne drukowanie: nazwa, punkty, pole
    protected function void print_points();
      int i;
      foreach (m_points[i]) begin
        $display("  P%0d = (%0.3f, %0.3f)", i, m_points[i].x, m_points[i].y);
      end
    endfunction

    virtual function void print();
      $display("Shape '%s':", m_name);
      print_points();
      $display("  Area  = %0.3f", get_area());
    endfunction
  endclass : shape_c


  // ====== Wielokąt ogólny ======
  class polygon_c extends shape_c;

    function new(string name, point_s points[$]);
      super.new(name, points);
    endfunction

    // Pole metodą "shoelace"
    virtual function real get_area();
      real sum;
      int i;
      sum = 0.0;
      for (i = 0; i < m_points.size(); i++) begin
        point_s p0;
        point_s p1;
        p0 = m_points[i];
        p1 = m_points[(i + 1) % m_points.size()];
        sum += (p0.x * p1.y) - (p1.x * p0.y);
      end
      return abs_real(sum) * 0.5;
    endfunction
  endclass : polygon_c


  // ====== Trójkąt (3 punkty) ======
  class triangle_c extends polygon_c;
    function new(string name, point_s points[$]);
      super.new(name, points);
      assert(points.size() == 3)
        else $warning("triangle_c created with %0d points", points.size());
    endfunction
    // get_area() i print() dziedziczone (shoelace + bazowe print)
  endclass : triangle_c


  // ====== Prostokąt (4 punkty) ======
  class rectangle_c extends polygon_c;
    function new(string name, point_s points[$]);
      super.new(name, points);
      assert(points.size() == 4)
        else $warning("rectangle_c created with %0d points", points.size());
    endfunction
    // get_area() i print() dziedziczone
  endclass : rectangle_c


  // ====== Okrąg (2 punkty: środek i punkt na obwodzie) ======
  class circle_c extends shape_c;
    protected real m_radius;

    function new(string name, point_s points[$]);
      super.new(name, points);
      if (points.size() >= 2) begin
        m_radius = distance(points[0], points[1]);
      end else begin
        m_radius = 0.0;
      end
    endfunction

    static function real distance(point_s p0, point_s p1);
      real dx;
      real dy;
      dx = p1.x - p0.x;
      dy = p1.y - p0.y;
      return $sqrt(dx * dx + dy * dy);
    endfunction

    virtual function real get_area();
      return 3.14159265358979323846 * m_radius * m_radius;
    endfunction

    function real get_radius();
      return m_radius;
    endfunction

    // Wymóg: oprócz nazwy/punktów/pola drukujemy też promień
    virtual function void print();
      $display("Shape '%s':", m_name);
      print_points();
      $display("  Radius = %0.3f", m_radius);
      $display("  Area   = %0.3f", get_area());
    endfunction
  endclass : circle_c


  // ====== Reporter obiektów danego typu (wymóg zadania) ======
  class shape_reporter #(type T = shape_c);
    protected static T shape_storage[$];

    static function void add_shape(T shape);
      if (shape != null) begin
        shape_storage.push_back(shape);
      end
    endfunction

    static function void report_shapes();
      string reporter_name;
      real total_area;
      int  i;

      reporter_name = $typename(T);

      if (shape_storage.size() == 0) begin
        $display("No shapes recorded for %s", reporter_name);
        $display("");
        return;
      end

      $display("---- Reporting %s objects ----", reporter_name);

      total_area = 0.0;
      foreach (shape_storage[i]) begin
        shape_storage[i].print();
        total_area += shape_storage[i].get_area();
        if (i != shape_storage.size() - 1) begin
          $display("");
        end
      end

      $display("Total area for %s objects: %0.3f", reporter_name, total_area);
      $display("");
    endfunction
  endclass : shape_reporter


  // ====== Fabryka kształtów (wymóg zadania) ======
  class shape_factory;
    protected static int polygon_id   = 0;
    protected static int rectangle_id = 0;
    protected static int triangle_id  = 0;
    protected static int circle_id    = 0;

    static function real distance(point_s p0, point_s p1);
      return circle_c::distance(p0, p1);
    endfunction

    // Rozpoznawanie prostokąta:
    // - kolejne boki prostopadłe (iloczyn skalarny ~ 0)
    // - równe długości przekątnych
    static function bit is_rectangle(point_s points[$]);
      real epsilon;
      real d0;
      real d1;
      int  i;

      if (points.size() != 4) begin
        return 0;
      end

      epsilon = 1e-6;

      for (i = 0; i < 4; i++) begin
        point_s p0;
        point_s p1;
        point_s p2;
        real v1x;
        real v1y;
        real v2x;
        real v2y;
        real dot;

        p0  = points[i];
        p1  = points[(i + 1) % 4];
        p2  = points[(i + 2) % 4];

        v1x = p1.x - p0.x;
        v1y = p1.y - p0.y;
        v2x = p2.x - p1.x;
        v2y = p2.y - p1.y;

        dot = v1x * v2x + v1y * v2y;
        if (abs_real(dot) > epsilon) begin
          return 0;
        end
      end

      d0 = distance(points[0], points[2]);
      d1 = distance(points[1], points[3]);

      if (abs_real(d0 - d1) > epsilon) begin
        return 0;
      end

      return 1;
    endfunction

    // Tworzenie obiektu i rejestracja w reporterze danego typu
    static function shape_c make_shape(point_s points[$]);
      shape_c result;

      case (points.size())
        2: begin
          circle_c circle;
          circle = new($sformatf("circle_%0d", circle_id++), points);
          shape_reporter#(circle_c)::add_shape(circle);
          result = circle;
        end
        3: begin
          triangle_c triangle;
          triangle = new($sformatf("triangle_%0d", triangle_id++), points);
          shape_reporter#(triangle_c)::add_shape(triangle);
          result = triangle;
        end
        4: begin
          if (is_rectangle(points)) begin
            rectangle_c rectangle;
            rectangle = new($sformatf("rectangle_%0d", rectangle_id++), points);
            shape_reporter#(rectangle_c)::add_shape(rectangle);
            result = rectangle;
          end else begin
            polygon_c polygon;
            polygon = new($sformatf("polygon_%0d", polygon_id++), points);
            shape_reporter#(polygon_c)::add_shape(polygon);
            result = polygon;
          end
        end
        default: begin
          polygon_c polygon;
          polygon = new($sformatf("polygon_%0d", polygon_id++), points);
          shape_reporter#(polygon_c)::add_shape(polygon);
          result = polygon;
        end
      endcase

      return result;
    endfunction

  endclass : shape_factory

endpackage : shape_pkg
