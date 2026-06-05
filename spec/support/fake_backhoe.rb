class FakeBackhoe
  attr_reader :loaded_path, :loaded_content, :loaded_drop_and_create

  def dump path, data: "DATA"
    File.write(path, data)
  end

  def load path, drop_and_create: false
    @loaded_path = path
    @loaded_content = File.binread(path)
    @loaded_drop_and_create = drop_and_create
  end
end

