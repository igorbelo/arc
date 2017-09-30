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
    case read_file(source_file) do
      {:ok, file_content} ->
        tmp_file = System.tmp_dir <> uuid <> Path.extname(source_file)
        File.write(tmp_file, file_content)
        {:ok, tmp_file}
      error -> error
    end
  end

  defp convert(file, [dimensions: dimensions]) when dimensions do
    converted_files = Enum.map(dimensions, fn(dimension) ->
      System.cmd("convert", [file, "-resize", dimension, "#{file}-#{dimension}"])
      "#{file}-#{dimension}"
    end)
    {:ok, [file] ++ converted_files}
  end

  defp convert(file, _options) do
    {:ok, [file]}
  end

  defp store_all_files(files, options) do
    files = Enum.map(files, fn(file) ->
      destination_path = destination_path(file, options)
      destination_file = destination_file(destination_path, file, options)
      case File.cp(file, destination_file) do
        :ok -> Path.expand(destination_file)
        error -> error
      end
    end)
    {:ok, files}
  end

  defp uuid do
    length = 32
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end

  defp destination_path(file, options) do
    path = options[:definition].storage_dir(file, options)
    if !File.exists?(path), do: File.mkdir_p(path)
    path
  end

  defp destination_file(path, file, options) do
    Path.join(path, Path.basename(file))
  end
end
