require "yaml"

alias PgType = (Array(PG::Geo::Point) | Bool | Char | Float32 | Float64 | Int16 | Int32 | Int64 | JSON::Any | PG::Geo::Box | PG::Geo::Circle | PG::Geo::Line | PG::Geo::LineSegment | PG::Geo::Path | PG::Geo::Point | PG::Numeric | Slice(UInt8) | String | Time | UInt32 | Nil)

class HTTP::Server::Context
  property! crystal_service : CrystalService
end

class Kemal::PG < HTTP::Handler
  getter :pg
end

def pg_connect_from_yaml(yaml_file, capacity = 25, timeout = 0.1)
  kpg = Kemal::PG.new(
    Kemal::CrystalApi.url_from_yaml(yaml_file),
    capacity,
    timeout
  )
  Kemal.config.add_handler(kpg)

  kca = Kemal::CrystalApi.new(kpg.pg)
  Kemal.config.add_handler(kca)
end

class Kemal::CrystalApi < HTTP::Handler
  def initialize(@pg : ConnectionPool(PG::Connection))
    @crystal_service = CrystalService.new(@pg)
  end

  getter :crystal_service

  def call(context)
    context.crystal_service = @crystal_service
    call_next(context)
  end

  def self.url_from_yaml(path)
    config = YAML.parse(File.read(path))
    host = config["host"].to_s
    database = config["database"].to_s
    user = config["user"].to_s
    password = config["password"].to_s
    return "postgresql://#{user}:#{password}@#{host}/#{database}"
  end

end

class CrystalService
  def initialize(@pg : ConnectionPool(PG::Connection))
  end

  def execute_sql(sql)
    db = @pg.connection
    result = db.exec(sql)
    @pg.release
    return result
  end

  def get_all_objects(collection)
    sql = "select * from #{collection};"
    db = @pg.connection
    result = db.exec(sql)
    @pg.release
    return result
  end

  def get_object(collection, id)
    sql = "select * from #{collection} where id = #{id};"
    db = @pg.connection
    result = db.exec(sql)
    @pg.release
    return result
  end

  def escape_value(value)
    if value.is_a?(Int32)
      return value.to_s
    elsif value.is_a?(String)
      return "'" + value.to_s + "'"
    else
      return "'" + value.to_s + "'"
    end
  end

  def insert_object(collection, hash)
    columns = [] of String
    values = [] of String

    hash.keys.each do |column|
      columns << column
      value = hash[column]
      values << escape_value(value)
    end

    sql = "insert into #{collection} (#{columns.join(", ")}) values (#{values.join(", ")}) returning *;"

    db = @pg.connection
    result = db.exec(sql)
    @pg.release
    return result
  end

  def update_object(collection, db_id, hash)
    columns = [] of String
    values = [] of String

    hash.keys.each do |column|
      columns << column
      value = hash[column]
      values << escape_value(value)
    end

    sql = "update only #{collection} set (#{columns.join(", ")}) = (#{values.join(", ")}) where id = #{db_id} returning *;"

    db = @pg.connection
    result = db.exec(sql)
    @pg.release
    return result
  end

  def delete_object(collection, db_id)
    sql = "delete from only #{collection} where id = #{db_id} returning *;"

    db = @pg.connection
    result = db.exec(sql)
    @pg.release
    return result
  end


end
