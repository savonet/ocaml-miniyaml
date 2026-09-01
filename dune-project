(lang dune 3.14)

(name miniyaml)
(version 0.1.0)
(source (github savonet/ocaml-miniyaml))
(license GPL-3.0-or-later)
(authors "Samuel Mimram <smimram@gmail.com>")
(maintainers "Samuel Mimram <smimram@gmail.com>")

(generate_opam_files true)

(package
 (name miniyaml)
 (synopsis "A simple YAML parser in pure OCaml")
 (description
  "MiniYaml reads and writes the subset of YAML which is commonly found in configuration files: block mappings and sequences, inline flow collections, quoted scalars and comments. It is written in pure OCaml and has no dependencies.")
 (depends
  (ocaml (>= 4.08))
 )
)
