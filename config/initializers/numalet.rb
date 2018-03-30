module Nimbus
  TextoUnidades = {
    '00'=>'','01'=>'un','02'=>'dos','03'=>'tres','04'=>'cuatro','05'=>'cinco','06'=>'seis','07'=>'siete','08'=>'ocho','09'=>'nueve',
    '10'=>'diez','11'=>'once','12'=>'doce','13'=>'trece','14'=>'catorce','15'=>'quince','16'=>'dieciséis','17'=>'diecisiete',
    '18'=>'dieciocho','19'=>'diecinueve','20'=>'veinte','21'=>'veintiún','22'=>'veintidós','23'=>'veintitrés',
    '24'=>'veinticuatro','25'=>'veinticinco','26'=>'veintiséis','27'=>'veintisiete','28'=>'veintiocho','29'=>'veintinueve',
  }
  TextoDecenas = {'3'=>'treinta','4'=>'cuarenta','5'=>'cincuenta','6'=>'sesenta','7'=>'setenta','8'=>'ochenta','9'=>'noventa'}
  TextoCentenas = {
    '0'=>'','1'=>'ciento','2'=>'doscientos','3'=>'trescientos','4'=>'cuatrocientos','5'=>'quinientos',
    '6'=>'seiscientos','7'=>'setecientos','8'=>'ochocientos','9'=>'novecientos'
  }

  def self.numalet(n:, gen: :n, suf: nil)
    return 'cero' if n == 0

    gen = gen.to_sym
    res = []
    ns = n.to_s
    ('0' * ((3 - ns.size%3)%3) + ns).scan(/.{3}/).reverse.each_with_index do |g, niv|
      if g == '100'
        pal = ['cien']
      else
        pal = [TextoCentenas[g[0]].dup]
        pal[0][-2] = 'a' if gen == :f && g[0] > '1' && niv < 2
        if TextoUnidades[g[1..2]]
          pal << TextoUnidades[g[1..2]].dup
        else
          pal << TextoDecenas[g[1]].dup
          pal << 'y ' + TextoUnidades['0' + g[2]] if g[2] != '0'
        end
        pal[-1][-2..-1] = 'una' if gen == :f && niv < 2 && pal[-1].ends_with?('n')
      end
      if niv.odd? 
        (g == '001' ? pal = ['mil'] : pal << 'mil') if g != '000'
      elsif niv == 2
        pal << (g == '001' ? 'millón' : 'millones')
      end
      pal.select! {|p| p != ''}
      res << pal.join(' ') unless pal.empty?
    end
    ret = res.reverse.join(' ')
    ret[-2..-1] = 'uno' if gen == :m && ret.ends_with?('n')
    ret << " #{n > 1 ? suf.pluralize : suf}" if suf
    ret
  end
end

class Numeric
  def texto(gen_manti: :n, gen_decim: :n, decim: 2, suf_manti: nil, suf_decim: nil, sep_decim: 'con')
    num = self.abs
    man = num.to_i
    dec = (num - man).round(decim).to_s[2..-1].to_i
    res = self < 0 ? 'menos ' : ''
    res << Nimbus.numalet(n: man, gen: gen_manti, suf: suf_manti)
    res << " #{sep_decim} " + Nimbus.numalet(n: dec, gen: gen_decim, suf: suf_decim) if dec != 0
    res
  end
end