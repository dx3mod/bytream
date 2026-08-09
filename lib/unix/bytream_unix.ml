module In = struct
  let of_file_descr ?(io_buffer_size = 4096) fd =
    let buffer = Bstr.create io_buffer_size in

    let reader () =
      match Unix.read_bigarray fd buffer 0 io_buffer_size with
      | 0 -> raise End_of_file
      | length -> (~buffer, ~offset:0, ~length)
    in

    Bytream.In.make' reader
end
