require "../reql/term"
require "../reql/terms/*"

macro if_defined(x)
  {% if x.resolve? %}
    {{yield}}
  {% end %}
end

module RethinkDB
  module DSL
    module R
      @@next_var_i = Atomic(Int64).new(1i64)
      alias Type = Array(Type) | Bool | Float64 | Hash(String, Type) | Int64 | Int32 | String | Nil | Time | R

      def self.reset_next_var_i
        @@next_var_i.set(1i64)
      end

      def self.convert_type(x : R, max_depth)
        x.val.as(ReQL::Term::Type)
      end

      def self.convert_type(x : ReQL::Term, max_depth)
        x.as(ReQL::Term::Type)
      end

      def self.convert_type(x : Int32 | Bytes | Time, max_depth)
        x.as(ReQL::Term::Type)
      end

      def self.convert_type(x : JSON::Any, max_depth)
        convert_type(x.raw, max_depth)
      end

      def self.convert_type(x : Int, max_depth)
        x.to_i64.as(ReQL::Term::Type)
      end

      def self.convert_type(x : Float, max_depth)
        x.to_f64.as(ReQL::Term::Type)
      end

      def self.convert_type(x : Array, max_depth)
        if max_depth <= 0
          raise ReQL::DriverCompileError.new "Maximum expression depth exceeded (you can override this with `r.expr(X, MAX_DEPTH)`)"
        end

        x.map { |y| convert_type(y, max_depth - 1).as(ReQL::Term::Type) }.as(ReQL::Term::Type)
      end

      def self.convert_type(x : Hash, max_depth)
        if max_depth <= 0
          raise ReQL::DriverCompileError.new "Maximum expression depth exceeded (you can override this with `r.expr(X, MAX_DEPTH)`)"
        end

        h = {} of String => ReQL::Term::Type
        x.each do |(k, v)|
          unless k.is_a? String || k.is_a? Symbol
            raise ReQL::CompileError.new "Object keys must be strings or symbols."
          end
          h[k.to_s] = convert_type v, max_depth - 1
        end
        h.as(ReQL::Term::Type)
      end

      def self.convert_type(x : NamedTuple, max_depth)
        convert_type x.to_h, max_depth
      end

      def self.convert_type(x : Bool | Float64 | Int64 | String | ReQL::Term | Nil, max_depth)
        x.as(ReQL::Term::Type)
      end

      def self.to_json_any(val : JSON::Any::Type)
        JSON::Any.new(val)
      end

      def self.to_json_any(val : Int32)
        JSON::Any.new(val.to_i64)
      end

      def self.to_json_any(val : Array)
        JSON::Any.new(val.map { |x| to_json_any(x) })
      end

      def self.to_json_any(val : Hash)
        JSON::Any.new(val.map { |(k, v)| {k.to_s, to_json_any(v)} })
      end

      def self.make_var_i
        @@next_var_i.add(1)
      end

      def self.expr(*args)
        r(*args)
      end

      getter val : ReQL::Term::Type

      def inspect(io)
        @val.inspect io
      end

      def run(conn, runopts : Hash = {} of String => Nil)
        conn.run(@val, RunOpts.new(runopts))
      end

      def +(other)
        add(other)
      end

      def -(other)
        sub(other)
      end

      def *(other)
        mul(other)
      end

      def /(other)
        div(other)
      end

      def %(other)
        mod(other)
      end

      def ==(other)
        eq(other)
      end

      def !=(other)
        ne(other)
      end

      def [](arg)
        bracket(arg)
      end

      def >(arg)
        gt(arg)
      end

      def >=(arg)
        ge(arg)
      end

      def <(arg)
        lt(arg)
      end

      def <=(arg)
        le(arg)
      end

      def &(arg)
        and(arg)
      end

      def |(arg)
        or(arg)
      end

      def ~
        not()
      end
    end

    def r
      R
    end

    def r(val, max_depth : Int = 20)
      RExpr.new(val, max_depth)
    end

    struct RExpr
      include R

      def initialize(val, max_depth)
        @val = R.convert_type(val, max_depth)
      end
    end

    {% for term_type in ReQL::TermType.constants %}
      {% name = term_type.stringify.downcase %}
      {% term_class = (term_type.stringify.split("_").map(&.capitalize).join("") + "Term").id %}

      struct R{{name.id}}
        include R

        def initialize(*args, **options)
          @val = ReQL::{{term_class}}.new(
            args.to_a.map { |x| R.convert_type(x, 20).as(ReQL::Term::Type) },
            options.to_h.map { |k, v| {k.to_s, R.to_json_any(v)}.as({String, JSON::Any}) }.to_h
          )
        end

        def initialize(*args, **options, &block : Int32, R, R, R, R, R, R, R -> ReQL::Term::Type)
          max_depth = 1000
          vari = {R.make_var_i, R.make_var_i, R.make_var_i, R.make_var_i, R.make_var_i, R.make_var_i, R.make_var_i}.map(&.as(ReQL::Term::Type))
          vars = vari.map { |i| RExpr.new(ReQL::VarTerm.new([i.as(ReQL::Term::Type)], nil), max_depth).as(R) }
          block = ReQL::FuncTerm.new([vari.to_a.map(&.as(ReQL::Term::Type)).as(ReQL::Term::Type), block.call(max_depth - 1, *vars)].map(&.as(ReQL::Term::Type)), nil).as(ReQL::Term::Type)
          initialize(*args, block, **options)
        end
      end

      module R
        def self.{{name.id}}(*args, **options)
          R{{name.id}}.new(*args, **options)
        end

        def {{name.id}}(*args, **options)
          R{{name.id}}.new(self, *args, **options)
        end

        def self.{{name.id}}(*args, **options, &block : R, R, R, R, R, R, R -> X) forall X
          R{{name.id}}.new(*args, **options) { |max_depth, a, b, c, d, e, f, g| R.convert_type(block.call(a, b, c, d, e, f, g), max_depth) }
        end

        def {{name.id}}(*args, **options, &block : R, R, R, R, R, R, R -> X) forall X
          R{{name.id}}.new(self, *args, **options) { |max_depth, a, b, c, d, e, f, g| R.convert_type(block.call(a, b, c, d, e, f, g), max_depth) }
        end
      end
    {% end %}
  end
end

class Object
  def +(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).add(other)
  end

  def -(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).sub(other)
  end

  def *(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).mul(other)
  end

  def /(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).div(other)
  end

  def %(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).mod(other)
  end

  def ==(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).eq(other)
  end

  def !=(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).ne(other)
  end

  def >(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).gt(other)
  end

  def >=(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).ge(other)
  end

  def <(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).lt(other)
  end

  def <=(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).le(other)
  end

  def &(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).and(other)
  end

  def |(other : RethinkDB::DSL::R)
    RethinkDB::DSL::RExpr.new(self, 1).or(other)
  end
end
