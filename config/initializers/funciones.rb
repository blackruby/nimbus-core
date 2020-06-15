class String
  def letra_dni
    return nil if !/^[XYZ\d]\d{7,7}$/.match(self.upcase)
    n = "XYZ".index(self[0].upcase)
    num = (n ? (n.to_s+self[1..-1]).to_i : num = self.to_i)
    'TRWAGMYFPDXBNJZSQVHLCKE'[num % 23]
  end
  def cp2provincia
    listaprovincias = ["ALAVA","ALBACETE","ALICANTE","ALMERIA","AVILA","BADAJOZ","BALEARES",
      "BARCELONA","BURGOS","CACERES","CADIZ","CASTELLON","CIUDAD REAL",
      "CORDOBA","LA CORU▒A","CUENCA","GERONA","GRANADA","GUADALAJARA",
      "GUIPUZCOA","HUELVA","HUESCA","JAEN","LEON","LERIDA","LA RIOJA","LUGO",
      "MADRID","MALAGA","MURCIA","NAVARRA","ORENSE","ASTURIAS","PALENCIA",
      "LAS PALMAS","PONTEVEDRA","SALAMANCA","STA.CRUZ DE TENERIFE",
      "CANTABRIA","SEGOVIA","SEVILLA","SORIA","TARRAGONA","TERUEL","TOLEDO",
      "VALENCIA","VALLADOLID","VIZCAYA","ZAMORA","ZARAGOZA", "CEUTA","MELILLA"]

    return listaprovincias[self[0..1].to_i-1]
  end

  # Validates NIF
  def validate_nif(value)
    letters = "TRWAGMYFPDXBNJZSQVHLCKE"
    check = value.slice!(value.length - 1..value.length - 1).upcase
    calculated_letter = letters[value.to_i % 23].chr
    return check === calculated_letter
  end
  # Validates CIF
  def validate_cif(value)
    letter = value.slice!(0).chr.upcase
    check = value.slice!(value.length - 1).chr.upcase

    n1 = n2 = 0
    for idx in 0..value.length - 1
      number = value.slice!(0).chr.to_i
      if (idx % 2) != 0
        n1 += number
      else
        n2 += ((2*number) % 10) + ((2 * number) / 10)
      end
    end
    calculated_number = (10 - ((n1 + n2) % 10)) % 10
    calculated_number = 10 if calculated_number == 0
    check = '10' if check == '0'
    calculated_letter = (64 + calculated_number).chr

    if letter.match(/[QRPNSW]/)
      return check.to_s == calculated_letter.to_s
    else
      return check.to_i == calculated_number.to_i
    end
  end
  # Validates NIE
  def validate_nie(value)
    case value[0]
      when 'Y'
        value[0] = '1'
      when 'Z'
        value[0] = '2'
      else
        value[0] = '0'
    end
    value.slice(0) if value.size > 9
    validate_nif(value)
  end
#=begin

  def dni?
    return true if self.length == 0
    return false unless self.length == 9
    value = self.clone

    case
      when value.match(/[0-9]{8}[a-z]/i)
        return validate_nif(value)
      when value.match(/[a-jn-w][0-9]{7}[0-9a-z]/i)
        return validate_cif(value)
      when value.match(/[klmxyz][0-9]{7,8}[a-z]/i)
        return validate_nie(value)
    end
    return false
  end

#=end
=begin
  def add_digits_from_int(n)
    digits = str_to_int_array(n.to_s)
    digits.inject(0) { |acum, n| acum + n }
  end

  def str_to_int_array(str)
    (0..(str.length-1)).inject([]) { |result, pos| result <<
      str[pos,1].to_i }
  end

  def dni?
    return true if self.length == 0
    return false unless self.length == 9

    # We also accept NIFs, NIF validation algoritm taken from:
    # http://es.wikipedia.org/wiki/Algoritmo_para_obtene...
      if self.match(/\D(\d{8})/)
        nif_letter = self[0,1]
        nif_digits = self[1,8]
      elsif self.match(/(\d{8})\D/)
        nif_letter = self[-1, 1]
        nif_digits = self[0,8]
      end
    nif_addition = nif_digits.to_i % 23
    return true if nif_letter && nif_digits &&
      'TRWAGMYFPDXBNJZSQVHLCKE'[nif_addition,1] == nif_letter

    # CIF validation algorithm taken from:
    # http://club.telepolis.com/jagar1/Ccif.htm
    return false unless "ABCDEFGHNPQS".include? self[0,1]
    central_digits = str_to_int_array(self[1,7])

    a = [1,3,5].inject(0) { |acum, pos| central_digits[pos] + acum }
    b = [0,2,4,6].inject(0) { |acum, pos| acum +
      add_digits_from_int(central_digits[pos] * 2) }

    candidate_digit = (10 - ( (a+b) % 10)) % 10
    candidate_letter = "JABCDEFGHI"[candidate_digit,1]

    control_digit = self[8,1]
    control_digit == candidate_digit.to_s || control_digit ==
      candidate_letter
  end
=end

  LenIbanPaises = {
    AL: 28, AD: 24, AT: 20, AZ: 28, BE: 16, BH: 22, BA: 20, BR: 29,
    BG: 22, CR: 21, HR: 21, CY: 28, CZ: 24, DK: 18, DO: 28, EE: 20,
    FO: 18, FI: 18, FR: 27, GE: 22, DE: 22, GI: 23, GR: 27, GL: 18,
    GT: 28, HU: 28, IS: 26, IE: 22, IL: 23, IT: 27, KZ: 20, KW: 30,
    LV: 21, LB: 28, LI: 21, LT: 20, LU: 20, MK: 19, MT: 31, MR: 27,
    MU: 30, MC: 27, MD: 24, ME: 22, NL: 18, NO: 15, PK: 24, PS: 29,
    PL: 28, PT: 25, RO: 24, SM: 27, SA: 24, RS: 22, SK: 24, SI: 19,
    ES: 24, SE: 24, CH: 21, TN: 24, TR: 26, AE: 23, GB: 22, VG: 24
  }

  # Método para validar un IBAN. El argumento (opcional) es lo que se devolverá en caso de que la cadena esté vacía
  def iban?(vacio:  true)
    # Quitar caracteres especiales
    iban = self.gsub(/[\s-]/, '')

    # Retornar si está vacío
    return vacio if iban.empty?

    # Retornar si hay caracteres diferentes de letras o números
    return false unless iban =~ /^[\dA-Z]+$/

    # Validar longitud en función del país
    return false unless iban.size == LenIbanPaises[iban[0, 2].to_sym]

    # Finalmente será válido si cumple la siguiente regla
    (iban[4..-1] + iban[0, 4]).gsub(/./){|c| c.to_i(36)}.to_i % 97 == 1
  end

  # Devuelve una cadena convertida a IBAN. Si self ya es un IBAN se retorna a sí mismo
  # y si es un CCC se convierte a IBAN. En cualquier otro caso devuelve nil.
  def to_iban(sep: '-')
    return self if self.iban?

    ccc = self.gsub(/[\s-]/, '')

    return nil unless ccc.ccc?

    resto = ''
    [0, 5, 10, 15].each {|i|
      codigo = (resto + ccc[i, 5]).to_i
      resto = (codigo % 97).to_s
    }

    codigo = (resto.to_s + '142800').to_i
    resto = codigo % 97

    format('ES%02d%s%s%s%s%s%s%s%s%s%s', 98 - resto, sep, ccc[0, 4], sep, ccc[4, 4], sep, ccc[8, 4], sep, ccc[12, 4], sep, ccc[16, 4])
  end

  # Convierte self a un IBAN. Si self ya es un IBAN se queda inalterado,
  # si es un CCC se convierte a IBAN. En cualquier otro caso se queda inalterado.
  # Devuelve true o false en función de si el contenido es un IBAN correcto
  # o se ha podido convertir a un IBAN correcto, por lo que también vale de
  # método de validación. Si la cena está vacía se queda inalterada y devuelve
  # lo indicado por el argumento "vacio" (true por defecto)
  def to_iban!(sep: '-', vacio: true)
    return vacio if self.gsub(/[\s-]/, '').empty?

    iban = to_iban sep: sep
    if iban
      self.replace(iban)
      true
    else
      false
    end
  end

  def ccc?(vacio: true)
    ccc = self.gsub(/[\s-]/, '')

    # Retornar si está vacío
    return vacio if ccc.empty?

    return false unless ccc.size == 20

    # Retornar si hay caracteres diferentes de números
    return false unless ccc =~ /^\d+$/

    obtener_dc('00' + ccc[0, 8]) == ccc[8].to_i && obtener_dc(ccc[10..-1]) == ccc[9].to_i
  end

  private def obtener_dc(value)
    valores = [1,2,4,8,5,10,9,7,3,6]
    control = 0

    (0..9).each {|i| control = control + value[i].to_i * valores[i]}
    control = 11 - (control % 11)
    if control == 11
      control = 0
    elsif control == 10
      control = 1
    end

    control
  end

  # Método para decidir si un número (n) está dentro de la cadena self (con la notación: a,b,c-d,e...)
	def rango(n)
		n = n.to_i
		self.tr(' ', '').split(',').each {|r|
			if r.include?('-')
				rs = r.split('-')
				d = rs[0].to_i
				h = rs[1].to_i
				return(true) if n >= d and (n <= h or h == 0)
			else
				return(true) if n == r.to_i
			end
		}
		false
	end

  # Método que devuelve una array con todos los valores incluidos en la cadena self (con la notación: a,b,c-d,e...)
	def expande_rango
    res = []
		self.tr(' ', '').split(',').each {|r|
			if r.include?('-')
				rs = r.split('-')
				(rs[0].to_i..rs[1].to_i).each{|i| res << i}
			else
				res << r.to_i
			end
		}
		res
	end

  # Este método busca todos los macros (expresiones que empiezan con "@"
  # y a continuación tienen un conjunto de letras, números o "_"), y por
  # cada uno de ellos llama al bloque que hay que pasarle, para que éste
  # lo evalúe y devuelva el valor por el que será sustituido. Retorna otra
  # cadena en la que todos los macros han sido sustituidos. Admite un 
  # argumento (:eval) que significa que, además de sustituir los macros,
  # la expresión final resultante será evaluada numéricamente. En este 
  # caso, el método retornará el valor numérico resultante de evaluar la
  # expresión. Si la expresión no fuera evaluable, por tener errores o
  # caracteres diferentes a los estrictamente numéricos (números, y 
  # operaciones matemáticas), retornará el Bigdecimal especial NaN
  # (Not A Number).

  def expande_macros(ev = false)
    raise ArgumentError, "El argumento, de existir, debe de ser :eval" if ev && ev != :eval

    ns = self.dup
    ns.scan(/@\w+/).uniq.each {|m| ns.gsub!(m, yield(m[1..-1]).to_s)}
    if ev
      if ns.match(/[a-zA-Z]/)
        'NaN'.to_d
      else
        begin
          eval(ns)
        rescue Exception
          'NaN'.to_d
        end
      end
    else
      ns
    end
  end
end

def fecha_texto(fecha, formato = :default)
  if fecha.nil?
    ''
  else
    I18n.l(fecha, format: formato)
  end
end

def iban_mask(pais = 'ES')
  pais == 'ES' ? '?**99-9999-9999-9999-9999-9999' : '?**********************************'
end

def nim_tmpname(prefijo = '', sufijo = '')
  t = Time.now.strftime("%Y%m%d%H%M%S")
  "#{prefijo}nim-#{t}-#{$$}-#{rand(0x100000000).to_s(36)}#{sufijo}"
end

# Se debe recibir un código string y devuelve el dígito de control
def obtener_dc_codigobarras(ean13)
  checksum    = 0
  ean13_array = ean13.reverse.split('') # invertimos la cadena y convertimos en array
  ean13_array.each_with_index { |value, index|
    checksum    += value.to_i * (3 - 2 * (index.to_i % 2))
  }
  return ((10 - (checksum % 10)) % 10).to_s
end