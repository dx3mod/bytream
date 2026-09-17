module In = struct
  let of_channel ?io_buffer_size ic =
    let io_buffer_size =
      Option.value io_buffer_size ~default:Lwt_bytes.page_size
    in

    let buffer = Lwt_bytes.create io_buffer_size in

    Lwt_direct.spawn begin fun () ->
        let reader () =
          match
            Lwt_direct.await
            @@ Lwt_io.read_into_bigstring ic buffer 0 io_buffer_size
          with
          | 0 -> raise End_of_file
          | length -> (~buffer, ~offset:0, ~length)
        in

        Bytream.In.make' reader
      end

  let of_fd ?io_buffer_size fd =
    Lwt_io.of_fd ~mode:Input fd |> of_channel ?io_buffer_size

  and of_unix_fd ?io_buffer_size unix_fd =
    Lwt_io.of_unix_fd ~mode:Input unix_fd |> of_channel ?io_buffer_size
end

module Out = struct
  let of_channel ?buffer_size oc =
    let writer ((~buffer, ~length, ..) : Bytream.Out.chunk) =
      Lwt_direct.spawn_in_the_background @@ fun () ->
      Lwt_direct.await @@ Lwt_io.write_from_exactly_bigstring oc buffer 0 length
    in

    Bytream.Out.make ?buffer_size writer

  let of_fd ?buffer_size fd =
    Lwt_io.of_fd ~mode:Output fd |> of_channel ?buffer_size

  and of_unix_fd ?buffer_size unix_fd =
    Lwt_io.of_unix_fd ~mode:Output unix_fd |> of_channel ?buffer_size
end
