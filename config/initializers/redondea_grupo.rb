# Método para repartir proporcionalmente tot entre todos los números
# del array nums redondeados a "decimales". Devuelve un array con el resultado.

def redondea_grupo(tot:, nums:, decimales:)
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