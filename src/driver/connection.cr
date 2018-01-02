module RethinkDB
  abstract class DriverConnection
    abstract def authorize(user : String, password : String)
    abstract def use(db_name : String)
    abstract def start
    abstract def run(term : ReQL::Term::Type, runopts : Hash) : Datum | Cursor
    abstract def close
  end

  struct Datum
    @value : Array(Datum) | Bool | Float64 | Hash(String, Datum) | Int64 | Int32 | Time | Bytes | String | Nil

    def initialize(value : Datum | Array | Bool | Float64 | Hash | Int64 | Int32 | Time | Bytes | String | Nil)
      case value
      when Datum
        @value = value.@value
      when Array
        @value = value.map { |x| Datum.new(x).as Datum }
      when Hash
        obj = {} of String => Datum
        value.each do |(k, v)|
          obj[k.to_s] = Datum.new(v)
        end
        @value = obj
      else
        @value = value
      end
    end

    def inspect(io)
      @value.inspect(io)
    end

    def datum
      self
    end

    def ==(other)
      @value == Datum.new(other).@value
    end

    def !=(other)
      @value != Datum.new(other).@value
    end

    def array
      @value.as Array(Datum)
    end

    def hash
      @value.as Hash(String, Datum)
    end

    def bool
      @value.as Bool
    end

    def string
      @value.as String
    end

    def float
      @value.as(Float64 | Int64 | Int32).to_f64
    end

    def int64
      @value.as(Float64 | Int64 | Int32).to_i64
    end

    def array?
      @value.as? Array(Datum)
    end

    def hash?
      @value.as? Hash(String, Datum)
    end

    def bool?
      @value.as? Bool
    end

    def string?
      @value.as? String
    end

    def float?
      @value.as?(Float64 | Int64 | Int32).try &.to_f64
    end

    def int64?
      @value.as?(Float64 | Int64 | Int32).try &.to_i64
    end
  end

  abstract class Cursor
    include Iterator(Datum)

    abstract def next

    def datum
      Datum.new to_a
    end
  end

  module DSL
    module R
      def self.connect(host : String)
        connect({"host" => host})
      end

      def self.connect(opts = {} of String => Nil)
        opts = {
          "host"     => "localhost",
          "port"     => 28015,
          "db"       => "test",
          "user"     => "admin",
          "password" => "",
        }.merge(opts.to_h)

        conn = RemoteConnection.new(opts["host"].as(String), opts["port"].as(Number).to_i)
        conn.authorize(opts["user"].as(String), opts["password"].as(String))
        conn.use(opts["db"].as(String))
        conn.start
        conn
      end

      def self.local_database(data_path)
        conn = LocalConnection.new(data_path)
        conn.start
        conn
      end
    end
  end
end
