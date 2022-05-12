defmodule Extract do
  @file_name "resources/pad00001.paz"
  @output_path "resources/pad00001-rm.paz"
  @save_path "resources/pad00001/"

  def start(_type, _args) do
    @file_name
    |> File.read()
    |> uncompress()
    |> delete_file()
    |> compress()

    fake_pid = spawn(fn -> nil end)
    {:ok, fake_pid}
  end

  def uncompress({:error, _}) do
    IO.puts("File #{@file_name} dose not exists!")
    exit(0)
  end

  def uncompress({:ok, bin}) do
    IO.puts(byte_size(bin))

    <<dumy::size(32), paz_files::size(32), names_size::size(32), rest::binary>> = bin

    dumy = <<dumy::32>> |> :binary.decode_unsigned(:little)
    paz_files = <<paz_files::32>> |> :binary.decode_unsigned(:little)
    names_length = <<names_size::32>> |> :binary.decode_unsigned(:little)

    # 24 bytes for each file info
    offset = paz_files * 24

    IO.puts("Paz file: #{paz_files}")
    IO.puts("Name lenght: #{names_length}")
    IO.puts("Offset: #{offset}")
    IO.puts("Start of file: #{offset + names_length}")

    names = binary_part(rest, offset, names_length) |> :binary.split([<<0>>], [:global])

    # IO.puts(names)

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
          # IO.puts("Created #{path}")
          File.mkdir_p(Path.dirname(path))
        end

        # IO.puts("#{hash}, #{folder_num}, #{file_num}, #{offset}, #{zsize}, #{size}")

        {file_content, bin_content} =
          if(size > zsize) do
            bin = :binary.part(bin, offset, zsize)
            # {:zlib.uncompress(bin), bin}
            {bin, bin}
          else
            bin = :binary.part(bin, offset, size)
            {bin, bin}
          end

        File.write(path, file_content)

        [hash, folder_num, zsize, size, path, bin_content]
      end

    [dumy, paz_files, names, file_details]
  end

  def delete_file([dumy, paz_files, names, file_details]) do
    file_to_delete = "res/stringtable/loc/en/languagedata_en_0_105.loc"
    (@save_path <> file_to_delete) |> File.rm()

    paz_files = paz_files - 1
    names = Enum.filter(names, fn n -> n != "languagedata_en_0_105.loc" end)

    file_details =
      Enum.filter(
        file_details,
        fn [_hash, _folder_num, _zsize, _size, path, _content] ->
          !String.match?(path, ~r/#{file_to_delete}/)
        end
      )

    [dumy, paz_files, names, file_details]
  end

  def compress([dumy, paz_files, names, file_details]) do
    names_bin = names |> Enum.join(<<0>>)
    names_length = byte_size(names_bin)

    header_bin = <<dumy::32-little, paz_files::32-little, names_length::32-little>>

    IO.puts("\n")
    # 24 bytes for each file info
    start_offset = paz_files * 24 + names_length

    {info_bin, file_bin} = create_files_bin(file_details, start_offset)

    bin = header_bin <> info_bin <> names_bin <> file_bin

    IO.puts("\nPaz file: #{paz_files}")

    IO.puts("Name length: #{names_length}")
    IO.puts("Offset: #{start_offset - names_length}")
    IO.puts("Start of file: #{start_offset}")

    File.write(@output_path, bin)

    IO.puts("File length: #{byte_size(bin)}")
    IO.puts("New file saved at: #{@output_path}")
  end

  def create_files_bin(files, start_offset) do
    create_files_bin(files, 1, start_offset, <<>>, <<>>)
  end

  def create_files_bin([], _file_num, _start_offset, info_bin, file_bin) do
    {info_bin, file_bin}
  end

  def create_files_bin([file | files], file_num, start_offset, info_bin, file_bin) do
    [hash, folder_num, zsize, size, _path, content] = file

    # IO.puts(path)

    # offset of file
    offset = start_offset + byte_size(file_bin)

    info_bin =
      info_bin <>
        <<hash::32-little, folder_num::32-little, file_num::32-little, offset::32-little,
          zsize::32-little, size::32-little>>

    file_bin = file_bin <> content

    # IO.puts("#{byte_size(content)}, size: #{size}, zsize: #{zsize}")
    # IO.puts("#{hash}, #{folder_num}, #{file_num}, #{offset}, #{zsize}, #{size}")

    create_files_bin(files, file_num + 1, start_offset, info_bin, file_bin)
  end
end

# Extract.start()
