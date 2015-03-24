class Store
  def initialize
    @data = {}
  end

  def get(id)
    @data[id]
  end

  def set(id, client_data)
    @data[id] = client_data
  end
end
