if ARGV.empty?
  print "\nSintaxis: ruby #{$0} <modelo1> [<modelo2> ...]\n\n"
  exit
end

ARGV.each {|m|
  cad = File.read(m)
  icl = cad.index('class ')
  next unless icl
  iar = cad.index('ActiveRecord')
  next unless iar
  mod = cad[icl+6...iar].split('<')[0].strip
  modh = mod.split('::')
  modh[-1] = 'H' + modh[-1]
  modh = modh.join('::')
  if cad.sub!(/class +#{modh}.+?ActiveRecord.+?end/m, "class #{modh} < #{mod}\n  include Historico\nend")
    puts m
    File.write(m, cad)
  end
}