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

module Out = struct
  let of_file_descr fd =
    let rec really_write_bigarray buffer offset = function
      | 0 -> ()
      | length ->
          let written_bytes = Unix.write_bigarray fd buffer 0 length in

          really_write_bigarray buffer (offset + written_bytes)
            (length - written_bytes)
    in

    let writer ((~buffer, ~length, ..) : Bytream.Out.chunk) =
      really_write_bigarray buffer 0 length
    in

    Bytream.Out.make writer
end
