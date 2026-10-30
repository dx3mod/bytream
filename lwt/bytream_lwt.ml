module In = struct
  let of_channel ?(io_buffer_size = Lwt_bytes.page_size) ic =
    let buf = Lwt_bytes.create io_buffer_size in

    let reader () =
      match
        Lwt_direct.await @@ Lwt_io.read_into_bigstring ic buf 0 io_buffer_size
      with
      | 0 -> raise End_of_file
      | len -> Slice.unsafe_make ~off:0 ~len buf
    in

    Bytream.In.make reader

  let of_fd ?io_buffer_size fd =
    let ic = Lwt_io.of_fd ~mode:Input fd in
    of_channel ?io_buffer_size ic

  let of_unix_fd ?io_buffer_size unix_fd =
    let ic = Lwt_io.of_unix_fd ~mode:Input unix_fd in
    of_channel ?io_buffer_size ic
end

module Out = struct
  let of_channel ?(io_buffer_size = Lwt_bytes.page_size) oc =
    let buf = Bstr.create io_buffer_size in

    let writer slice =
      Lwt_direct.spawn_in_the_background @@ fun () ->
      Lwt_direct.await
      @@ Lwt_io.write_from_exactly_bigstring oc slice.Slice.buf slice.off
           slice.len
    in

    Bytream.Out.make ~buf writer

  let of_fd ?io_buffer_size fd =
    let oc = Lwt_io.of_fd ~mode:Output fd in
    of_channel ?io_buffer_size oc

  let of_unix_fd ?io_buffer_size unix_fd =
    let oc = Lwt_io.of_unix_fd ~mode:Output unix_fd in
    of_channel ?io_buffer_size oc
end


