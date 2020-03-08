require "../term"

module ReQL
  class GroupTerm < Term
    infix_inspect "group"

    def check
      expect_args 2, 3
    end
  end

  class Evaluator
    def eval_term(term : GroupTerm)
      target = eval(term.args[0])
      group_func = eval(term.args[1]).as_function

      result = [] of Hash(String, Datum)

      if term.args.size == 3
        aggregation_func = eval(term.args[2]).as_function

        stream_table = {} of Datum => GroupStream
        result_channel = Channel({Datum, Datum} | Exception).new

        group_count = 0

        target.each do |value|
          value = value.as_datum
          group = group_func.eval(self, {value}).as_datum
          stream = stream_table[group]?
          unless stream
            stream = stream_table[group] = GroupStream.new
            group_count += 1
            spawn do
              begin
                evaluator = Evaluator.new(@manager, @worker)
                evaluator.vars = @vars.dup
                evaluator.now = @now

                result_channel.send({
                  group,
                  aggregation_func.eval(evaluator, {stream.not_nil!}).as_datum,
                })
              rescue exception
                result_channel.send(exception)
              end
            end
          end
          stream.not_nil! << value
        end

        stream_table.each_value &.<<(nil)

        group_count.times do
          pair = result_channel.receive
          if pair.is_a? Exception
            raise pair
          end

          result << {
            "group"     => pair[0],
            "reduction" => pair[1],
          }
        end
      else
        groups = Hash(Datum, Array(Datum)).new { |h, k| h[k] = [] of Datum }

        target.each do |value|
          value = value.as_datum
          group = group_func.eval(self, {value}).as_datum
          groups[group] << value
        end

        groups.each do |(group, array)|
          result << {
            "group"     => group,
            "reduction" => Datum.new(array),
          }
        end
      end

      Datum.new(result)
    end
  end
end
