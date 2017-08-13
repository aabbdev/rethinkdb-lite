require "./stream"

module ReQL
  abstract class InfiniteStream < Stream
    def self.reql_name
      "STREAM"
    end

    private def err
      raise RuntimeError.new "Cannot use an infinite stream with an aggregation function (`reduce`, `count`, etc.) or coerce it to an array"
    end

    def to_datum_array
      err
    end

    def value
      err
    end

    def count
      err
    end
  end
end