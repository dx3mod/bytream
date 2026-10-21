(lang dune 3.15)

(name bytream)

(generate_opam_files true)

(source
 (github dx3mod/bytream))

(authors "Mikhail Lopatin <dx3mod@bk.ru>")

(maintainers "Mikhail Lopatin <dx3mod@bk.ru>")

(license MIT)

; (documentation https://url/to/documentation)

(package
 (name bytream)
 (synopsis "A streaming bytes and crunching them library")
 (description
  "This library contains angostic I/O runtime mechanisms for organization byte streams processing for write and read in an efficient manner, e.g. for buildings codecs and protocol implementations.")
 (depends
  (ocaml
   (>= 4.14))
  bstr
  (slice
   (>= 0.1.0))
  (alcotest :with-test))
 (depopts ozstd lwt bin)
 (tags
  (bytes streaming)))
