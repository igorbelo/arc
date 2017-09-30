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
        {:ok, all_files} <- store_all_files(files, options) do
      {:ok, all_files}
    else
      error -> error
    end
  end

  defp read_file(source_file) do
    File.read(source_file)
  end

  defp store_tmp(source_file, options) do
    tmp_dir = Path.join(System.tmp_dir, uuid)
    File.mkdir(tmp_dir)
    case read_file(source_file) do
      {:ok, file_content} ->
        tmp_file = %Arc.File{
          path: tmp_dir,
          file_name: file_name(source_file, options)
        }
        File.write(Path.join(tmp_file.path, tmp_file.file_name), file_content)
        {:ok, tmp_file}
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

  defp store_all_files(files, options) do
    files = Enum.map(files, fn(file) ->
      destination_file = destination_file(file, options)
      case File.cp(Path.join(file.path, file.file_name), destination_file) do
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

  def file_name(file, options) when is_binary(file) do
    uuid <> Path.extname(file)
  end

  defp destination_file(file, options) do
    path = options[:definition].storage_dir(file, options)
    if !File.exists?(path), do: File.mkdir_p(path)
    Path.join(path, file.file_name)
  end
end
