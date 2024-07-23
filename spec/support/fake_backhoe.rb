class FakeBackhoe
  def dump path, data: "DATA"
    File.write(path, data)
  end
end

