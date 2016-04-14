class Vista < ActiveRecord::Base
  before_save :marshal
  after_initialize :unmarshal

  def marshal
    self.data = Marshal.dump(self.data)
  end

  def unmarshal
    self.data = Marshal.load(self.data) if self.id.to_i != 0
  end
  #serialize :data
end
