class Vista < ActiveRecord::Base
  after_initialize :unmarshal
=begin
  around_save :marshal

  def marshal
    data = self.data
    self.data = Marshal.dump(data)
    yield
    self.data = data
  end
=end

  def unmarshal
    self.data = Marshal.load(self.data) if self.id.to_i != 0
  end

  alias save_vista save

  def save
    d = self.data
    self.data = Marshal.dump(d)
    save_vista
    self.data = d
  end
end
