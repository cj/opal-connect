Opal::Processor.instance_eval do
  def stubbed_files
    ::Opal::Config.stubbed_files
  end

  def stub_file(name)
    ::Opal::Config.stubbed_files << name.to_s
  end

  def dynamic_require_severity=(value)
    ::Opal::Config.dynamic_require_severity = value
  end
end
