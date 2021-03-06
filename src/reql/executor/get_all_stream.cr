require "./stream"
require "./row_value"
require "../../storage/*"

module ReQL
  struct GetAllStream < Stream
    class InternalData
      property channels = [] of Channel(RowValue | Nil | Exception)
    end

    def reql_type
      "STREAM"
    end

    def initialize(@table : Storage::AbstractTable, @keys : Array(Datum) | Set(Datum), @index : String)
      @internal = InternalData.new
    end

    def start_reading
      @keys.each do |key|
        channel = Channel(RowValue | Nil | Exception).new(16)
        @internal.channels << channel
        spawn do
          begin
            if @index == @table.primary_key
              @table.get(key).try { |row| channel.send RowValue.new(@table, row) }
            else
              @table.index_scan(@index, key, key) do |row|
                channel.send RowValue.new(@table, row)
              end
            end
            channel.send nil
          rescue Channel::ClosedError
          rescue error
            channel.send error
          end
        end
      end
    end

    def next_val
      return nil if @internal.channels.empty?
      idx, val = Channel.select(@internal.channels.map &.receive_select_action?)

      case val
      when Nil
        @internal.channels[idx].try &.close
        @internal.channels.reject! &.closed?
        return next_val
      when Exception
        @internal.channels[idx].try &.close
        @internal.channels.reject! &.closed?
        raise val
      else
        val
      end
    end

    def finish_reading
      @internal.channels.each &.close
      @internal.channels.clear
    end
  end
end
