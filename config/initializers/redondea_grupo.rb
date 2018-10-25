def redondea_grupo(tot:, nums:, decimales:)
  return nums if (tot.class != BigDecimal && tot.class != Float) || nums.class != Array || decimales.class != Fixnum

  redondeado = nums.map{|n| n.round(decimales)}
  diferencia = redondeado.reduce(tot){|t,n| t - n}.round(decimales)
  if diferencia != 0
    (diferencia > 0) ? signo = 1 : signo = -1
    (decimales == 0) ? paso = 1 : paso = 1.0 / 10 ** decimales
    diferencia *= signo
    decis = nums.map.with_index{|n,i| [i,n.modulo(1)]}.to_h.sort_by{|c,v| -v}.to_h
    decis.each{|c,v|
      break if diferencia == 0
      paso = diferencia if diferencia < paso
      redondeado[c] += paso * signo
      diferencia -= paso
    }
  end
  redondeado
end

def redondea_g(tot:, nums:, decimales:)
  tot = tot.round(decimales).to_d
  suma = nums.reduce(:+)
  mindif = [99, 0]
  maxdif = [-99, 0]
  nsuma = 0.to_d
  nums.map!.with_index{|n, i|
    nn = tot*n/suma
    nnr = nn.round(decimales)
    d = nn - nnr
    mindif = [d, i] if d < mindif[0]
    maxdif = [d, i] if d > maxdif[0]
    nsuma += nnr
    nnr
  }
  dif = tot - nsuma
  nums[dif > 0 ? maxdif[1] : mindif[1]] += dif
  nums
end