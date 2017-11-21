def importa_seed(modelo)
  return if modelo.count != 0

  puts modelo.name.pluralize.split('::').join(' ')

  tabla  = modelo.table_name
  cols   = modelo.column_names
  modulo = modelo.name.include?('::') ? "/modulos/#{modelo.name.split('::')[0].downcase}" : ''
  csv    = "#{modelo.name.split('::')[-1].downcase}.csv"
  campos = File.open("#{Rails.root}#{modulo}/db/#{csv}", 'r').gets.chomp
  cmpadd = campos.split(',').select {|c| !cols.include?(c)}

  ActiveRecord::Base.connection.reset_pk_sequence!(tabla)
  sql_exe "ALTER TABLE #{tabla} " + cmpadd.map{|c| "ADD COLUMN #{c} CHARACTER VARYING"}.join(',') if !cmpadd.empty?
  sql_exe "COPY #{tabla} (#{campos}) FROM '#{Rails.root}#{modulo}/db/#{csv}' CSV HEADER"

  yield if block_given?

  sql_exe "ALTER TABLE #{tabla} " + cmpadd.map{|c| "DROP COLUMN #{c}"}.join(',') if !cmpadd.empty?

  modeloh = modelo.name.sub('::', '::H')
  if Object.const_defined?(modeloh)
    tablah = modeloh.constantize.table_name
    sql_exe "TRUNCATE #{tablah} RESTART IDENTITY"
    sql_exe "INSERT INTO #{tablah} (id#{cols.join(',')}) SELECT * FROM #{tabla}"
    sql_exe "UPDATE #{tablah} SET created_by_id = '1', created_at = '#{Nimbus.now.to_s}'"
  end
end
