class Store
  def initialize
    @data = {}
  end

  def get(attr)
    @data[attr].dup if @data.key?(attr)
  end

  def set(attr, client_data)
    @data[attr] = client_data
  end
end
