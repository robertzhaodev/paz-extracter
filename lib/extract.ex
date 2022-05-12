defmodule Extract do
  @file_name "resources/pad00001.paz"
  @save_path "resources/pad00001/"

  def start() do
    @file_name
    |> File.read()
    |> uncompress()
    |> delete_file()
    |> compress
  end

  def uncompress({:ok, bin}) do
    <<dumy::size(32), paz_files::size(32), names_size::size(32), rest::binary>> = bin

    paz_files = <<paz_files::32>> |> :binary.decode_unsigned(:little)
    names_length = <<names_size::32>> |> :binary.decode_unsigned(:little)

    # why?
    offset = paz_files * 4 * 6

    names = binary_part(rest, offset, names_length) |> :binary.split([<<0>>], [:global])

    file_details =
      for i <- 0..(paz_files - 1) do
        index = i * 24

        hash = binary_part(rest, index + 0, 4) |> :binary.decode_unsigned(:little)
        folder_num = binary_part(rest, index + 4, 4) |> :binary.decode_unsigned(:little)
        file_num = binary_part(rest, index + 8, 4) |> :binary.decode_unsigned(:little)
        offset = binary_part(rest, index + 12, 4) |> :binary.decode_unsigned(:little)
        zsize = binary_part(rest, index + 16, 4) |> :binary.decode_unsigned(:little)
        size = binary_part(rest, index + 20, 4) |> :binary.decode_unsigned(:little)

        path = @save_path <> Enum.at(names, folder_num) <> Enum.at(names, file_num)

        if(!File.exists?(path)) do
          IO.puts("Created #{path}")
          File.mkdir_p(Path.dirname(path))
        end

        file_content =
          if(size > zsize) do
            :binary.part(bin, offset, zsize) |> :zlib.uncompress()
          else
            :binary.part(bin, offset, size)
          end

        File.write(path, file_content)

        [hash, zsize, size, path]
      end

    [dumy, paz_files, names, file_details]
  end

  def delete_file([dumy, paz_files, names, file_details]) do
    file_to_delete = "res/stringtable/loc/en/languagedata_en_0_105.loc"
    (@save_path <> name) |> File.rm(file_to_delete)

    paz_files = paz_files - 1
    names = Enum.filter(name, fn n -> n != languagedata_en_0_105.loc end)

    names =
      Enum.filter(
        file_details,
        fn [hash, zsize, size, path] ->
          String.match?(path, file_to_delete)
        end
      )

    bin
  end
end

def compress() do
end

Extract.start()
