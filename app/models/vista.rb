class Vista < ActiveRecord::Base
  around_save :marshal
  after_initialize :unmarshal

  def marshal
    data = self.data
    self.data = Marshal.dump(data)
    yield
    self.data = data
  end

  def unmarshal
    self.data = Marshal.load(self.data) if self.id.to_i != 0
  end
  #serialize :data
end
