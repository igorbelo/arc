defmodule Arc.File do
  defstruct [:version, :source, :binary, :path]

  def new(options \\ []) do
    %Arc.File{
      version: options[:version],
      source: options[:source],
      binary: options[:binary]
    }
  end

  def read(file) do
    File.read(file.source)
  end
end
