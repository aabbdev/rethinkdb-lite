require "./virtual_table"

module Storage
  struct VirtualDbConfigTable < VirtualTable
    @@mutex = Mutex.new

    def initialize(manager : Manager)
      super("db_config", manager)
    end

    def replace(key, durability : ReQL::Durability? = nil)
      id = extract_uuid({"id" => key}, "id")

      after_commit = nil

      @@mutex.synchronize do
        existing_info = @manager.kv.get_db(id)
        new_row = yield encode(existing_info)

        if new_row.nil?
          # Delete
          raise "TODO: Delete database"
        end
        info = decode(new_row)

        if existing_info.nil?
          # Insert
          if info.name == "rethinkdb" || @manager.lock.synchronize { @manager.databases.has_key?(info.name) }
            raise ReQL::OpFailedError.new("Database `#{info.name}` already exists")
          end

          @manager.kv.save_db(info)

          after_commit = ->{ @manager.lock.synchronize { @manager.database_by_id[info.id] = @manager.databases[info.name] = Manager::Database.new(info) } }
          next
        end

        if existing_info != info
          # Update
          raise "TODO: Update database"
        end
      end

      after_commit.try &.call
    end

    private def encode(info : KeyValueStore::DatabaseInfo)
      ReQL::Datum.new({
        "id"   => info.id.to_s,
        "name" => info.name,
      }).hash_value
    end

    private def decode(obj)
      info = KeyValueStore::DatabaseInfo.new
      check_extra_keys(obj, {"id", "name"})
      info.id = extract_uuid(obj, "id")
      info.name = extract_db_name(obj, "name")
      info
    end

    def get(key)
      id = UUID.new(key.string_value) rescue return nil
      encode(@manager.kv.get_db(id))
    end

    def scan
      @manager.kv.each_db do |info|
        yield encode(info)
      end
    end
  end
end
