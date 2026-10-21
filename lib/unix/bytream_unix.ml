module In = struct
  let of_fd ?(io_buffer_size = Sys.io_buffer_size) fd =
    let buffer = Bstr.create io_buffer_size in

    let reader () =
      match Unix.read_bigarray fd buffer 0 io_buffer_size with
      | 0 -> raise End_of_file
      | len -> Slice.unsafe_make ~off:0 ~len buffer
    in

    Bytream.In.make reader
end

module Out = struct
  let of_fd ?(io_buffer_size = Sys.io_buffer_size) fd =
    let rec really_write_bigarray buffer offset = function
      | 0 -> ()
      | length ->
          let written_bytes = Unix.write_bigarray fd buffer 0 length in

          really_write_bigarray buffer (offset + written_bytes)
            (length - written_bytes)
    in

    let writer Slice.{ buf; off; len } = really_write_bigarray buf off len in

    Bytream.Out.make ~buf:(Bstr.create io_buffer_size) writer
end
