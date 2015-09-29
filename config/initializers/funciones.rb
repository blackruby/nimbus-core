class String
  def letra_dni
    return nil if !/^[XYZ\d]\d{7,7}$/.match(self.upcase)
    n = "XYZ".index(self[0].upcase)
    num = (n ? (n.to_s+self[1..-1]).to_i : num = self.to_i)
    'TRWAGMYFPDXBNJZSQVHLCKE'[num % 23]
  end
end
