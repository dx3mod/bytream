module To_test_of_buffer = struct
  let test_of_buffer_from_non_empty_buffer () =
    let in_stream = Bytream.In.of_string "hello!" in

    Alcotest.(check string)
      "same string" "hello!"
      (Bytream.In.input_string in_stream 6);

    Alcotest.check_raises "end of the stream" End_of_file (fun () ->
        Bytream.In.input_char in_stream |> ignore)

  let test_of_buffer_from_empty_buffer () =
    let in_stream = Bytream.In.of_string "" in
    Alcotest.check_raises "end of the stream" End_of_file (fun () ->
        Bytream.In.input_char in_stream |> ignore)
end

module To_test_inputting_lines = struct
  let test_input_line () =
    let in_stream =
      Bytream.In.of_string "first line\nsecond line\nfinal line"
    in

    Alcotest.(check (list string))
      "same strings"
      [ "first line"; "second line"; "final line" ]
      Bytream.In.(many input_line in_stream)
end

let () =
  let open Alcotest in
  run "Bytream.In"
    [
      ( "of_buffer",
        [
          test_case "From non empty buffer" `Quick
            To_test_of_buffer.test_of_buffer_from_non_empty_buffer;
          test_case "From empty buffer" `Quick
            To_test_of_buffer.test_of_buffer_from_empty_buffer;
        ] );
      ( "input_line",
        [
          test_case "Many lines" `Quick To_test_inputting_lines.test_input_line;
        ] );
    ]
