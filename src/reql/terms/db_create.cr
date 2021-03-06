require "../term"

module ReQL
  class DbCreateTerm < Term
    prefix_inspect "db_create"

    def check
      expect_args 1
    end
  end

  class Evaluator
    def eval_term(term : DbCreateTerm)
      name = eval(term.args[0]).string_value

      unless name =~ /\A[A-Za-z0-9_-]+\Z/
        raise QueryLogicError.new "Database name `#{name}` invalid (Use A-Z, a-z, 0-9, _ and - only)."
      end

      db_config = @manager.get_table("rethinkdb", "db_config").not_nil!

      perform_writes do |writer|
        writer.insert(db_config, {
          "name" => Datum.new(name),
        })
      end

      Datum.new(Hash(String, Datum::Type).new)
    end
  end
end
