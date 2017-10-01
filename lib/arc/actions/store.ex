defmodule Arc.Actions.Store do
  defmacro __using__(_) do
    quote do
      def store(source_file, options \\ []), do: Arc.Actions.Store.store(source_file, options ++ [definition: __MODULE__])
    end
  end

  def store(source_file, options) do
    definition = options[:definition]

    with :ok <- definition.validate(source_file, options),
        {:ok, tmp_file} <- store_tmp(source_file, options),
        {:ok, files} <- convert(tmp_file, options),
        {:ok, all_files} <- move_all_files(files, options) do
      {:ok, all_files}
    else
      error -> error
    end
  end

  defp store_tmp(source_file, options) do
    tmp_dir = Path.join(System.tmp_dir, uuid)
    File.mkdir(tmp_dir)
    original_file = Arc.File.new(version: :original, source: source_file)
    case Arc.File.read(original_file) do
      {:ok, file_content} ->
        file_name = file_name(original_file, options)
        destination = Path.join(tmp_dir, file_name)
        File.write(destination, file_content)
        {:ok, Arc.File.new(version: :original, source: destination)}
      error -> error
    end
  end

  # defp convert(file, [dimensions: dimensions]) when dimensions do
  #   converted_files = Enum.map(dimensions, fn(dimension) ->
  #     System.cmd("convert", [file, "-resize", dimension, "#{file}-#{dimension}"])
  #     %Arc.File{path: "#{file}-#{dimension}", version: dimension}
  #   end)
  #   {:ok, [%Arc.File{location: file, version: :original}] ++ converted_files}
  # end

  defp convert(file, _options) do
    {:ok, [file]}
  end

  defp move_all_files(files, options) do
    files = Enum.map(files, fn(file) ->
      destination_file = destination_file(file, options)
      case File.cp(file.source, destination_file) do
        :ok -> Path.expand(destination_file)
        error -> error
      end
    end)
    {:ok, files}
  end

  defp uuid do
    length = 32
    :crypto.strong_rand_bytes(length)
    |> Base.encode64
    |> binary_part(0, length)
    |> String.replace("/", "-")
  end

  def file_name(file, options) do
    Path.basename(file.source)
  end

  defp destination_file(file, options) do
    path = options[:definition].storage_dir(file, options)
    if !File.exists?(path), do: File.mkdir_p(path)
    Path.join(path, Path.basename(file.source))
  end
end
