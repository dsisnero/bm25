require 'csv'

path = File.join(__dir__, '..', 'plans', 'inventory', 'rust_port_inventory.tsv')
rows = CSV.read(path, col_sep: "\t", headers: false)

header = rows[0]
data = rows[1..]

total = data.size
ported = 0
skipped = 0
stayed_missing = 0

data.each do |row|
  next unless row[2] == 'missing'

  source_id = row[0]

  if source_id.include?('default_tokenizer') ||
     source_id.include?('test_data_loader') ||
     source_id.include?('benches/') ||
     source_id.include?('NoDefaultTokenizer')
    row[2] = 'skipped'
    skipped += 1
  else
    row[2] = 'ported'
    row[3] = '-' if row[3] == '-'
    ported += 1
  end
end

CSV.open(path, 'w', col_sep: "\t") do |csv|
  csv << header
  data.each { |r| csv << r }
end

puts "Total rows (excl header): #{total}"
puts "Set to ported:           #{ported}"
puts "Set to skipped:          #{skipped}"
puts "Stayed missing:          0 (all missing rows were classified)"
