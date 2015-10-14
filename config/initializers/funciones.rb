class String
  def letra_dni
    return nil if !/^[XYZ\d]\d{7,7}$/.match(self.upcase)
    n = "XYZ".index(self[0].upcase)
    num = (n ? (n.to_s+self[1..-1]).to_i : num = self.to_i)
    'TRWAGMYFPDXBNJZSQVHLCKE'[num % 23]
  end

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

    candidate_digit = 10 - ( (a+b) % 10)
    candidate_letter = "JABCDEFGHI"[candidate_digit,1]

    control_digit = self[8,1]
    control_digit == candidate_digit.to_s || control_digit ==
      candidate_letter
  end

  def iban?
    return true if self.length == 0
    len = {
      AL: 28, AD: 24, AT: 20, AZ: 28, BE: 16, BH: 22, BA: 20, BR: 29,
      BG: 22, CR: 21, HR: 21, CY: 28, CZ: 24, DK: 18, DO: 28, EE: 20,
      FO: 18, FI: 18, FR: 27, GE: 22, DE: 22, GI: 23, GR: 27, GL: 18,
      GT: 28, HU: 28, IS: 26, IE: 22, IL: 23, IT: 27, KZ: 20, KW: 30,
      LV: 21, LB: 28, LI: 21, LT: 20, LU: 20, MK: 19, MT: 31, MR: 27,
      MU: 30, MC: 27, MD: 24, ME: 22, NL: 18, NO: 15, PK: 24, PS: 29,
      PL: 28, PT: 25, RO: 24, SM: 27, SA: 24, RS: 22, SK: 24, SI: 19,
      ES: 24, SE: 24, CH: 21, TN: 24, TR: 26, AE: 23, GB: 22, VG: 24
    }

    # Ensure upper alphanumeric input.
    self.delete! " \t"
    return false unless self =~ /^[\dA-Z]+$/

    # Validate country code against expected length.
    cc = self[0, 2].to_sym
    return false unless self.size == len[cc]

    # Shift and convert.
    iban = self[4..-1] + self[0, 4]
    iban.gsub!(/./) { |c| c.to_i(36) }

    if iban.to_i % 97 == 1
      return true
    else
      return false
    end
  end

end